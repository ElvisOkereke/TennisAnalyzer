import math

from tennis_analyzer.phase_detector import (
    detect_contact_frame,
    detect_phases,
    detect_trophy_frame,
    diagnose_phases,
    hitting_side,
    speed,
    summarize_joints,
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


def test_summarize_joints_covers_all_joints_seen():
    frames = [
        {"right_wrist": (0, 0, 0.9), "right_hip": (0, 0, 0.9)},
        {"right_wrist": (1, 0, 0.1), "left_wrist": (5, 5, 0.8)},
    ]
    stats = summarize_joints(frames, min_confidence=0.3)

    assert set(stats) == {"right_wrist", "right_hip", "left_wrist"}

    right_wrist = stats["right_wrist"]
    assert right_wrist.frames_present == 2
    assert right_wrist.frames_confident == 1
    assert math.isclose(right_wrist.average_confidence, 0.5)
    assert right_wrist.min_confidence == 0.1
    assert right_wrist.max_confidence == 0.9

    left_wrist = stats["left_wrist"]
    assert left_wrist.frames_present == 1
    assert left_wrist.frames_confident == 1

    right_hip = stats["right_hip"]
    assert right_hip.frames_present == 1


def test_diagnose_phases_success_has_no_failure_reason():
    frames = _build_synthetic_frames()
    diagnostics = diagnose_phases(frames, hitting_side="right", frame_duration=1.0 / 30.0)

    assert diagnostics.failure_reason is None
    assert diagnostics.result is not None
    assert diagnostics.result.contact_frame_index == 7
    assert diagnostics.result.trophy_frame_index == 3
    assert diagnostics.total_frames == 10
    assert diagnostics.valid_frame_count == 10
    assert "right_wrist" in diagnostics.joint_stats


def test_diagnose_phases_reports_too_few_valid_frames():
    frames = _build_synthetic_frames()[:2]
    diagnostics = diagnose_phases(frames, hitting_side="right", frame_duration=1.0 / 30.0)

    assert diagnostics.result is None
    assert diagnostics.valid_frame_count == 2
    assert "only 2 of 2 frames" in diagnostics.failure_reason
    assert "need >= 3" in diagnostics.failure_reason


def test_diagnose_phases_still_reports_joint_stats_on_failure():
    # joint_stats should be populated even when the sequence fails the
    # too-few-valid-frames gate, so the debug report can still show which
    # joints were weak.
    frames = _build_synthetic_frames()[:2]
    diagnostics = diagnose_phases(frames, hitting_side="right", frame_duration=1.0 / 30.0)

    assert diagnostics.result is None
    assert diagnostics.failure_reason is not None
    assert "right_wrist" in diagnostics.joint_stats
    assert diagnostics.joint_stats["right_wrist"].frames_present == 2
