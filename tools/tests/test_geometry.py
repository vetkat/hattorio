import math

from tools.field import K, Q5
from tools.geometry import Pt, Xf, match_two, HAT_OUTLINE, hr3, hex_pt


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


def test_hat_outline_has_13_exact_vertices():
    # The hat is a 13-gon, not a 14-gon. Verbatim from hatviz geometry.js.
    assert len(HAT_OUTLINE) == 13
    for p in HAT_OUTLINE:
        assert p.x.denominator() in (1, 2)
        assert p.y.denominator() in (1, 2)


def test_hat_outline_matches_reference_floats():
    hr3 = math.sqrt(3) / 2
    expected = [(x + 0.5 * y, hr3 * y) for x, y in
                [(0, 0), (-1, -1), (0, -2), (2, -2), (2, -1), (4, -2), (5, -1),
                 (4, 0), (3, 0), (2, 2), (0, 3), (0, 2), (-1, 2)]]
    for p, (ex, ey) in zip(HAT_OUTLINE, expected):
        fx, fy = p.to_float()
        assert abs(fx - ex) < 1e-12 and abs(fy - ey) < 1e-12


def test_hr3_squared_is_three_quarters():
    assert hr3() * hr3() == K.from_int(3) * K.half() * K.half()


def test_hex_pt_uses_the_triangular_basis():
    hr3 = math.sqrt(3) / 2
    fx, fy = hex_pt(3, 2).to_float()
    assert abs(fx - (3 + 0.5 * 2)) < 1e-12
    assert abs(fy - (hr3 * 2)) < 1e-12
