"""Level-0 metatiles, ported from hatviz (BSD-3-Clause). See THIRD_PARTY.md.

hatviz writes vertices as pt(x, k*hr3) with hr3 = sqrt(3)/2, so a y of k*hr3
is (k/2)*sqrt(3). The _p() helper below takes that halved coefficient.
"""
from __future__ import annotations

from fractions import Fraction as F

from tools.field import K, Q5
from tools.geometry import Pt, Xf, match_two, HAT_OUTLINE, hr3


class Child:
    __slots__ = ("xf", "geom")

    def __init__(self, xf: Xf, geom):
        self.xf, self.geom = xf, geom


class MetaTile:
    __slots__ = ("label", "outline", "children")

    def __init__(self, label, outline, children=None):
        self.label = label
        self.outline = list(outline)
        self.children = list(children or [])

    def add(self, xf: Xf, geom):
        self.children.append(Child(xf, geom))


def _p(xh, yh) -> Pt:
    """Vertex at (xh, yh*sqrt(3))."""
    return Pt(K(Q5(F(xh)), Q5.ZERO), K(Q5.ZERO, Q5(F(yh))))


def _k(v) -> K:
    return K(Q5(F(v)), Q5.ZERO)


def hat_polygon(xf: Xf):
    return [xf.apply(v) for v in HAT_OUTLINE]


def _half_scale() -> Xf:
    return Xf.scale(K.half())


def level0():
    ho = HAT_OUTLINE

    # --- H: four hats, one of them reflected -------------------------------
    H_out = [
        _p(F(0), F(0)), _p(F(4), F(0)), _p(F(9, 2), F(1, 2)),
        _p(F(5, 2), F(5, 2)), _p(F(3, 2), F(5, 2)), _p(F(-1, 2), F(1, 2)),
    ]
    H = MetaTile("H", H_out)
    H.add(match_two(ho[5], ho[7], H_out[5], H_out[0]), "H")
    H.add(match_two(ho[9], ho[11], H_out[1], H_out[2]), "H")
    H.add(match_two(ho[5], ho[7], H_out[3], H_out[4]), "H")
    # the anti-hat: translate . rot120 . (half scale with y flipped)
    rot120 = Xf([-K.half(), -hr3(), K.ZERO, hr3(), -K.half(), K.ZERO])
    flip_half = Xf([K.half(), K.ZERO, K.ZERO, K.ZERO, -K.half(), K.ZERO])
    H.add(Xf.translate(_p(F(5, 2), F(1, 2))).mul(rot120).mul(flip_half), "H1")

    # --- T: one hat --------------------------------------------------------
    T_out = [_p(F(0), F(0)), _p(F(3), F(0)), _p(F(3, 2), F(3, 2))]
    T = MetaTile("T", T_out)
    T.add(Xf([K.half(), K.ZERO, _k(F(1, 2)), K.ZERO, K.half(), hr3()]), "T")

    # --- P: two hats forming a parallelogram -------------------------------
    P_out = [_p(F(0), F(0)), _p(F(4), F(0)), _p(F(3), F(1)), _p(F(-1), F(1))]
    rot_p = Xf([K.half(), hr3(), K.ZERO, -hr3(), K.half(), K.ZERO])
    P = MetaTile("P", P_out)
    P.add(Xf([K.half(), K.ZERO, _k(F(3, 2)), K.ZERO, K.half(), hr3()]), "P")
    P.add(Xf.translate(_p(F(0), F(1))).mul(rot_p).mul(_half_scale()), "P")

    # --- F: two hats, one leg of a triskelion ------------------------------
    F_out = [
        _p(F(0), F(0)), _p(F(3), F(0)), _p(F(7, 2), F(1, 2)),
        _p(F(3), F(1)), _p(F(-1), F(1)),
    ]
    Fm = MetaTile("F", F_out)
    Fm.add(Xf([K.half(), K.ZERO, _k(F(3, 2)), K.ZERO, K.half(), hr3()]), "F")
    Fm.add(Xf.translate(_p(F(0), F(1))).mul(rot_p).mul(_half_scale()), "F")

    return {"H": H, "T": T, "P": P, "F": Fm}
