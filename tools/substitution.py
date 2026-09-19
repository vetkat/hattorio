"""Substitution rules, ported from hatviz (BSD-3-Clause). See THIRD_PARTY.md.

hatviz holds a fixed 29-entry combinatorial table and computes the actual
transforms with matchTwo against the CURRENT outlines; constructMetatiles then
derives the next level's outlines geometrically. The outlines therefore change
level to level, converging on the limiting phi-proportioned shapes. There is no
fixed matrix set to port.
"""
from __future__ import annotations

from fractions import Fraction as F

from tools.field import K, Q5
from tools.geometry import Pt, Xf, match_two, hr3
from tools.hatviz_port import MetaTile, Child, level0

RULES = [
    ("H",),
    (0, 0, "P", 2), (1, 0, "H", 2), (2, 0, "P", 2), (3, 0, "H", 2),
    (4, 4, "P", 2), (0, 4, "F", 3), (2, 4, "F", 3),
    (4, 1, 3, 2, "F", 0),
    (8, 3, "H", 0), (9, 2, "P", 0), (10, 2, "H", 0), (11, 4, "P", 2),
    (12, 0, "H", 2), (13, 0, "F", 3), (14, 2, "F", 1), (15, 3, "H", 4),
    (8, 2, "F", 1), (17, 3, "H", 0), (18, 2, "P", 0), (19, 2, "H", 2),
    (20, 4, "F", 3), (20, 0, "P", 2), (22, 0, "H", 2), (23, 4, "F", 3),
    (23, 0, "F", 3), (16, 0, "P", 2),
    (9, 4, 0, 2, "T", 2),
    (4, 0, "F", 3),
]


def rot_sixths(n: int) -> Xf:
    """Rotation about the origin by n * 60 degrees."""
    r = Xf.identity()
    step = Xf.rot60()
    for _ in range(n % 6):
        r = r.mul(step)
    return r


def rotate_about(centre: Pt, n: int) -> Xf:
    """hatviz rotAbout: ttrans(p) . trot(ang) . ttrans(-p)."""
    back = Xf.translate(Pt(-centre.x, -centre.y))
    return Xf.translate(centre).mul(rot_sixths(n)).mul(back)


def line_intersect(p1: Pt, q1: Pt, p2: Pt, q2: Pt) -> Pt:
    """hatviz intersect(p1, q1, p2, q2): the crossing of line p1-q1 with p2-q2."""
    d = (q2.y - p2.y) * (q1.x - p1.x) - (q2.x - p2.x) * (q1.y - p1.y)
    if d.is_zero():
        raise ZeroDivisionError("parallel lines in line_intersect")
    ua = ((q2.x - p2.x) * (p1.y - p2.y) - (q2.y - p2.y) * (p1.x - p2.x)) * d.inverse()
    return Pt(p1.x + ua * (q1.x - p1.x), p1.y + ua * (q1.y - p1.y))


def _eval_child(mt: MetaTile, n: int, i: int) -> Pt:
    """hatviz evalChild: apply child n's transform to vertex i of its outline."""
    ch = mt.children[n]
    return ch.xf.apply(ch.geom.outline[i])


def construct_patch(shapes) -> MetaTile:
    out = MetaTile("patch", [])
    for r in RULES:
        if len(r) == 1:
            out.add(Xf.identity(), shapes[r[0]])
        elif len(r) == 4:
            src = out.children[r[0]]
            poly = src.geom.outline
            P = src.xf.apply(poly[(r[1] + 1) % len(poly)])
            Q = src.xf.apply(poly[r[1]])
            nsh = shapes[r[2]]
            npoly = nsh.outline
            out.add(match_two(npoly[r[3]], npoly[(r[3] + 1) % len(npoly)], P, Q), nsh)
        else:
            ch_p = out.children[r[0]]
            ch_q = out.children[r[2]]
            P = ch_q.xf.apply(ch_q.geom.outline[r[3]])
            Q = ch_p.xf.apply(ch_p.geom.outline[r[1]])
            nsh = shapes[r[4]]
            npoly = nsh.outline
            out.add(match_two(npoly[r[5]], npoly[(r[5] + 1) % len(npoly)], P, Q), nsh)
    return out


def _recentre(mt: MetaTile) -> MetaTile:
    """hatviz recentre: shift so the outline's CENTROID sits at the origin."""
    n = len(mt.outline)
    cx = mt.outline[0].x
    cy = mt.outline[0].y
    for p in mt.outline[1:]:
        cx = cx + p.x
        cy = cy + p.y
    inv_n = K(Q5(F(1, n)), Q5.ZERO)
    cx = cx * inv_n
    cy = cy * inv_n
    tr = Pt(-cx, -cy)
    mt.outline = [Pt(p.x - cx, p.y - cy) for p in mt.outline]
    M = Xf.translate(tr)
    mt.children = [Child(M.mul(ch.xf), ch.geom) for ch in mt.children]
    return mt


def construct_metatiles(patch: MetaTile):
    bps1 = _eval_child(patch, 8, 2)
    bps2 = _eval_child(patch, 21, 2)
    rbps = rotate_about(bps1, 4).apply(bps2)      # -2*PI/3 == +4 sixths
    p72 = _eval_child(patch, 7, 2)
    p252 = _eval_child(patch, 25, 2)
    c62 = _eval_child(patch, 6, 2)

    llc = line_intersect(bps1, rbps, c62, p72)
    w = c62 - llc
    rot_m60 = rot_sixths(5)                        # -PI/3 == +5 sixths

    H_out = [llc, bps1]
    w = _linear(rot_m60, w)
    H_out.append(Pt(H_out[1].x + w.x, H_out[1].y + w.y))
    H_out.append(_eval_child(patch, 14, 2))
    w = _linear(rot_m60, w)
    H_out.append(Pt(H_out[3].x - w.x, H_out[3].y - w.y))
    H_out.append(c62)
    new_H = MetaTile("H", H_out,
                     [patch.children[i] for i in (0, 9, 16, 27, 26, 6, 1, 8, 10, 15)])

    P_out = [p72, Pt(p72.x + (bps1.x - llc.x), p72.y + (bps1.y - llc.y)), bps1, llc]
    new_P = MetaTile("P", P_out, [patch.children[i] for i in (7, 2, 3, 4, 28)])

    F_out = [bps2, _eval_child(patch, 24, 2), _eval_child(patch, 25, 0), p252,
             Pt(p252.x + (llc.x - bps1.x), p252.y + (llc.y - bps1.y))]
    new_F = MetaTile("F", F_out, [patch.children[i] for i in (21, 20, 22, 23, 24, 25)])

    AAA = H_out[2]
    BBB = Pt(H_out[1].x + (H_out[4].x - H_out[5].x),
             H_out[1].y + (H_out[4].y - H_out[5].y))
    CCC = rotate_about(BBB, 5).apply(AAA)
    new_T = MetaTile("T", [BBB, CCC, AAA], [patch.children[11]])

    return {"H": _recentre(new_H), "T": _recentre(new_T),
            "P": _recentre(new_P), "F": _recentre(new_F)}


def _linear(xf: Xf, p: Pt) -> Pt:
    """Apply only the linear part of xf (hatviz uses transPt with a pure rotation)."""
    a, b, _, d, e, _ = xf.m
    return Pt(a * p.x + b * p.y, d * p.x + e * p.y)


def levels(n: int):
    out = [level0()]
    for _ in range(n):
        out.append(construct_metatiles(construct_patch(out[-1])))
    return out
