"""Phase-detection heuristics: auto-locate the trophy and contact frames
from a per-frame pose time series (Phase 2).

Prototyped and unit-tested here first per the playbook's Python-before-Swift
workflow (docs/tennis-serve-app-full-playbook.md §3, §10) — ported 1:1 to
PhaseDetector.swift once validated. Vision itself has no Python equivalent
and is implemented directly in Swift; this module only covers the numeric
heuristic layered on top of its output.
"""

import math
from dataclasses import dataclass

from tennis_analyzer.geometry import angle_at_vertex

MIN_VALID_FRAMES = 3
DEFAULT_MIN_CONFIDENCE = 0.3


@dataclass
class PhaseDetectionResult:
    trophy_frame_index: int
    contact_frame_index: int


def speed(a, b, dt):
    """Finite-difference speed between two (x, y) points over dt seconds.

    Returns 0.0 if dt is zero or negative (degenerate).
    """
    if dt <= 0:
        return 0.0
    return math.hypot(b[0] - a[0], b[1] - a[1]) / dt


def hitting_side(left_wrist_speeds, right_wrist_speeds):
    """Which wrist has the higher peak speed across the sequence.

    Used only as a fallback when no handedness setting is available.
    Returns "left" or "right"; ties favor "right".
    """
    left_peak = max(left_wrist_speeds, default=0.0)
    right_peak = max(right_wrist_speeds, default=0.0)
    return "left" if left_peak > right_peak else "right"


def detect_contact_frame(wrist_speeds):
    """Index of peak wrist speed."""
    return max(range(len(wrist_speeds)), key=lambda i: wrist_speeds[i])


def detect_trophy_frame(knee_angles, before_index):
    """Index of the most-bent knee, restricted to frames strictly before
    `before_index` (the detected contact frame).
    """
    return min(range(before_index), key=lambda i: knee_angles[i])


def _is_valid(frame, joint_names, min_confidence):
    for name in joint_names:
        joint = frame.get(name)
        if joint is None or joint[2] < min_confidence:
            return False
    return True


def detect_phases(frames, hitting_side, frame_duration, min_confidence=DEFAULT_MIN_CONFIDENCE):
    """Auto-locate the trophy and contact frame indices.

    `frames` is a list of per-frame joint dicts: joint name -> (x, y,
    confidence), one entry per decoded video frame, in image-pixel space.
    `hitting_side` is "left" or "right" (from the user's handedness
    setting). `frame_duration` is the time between frames, in seconds.

    Returns None if there aren't enough confidently-tracked frames to make
    a reliable call — callers should fall back to manual marking.
    """
    wrist_joint = f"{hitting_side}_wrist"
    hip_joint = f"{hitting_side}_hip"
    knee_joint = f"{hitting_side}_knee"
    ankle_joint = f"{hitting_side}_ankle"
    required_joints = (wrist_joint, hip_joint, knee_joint, ankle_joint)

    valid_indices = [
        i for i, frame in enumerate(frames)
        if _is_valid(frame, required_joints, min_confidence)
    ]
    if len(valid_indices) < MIN_VALID_FRAMES:
        return None

    wrist_speeds = [-math.inf] * len(frames)
    for prev_i, curr_i in zip(valid_indices, valid_indices[1:]):
        a = frames[prev_i][wrist_joint][:2]
        b = frames[curr_i][wrist_joint][:2]
        dt = frame_duration * (curr_i - prev_i)
        wrist_speeds[curr_i] = speed(a, b, dt)

    if all(s == -math.inf for s in wrist_speeds):
        return None

    contact_index = detect_contact_frame(wrist_speeds)

    valid_before_contact = {i for i in valid_indices if i < contact_index}
    if not valid_before_contact:
        return None

    knee_angles = [math.inf] * len(frames)
    for i in valid_before_contact:
        knee_angles[i] = angle_at_vertex(
            frames[i][hip_joint][:2], frames[i][knee_joint][:2], frames[i][ankle_joint][:2]
        )

    trophy_index = detect_trophy_frame(knee_angles, contact_index)

    return PhaseDetectionResult(
        trophy_frame_index=trophy_index,
        contact_frame_index=contact_index,
    )
