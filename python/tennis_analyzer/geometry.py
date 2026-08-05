"""Pure geometry math for serve mechanics metrics.

Prototyped and unit-tested here first per the playbook's Python-before-Swift
workflow (docs/tennis-serve-app-full-playbook.md §3, §10) — ported 1:1 to
GeometryEngine.swift once validated.
"""

import math


def angle_at_vertex(a, b, c):
    """Angle in degrees at vertex b, between rays b->a and b->c.

    Points are (x, y) tuples in image-pixel space. Returns 0.0 for
    degenerate input (a coincident with b, or c coincident with b).
    """
    bax = a[0] - b[0]
    bay = a[1] - b[1]
    bcx = c[0] - b[0]
    bcy = c[1] - b[1]

    mag_ba = math.hypot(bax, bay)
    mag_bc = math.hypot(bcx, bcy)
    if mag_ba == 0 or mag_bc == 0:
        return 0.0

    cosine = (bax * bcx + bay * bcy) / (mag_ba * mag_bc)
    cosine = max(-1.0, min(1.0, cosine))
    return math.degrees(math.acos(cosine))


def height_ratio(contact, head, foot):
    """Contact point height as a fraction of standing body height.

    All points are (x, y) tuples in image-pixel space, y increasing
    downward. Returns 0.0 if head and foot are at the same height
    (degenerate — can't establish a body-height scale).
    """
    body_height = foot[1] - head[1]
    if body_height == 0:
        return 0.0
    return (foot[1] - contact[1]) / body_height
