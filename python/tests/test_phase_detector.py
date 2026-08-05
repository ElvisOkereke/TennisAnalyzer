import math

from tennis_analyzer.phase_detector import (
    detect_contact_frame,
    detect_phases,
    detect_trophy_frame,
    hitting_side,
    speed,
)


def test_speed_basic():
    assert math.isclose(speed((0, 0), (3, 4), 1.0), 5.0, abs_tol=1e-9)


def test_speed_zero_dt():
    assert speed((0, 0), (3, 4), 0.0) == 0.0


def test_hitting_side_prefers_higher_peak_right():
    assert hitting_side([1.0, 2.0], [1.0, 5.0]) == "right"


def test_hitting_side_prefers_higher_peak_left():
    assert hitting_side([1.0, 9.0], [1.0, 5.0]) == "left"


def test_detect_contact_frame_finds_peak():
    wrist_speeds = [0.0, 1.0, 2.0, 9.0, 3.0]
    assert detect_contact_frame(wrist_speeds) == 3


def test_detect_trophy_frame_finds_min_before_index():
    knee_angles = [170, 165, 120, 90, 140, 175, 178]
    # global min is at index 3, but restrict to frames before index 5
    assert detect_trophy_frame(knee_angles, before_index=5) == 3


def _frame(right_hip, right_knee, right_ankle, right_wrist, confidence=0.9):
    return {
        "right_hip": (*right_hip, confidence),
        "right_knee": (*right_knee, confidence),
        "right_ankle": (*right_ankle, confidence),
        "right_wrist": (*right_wrist, confidence),
    }


def _build_synthetic_frames():
    hip = (0, 0)
    ankle = (0, 100)
    knee_x_offsets = [5, 5, 5, 40, 5, 5, 5, 5, 5, 5]  # most bent at index 3
    wrist_positions = [(0, 0)] * 7 + [(100, 0)] * 3  # big jump lands on index 7

    frames = []
    for i in range(10):
        knee = (knee_x_offsets[i], 50)
        frames.append(_frame(hip, knee, ankle, wrist_positions[i]))
    return frames


def test_detect_phases_finds_trophy_and_contact():
    frames = _build_synthetic_frames()
    result = detect_phases(frames, hitting_side="right", frame_duration=1.0 / 30.0)
    assert result is not None
    assert result.contact_frame_index == 7
    assert result.trophy_frame_index == 3


def test_detect_phases_returns_none_when_too_few_valid_frames():
    frames = _build_synthetic_frames()[:2]
    result = detect_phases(frames, hitting_side="right", frame_duration=1.0 / 30.0)
    assert result is None


def test_detect_phases_returns_none_when_all_low_confidence():
    frames = [
        _frame((0, 0), (offset, 50), (0, 100), pos, confidence=0.05)
        for offset, pos in zip([5, 5, 5, 40, 5, 5, 5, 5, 5, 5], [(0, 0)] * 7 + [(100, 0)] * 3)
    ]
    result = detect_phases(frames, hitting_side="right", frame_duration=1.0 / 30.0)
    assert result is None
