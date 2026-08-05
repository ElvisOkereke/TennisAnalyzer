from tennis_analyzer.feedback import (
    CONTACT_HEIGHT_MESSAGE,
    ELBOW_ANGLE_MESSAGE,
    KNEE_BEND_MESSAGE,
    NO_ISSUES_MESSAGE,
    generate_feedback,
)


def test_no_issues_when_all_metrics_good():
    result = generate_feedback(
        knee_bend_degrees=140.0,
        elbow_angle_degrees=170.0,
        contact_height_ratio=1.3,
    )
    assert result == [NO_ISSUES_MESSAGE]


def test_knee_bend_flagged_above_threshold():
    result = generate_feedback(
        knee_bend_degrees=165.0,
        elbow_angle_degrees=170.0,
        contact_height_ratio=1.3,
    )
    assert result == [KNEE_BEND_MESSAGE]


def test_knee_bend_boundary_not_flagged():
    result = generate_feedback(
        knee_bend_degrees=160.0,
        elbow_angle_degrees=170.0,
        contact_height_ratio=1.3,
    )
    assert result == [NO_ISSUES_MESSAGE]


def test_elbow_angle_flagged_below_threshold():
    result = generate_feedback(
        knee_bend_degrees=140.0,
        elbow_angle_degrees=145.0,
        contact_height_ratio=1.3,
    )
    assert result == [ELBOW_ANGLE_MESSAGE]


def test_elbow_angle_boundary_not_flagged():
    result = generate_feedback(
        knee_bend_degrees=140.0,
        elbow_angle_degrees=150.0,
        contact_height_ratio=1.3,
    )
    assert result == [NO_ISSUES_MESSAGE]


def test_contact_height_flagged_below_threshold():
    result = generate_feedback(
        knee_bend_degrees=140.0,
        elbow_angle_degrees=170.0,
        contact_height_ratio=1.0,
    )
    assert result == [CONTACT_HEIGHT_MESSAGE]


def test_contact_height_boundary_not_flagged():
    result = generate_feedback(
        knee_bend_degrees=140.0,
        elbow_angle_degrees=170.0,
        contact_height_ratio=1.15,
    )
    assert result == [NO_ISSUES_MESSAGE]


def test_all_three_flagged_capped_at_three():
    result = generate_feedback(
        knee_bend_degrees=170.0,
        elbow_angle_degrees=120.0,
        contact_height_ratio=0.9,
    )
    assert result == [KNEE_BEND_MESSAGE, ELBOW_ANGLE_MESSAGE, CONTACT_HEIGHT_MESSAGE]
    assert len(result) <= 3
