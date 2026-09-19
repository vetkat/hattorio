"""The limiting phi-proportioned metatiles, where the substitution is exactly
self-similar.

Why this exists: hatviz's construct_metatiles derives each level's outlines
geometrically, so they are exact rationals converging on irrational limits and
their numerators blow up (level 7 already exceeds 2^53). That caps the
emittable depth at 6. In the LIMIT the shapes have tiny exact coefficients and
one rule set works at every depth.

The constants below were recovered by integer-relation recognition against a
level-22 normalisation (agreeing independently at level 14 to 1e-8 and level 22
to 1e-14), then VERIFIED: substituting them reproduces them scaled by phi^2
exactly, as ring elements. verify_fixed_point() re-runs that check, and
rederive_outlines() re-runs the recognition from scratch.

Each coordinate is (a, b, q) meaning (a + b*phi)/q; y values are that times
sqrt(3).
"""
from __future__ import annotations

from decimal import Decimal as D, getcontext
from fractions import Fraction as F

from tools.field import K, Q5
from tools.geometry import Pt, Xf
from tools.hatviz_port import MetaTile
from tools.substitution import levels, construct_patch, construct_metatiles

DERIVE_LEVEL = 22

LIMIT_OUTLINES = {
    "H": [
        ((-11, -18, 20), (-1, -8, 20)),
        ((7, 6, 10), (-3, -4, 10)),
        ((7, 21, 20), (-1, -1, 4)),
        ((1, 3, 10), (1, 1, 2)),
        ((4, -3, 20), (6, 13, 20)),
        ((-8, -9, 10), (-2, -1, 10)),
    ],
    "T": [
        ((18, 9, 20), (0, 1, 4)),
        ((-9, -12, 20), (9, 2, 20)),
        ((-9, 3, 20), (-9, -7, 20)),
    ],
    "P": [
        ((-1, -1, 2), (-1, -3, 10)),
        ((3, 4, 4), (-7, -6, 20)),
        ((1, 1, 2), (1, 3, 10)),
        ((-3, -4, 4), (7, 6, 20)),
    ],
    "F": [
        ((-47, -76, 100), (-17, -26, 100)),
        ((23, 84, 100), (-7, -46, 100)),
        ((43, 94, 100), (-7, 4, 100)),
        ((53, 24, 100), (3, 34, 100)),
        ((-36, -63, 50), (14, 17, 50)),
    ],
}


def _coord(t):
    a, b, q = t
    return Q5(F(a, q), F(b, q))


def _pt(xt, yt) -> Pt:
    return Pt(K(_coord(xt), Q5.ZERO), K(Q5.ZERO, _coord(yt)))


def limit_shapes():
    """The four limiting metatiles as exact MetaTiles (outlines only)."""
    return {n: MetaTile(n, [_pt(x, y) for x, y in pts])
            for n, pts in LIMIT_OUTLINES.items()}


def self_similar_rules():
    """One level-independent rule set: {shape: [(child_shape, Xf), ...]}."""
    nxt = construct_metatiles(construct_patch(limit_shapes()))
    return {n: [(ch.geom.label, ch.xf) for ch in mt.children] for n, mt in nxt.items()}


def verify_fixed_point() -> list[str]:
    """Substituting the limit shapes must reproduce them scaled by phi^2, exactly."""
    limit = limit_shapes()
    nxt = construct_metatiles(construct_patch(limit))
    phi2 = K.PHI * K.PHI
    errs = []
    for name, mt in limit.items():
        want = [Pt(p.x * phi2, p.y * phi2) for p in mt.outline]
        got = nxt[name].outline
        if len(want) != len(got):
            errs.append(f"{name}: {len(want)} vertices vs {len(got)}")
            continue
        for i, (a, b) in enumerate(zip(want, got)):
            if not (a.x == b.x and a.y == b.y):
                errs.append(f"{name} vertex {i}: {a} != {b}")
    return errs


def max_rule_coefficient() -> int:
    worst = 0
    for rules in self_similar_rules().values():
        for _, xf in rules:
            worst = max(worst, xf.denominator())
            for g in xf.numerators():
                for v in g:
                    worst = max(worst, abs(int(v)))
    return worst


# --- rederivation, for the test that the constants are not invented ---------

def _recognise(v, tol, maxq=400, maxab=3000):
    getcontext().prec = 120
    phi = (1 + D(5).sqrt()) / 2
    for q in range(1, maxq + 1):
        t = v * q
        for b in range(-maxab, maxab + 1):
            a = t - b * phi
            ar = a.to_integral_value()
            if abs(a - ar) < tol and abs(ar) <= maxab:
                return (int(ar), b, q)
    return None


def rederive_outlines(level=DERIVE_LEVEL, tol=None):
    """Re-run recognition from the substitution itself. Slow; used by tests."""
    getcontext().prec = 120
    phi = (1 + D(5).sqrt()) / 2
    s3 = D(3).sqrt()
    tol = tol if tol is not None else D(10) ** -14

    def dec(f):
        return D(f.numerator) / D(f.denominator)

    def val(k):
        return (dec(k.x.p) + dec(k.x.q) * phi) + (dec(k.y.p) + dec(k.y.q) * phi) * s3

    ls = levels(level)
    scale = K.ONE
    inv = K.from_int(2) - K.PHI          # 1/phi^2, an exact ring element
    for _ in range(level):
        scale = scale * inv
    out = {}
    for name in ("H", "T", "P", "F"):
        got = []
        for p in ls[level][name].outline:
            rx = _recognise(val(p.x * scale), tol)
            ry = _recognise(val(p.y * scale) / s3, tol)
            if rx is None or ry is None:
                raise ValueError(f"{name}: coordinate not recognised")
            got.append((rx, ry))
        out[name] = got
    return out


def main():
    errs = verify_fixed_point()
    if errs:
        raise SystemExit("fixed point FAILED:\n" + "\n".join(errs))
    print("fixed point verified exactly for H, T, P, F")
    print(f"max rule coefficient: {max_rule_coefficient()}")
    for n, r in self_similar_rules().items():
        print(f"  {n}: {len(r)} children")


if __name__ == "__main__":
    main()
