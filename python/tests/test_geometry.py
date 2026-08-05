import math

from tennis_analyzer.geometry import angle_at_vertex, height_ratio


def test_angle_at_vertex_right_angle():
    a = (0, 0)
    b = (0, 1)
    c = (1, 1)
    assert math.isclose(angle_at_vertex(a, b, c), 90.0, abs_tol=1e-6)


def test_angle_at_vertex_straight_line():
    a = (0, 0)
    b = (1, 0)
    c = (2, 0)
    assert math.isclose(angle_at_vertex(a, b, c), 180.0, abs_tol=1e-6)


def test_angle_at_vertex_acute():
    a = (1, 0)
    b = (0, 0)
    c = (1, 1)
    assert math.isclose(angle_at_vertex(a, b, c), 45.0, abs_tol=1e-6)


def test_angle_at_vertex_degenerate_coincident_with_vertex():
    a = (0, 0)
    b = (0, 0)
    c = (1, 1)
    assert angle_at_vertex(a, b, c) == 0.0


def test_angle_at_vertex_symmetric():
    a = (1, 0)
    b = (0, 0)
    c = (0, 1)
    assert math.isclose(
        angle_at_vertex(a, b, c), angle_at_vertex(c, b, a), abs_tol=1e-9
    )


def test_height_ratio_basic():
    head = (0, 0)
    foot = (0, 100)
    contact = (0, 20)
    # (100 - 20) / (100 - 0) = 0.8
    assert math.isclose(height_ratio(contact, head, foot), 0.8, abs_tol=1e-9)


def test_height_ratio_contact_above_head():
    head = (0, 50)
    foot = (0, 150)
    contact = (0, 0)
    # (150 - 0) / (150 - 50) = 1.5
    assert math.isclose(height_ratio(contact, head, foot), 1.5, abs_tol=1e-9)


def test_height_ratio_degenerate_zero_body_height():
    head = (0, 50)
    foot = (10, 50)
    contact = (5, 20)
    assert height_ratio(contact, head, foot) == 0.0
