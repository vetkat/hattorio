import math

from tools.field import K, Q5
from tools.geometry import Pt, Xf, match_two, HAT_OUTLINE, hr3


def test_identity_applies_unchanged():
    p = Pt(K.from_int(3), K.from_int(4))
    assert Xf.identity().apply(p) == p


def test_rot60_six_times_is_identity():
    r = Xf.rot60()
    acc = Xf.identity()
    for _ in range(6):
        acc = acc.mul(r)
    p = Pt(K.from_int(5), K.from_int(-2))
    assert acc.apply(p) == p


def test_rot60_is_not_reflected_but_flip_is():
    assert not Xf.rot60().is_reflected()
    assert Xf.flip_y().is_reflected()


def test_match_two_maps_the_segment():
    p1, p2 = Pt(K.from_int(0), K.from_int(0)), Pt(K.from_int(1), K.from_int(0))
    q1 = Pt(K.from_int(2), K.from_int(3))
    q2 = Pt(K.from_int(2), K.from_int(5))
    t = match_two(p1, p2, q1, q2)
    assert t.apply(p1) == q1
    assert t.apply(p2) == q2


def test_hat_outline_has_14_exact_vertices():
    assert len(HAT_OUTLINE) == 14
    for p in HAT_OUTLINE:
        assert p.x.denominator() in (1, 2)


def test_hat_outline_matches_reference_floats():
    s3 = math.sqrt(3)
    expected = [
        (0, 0), (-1.5, -0.5 * s3), (0, -s3), (1.5, -0.5 * s3), (3, -s3),
        (4.5, -0.5 * s3), (3, 0), (3, s3), (1.5, 1.5 * s3), (0, s3),
        (0, 2 * s3), (-1.5, 2.5 * s3), (-3, 2 * s3), (-3, s3),
    ]
    for p, (ex, ey) in zip(HAT_OUTLINE, expected):
        fx, fy = p.to_float()
        assert abs(fx - ex) < 1e-12 and abs(fy - ey) < 1e-12


def test_hr3_squared_is_three_quarters():
    assert hr3() * hr3() == K.from_int(3) * K.half() * K.half()
