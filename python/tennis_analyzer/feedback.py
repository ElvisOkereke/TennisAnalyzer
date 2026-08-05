"""Rule-based feedback for manually-marked serve mechanics (Phase 1).

Thresholds below are starting estimates (docs/decisions.md / Phase 1 plan),
not validated against real footage yet — see playbook §10 for the ground-truth
comparison process used to tune them.
"""

KNEE_BEND_MAX_DEGREES = 160.0
ELBOW_ANGLE_MIN_DEGREES = 150.0
CONTACT_HEIGHT_RATIO_MIN = 1.15

MAX_FEEDBACK_ITEMS = 3

KNEE_BEND_MESSAGE = "Bend your knees more for a stronger leg drive."
ELBOW_ANGLE_MESSAGE = "Extend your arm more at contact for full reach."
CONTACT_HEIGHT_MESSAGE = "Try tossing higher / extending fully at contact."
NO_ISSUES_MESSAGE = "Nice mechanics — nothing stood out to flag on this serve."


def generate_feedback(knee_bend_degrees, elbow_angle_degrees, contact_height_ratio):
    """Apply Phase 1 thresholds to computed metrics.

    Returns a list of at most MAX_FEEDBACK_ITEMS feedback strings, or a
    single positive message if nothing trips.
    """
    feedback = []

    if knee_bend_degrees > KNEE_BEND_MAX_DEGREES:
        feedback.append(KNEE_BEND_MESSAGE)

    if elbow_angle_degrees < ELBOW_ANGLE_MIN_DEGREES:
        feedback.append(ELBOW_ANGLE_MESSAGE)

    if contact_height_ratio < CONTACT_HEIGHT_RATIO_MIN:
        feedback.append(CONTACT_HEIGHT_MESSAGE)

    feedback = feedback[:MAX_FEEDBACK_ITEMS]

    if not feedback:
        return [NO_ISSUES_MESSAGE]
    return feedback
