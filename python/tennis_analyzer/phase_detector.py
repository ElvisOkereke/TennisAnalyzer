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
from itertools import pairwise

from tennis_analyzer.geometry import angle_at_vertex

MIN_VALID_FRAMES = 3
DEFAULT_MIN_CONFIDENCE = 0.3


@dataclass
class PhaseDetectionResult:
    trophy_frame_index: int
    contact_frame_index: int


@dataclass
class JointStats:
    frames_present: int
    frames_confident: int
    average_confidence: float
    min_confidence: float
    max_confidence: float


@dataclass
class PhaseDetectionDiagnostics:
    result: PhaseDetectionResult | None
    failure_reason: str | None
    total_frames: int
    valid_frame_count: int
    joint_stats: dict[str, JointStats]


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


def summarize_joints(frames, min_confidence=DEFAULT_MIN_CONFIDENCE):
    """Per-joint confidence stats across every joint name seen in `frames`.

    Covers all joints present in the data, not just the hitting-side
    required ones — this is what surfaces a handedness-setting mismatch
    (the real wrist tracked confidently on the *other* side) or a joint
    that drops out during a specific phase of the motion.
    """
    joint_names = sorted({name for frame in frames for name in frame})
    stats = {}
    for name in joint_names:
        confidences = [frame[name][2] for frame in frames if name in frame]
        if not confidences:
            continue
        stats[name] = JointStats(
            frames_present=len(confidences),
            frames_confident=sum(1 for c in confidences if c >= min_confidence),
            average_confidence=sum(confidences) / len(confidences),
            min_confidence=min(confidences),
            max_confidence=max(confidences),
        )
    return stats


def diagnose_phases(frames, hitting_side, frame_duration, min_confidence=DEFAULT_MIN_CONFIDENCE):
    """Like `detect_phases`, but always returns a populated diagnostics
    record — including a specific human-readable `failure_reason` at
    whichever gate rejected the sequence, instead of a bare None.
    """
    joint_stats = summarize_joints(frames, min_confidence)

    def diagnostics(result=None, failure_reason=None, valid_frame_count=0):
        return PhaseDetectionDiagnostics(
            result=result,
            failure_reason=failure_reason,
            total_frames=len(frames),
            valid_frame_count=valid_frame_count,
            joint_stats=joint_stats,
        )

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
        return diagnostics(
            failure_reason=(
                f"only {len(valid_indices)} of {len(frames)} frames had all required "
                f"{hitting_side}-side joints ({', '.join(required_joints)}) tracked above "
                f"{min_confidence} confidence (need >= {MIN_VALID_FRAMES})"
            ),
            valid_frame_count=len(valid_indices),
        )

    wrist_speeds = [-math.inf] * len(frames)
    for prev_i, curr_i in pairwise(valid_indices):
        a = frames[prev_i][wrist_joint][:2]
        b = frames[curr_i][wrist_joint][:2]
        dt = frame_duration * (curr_i - prev_i)
        wrist_speeds[curr_i] = speed(a, b, dt)

    if all(s == -math.inf for s in wrist_speeds):
        return diagnostics(
            failure_reason=(
                f"could not compute a wrist speed for any frame ({len(valid_indices)} "
                "valid frame(s) found, but none formed a consecutive pair to measure "
                "movement between)"
            ),
            valid_frame_count=len(valid_indices),
        )

    contact_index = detect_contact_frame(wrist_speeds)

    valid_before_contact = {i for i in valid_indices if i < contact_index}
    if not valid_before_contact:
        return diagnostics(
            failure_reason=(
                f"no confidently-tracked frame occurs before the detected contact frame "
                f"(index {contact_index})"
            ),
            valid_frame_count=len(valid_indices),
        )

    knee_angles = [math.inf] * len(frames)
    for i in valid_before_contact:
        knee_angles[i] = angle_at_vertex(
            frames[i][hip_joint][:2], frames[i][knee_joint][:2], frames[i][ankle_joint][:2]
        )

    trophy_index = detect_trophy_frame(knee_angles, contact_index)

    return diagnostics(
        result=PhaseDetectionResult(
            trophy_frame_index=trophy_index,
            contact_frame_index=contact_index,
        ),
        valid_frame_count=len(valid_indices),
    )


def detect_phases(frames, hitting_side, frame_duration, min_confidence=DEFAULT_MIN_CONFIDENCE):
    """Auto-locate the trophy and contact frame indices.

    `frames` is a list of per-frame joint dicts: joint name -> (x, y,
    confidence), one entry per decoded video frame, in image-pixel space.
    `hitting_side` is "left" or "right" (from the user's handedness
    setting). `frame_duration` is the time between frames, in seconds.

    Returns None if there aren't enough confidently-tracked frames to make
    a reliable call — callers should fall back to manual marking. Use
    `diagnose_phases` for the reason why.
    """
    return diagnose_phases(frames, hitting_side, frame_duration, min_confidence).result
