"""Exact points and affine transforms over K = Q(phi, sqrt3)."""
from __future__ import annotations

from fractions import Fraction as F
from math import lcm

from tools.field import K, Q5


def hr3() -> K:
    """sqrt(3)/2."""
    return K(Q5.ZERO, Q5(F(1, 2), 0))


class Pt:
    __slots__ = ("x", "y")

    def __init__(self, x: K, y: K):
        self.x, self.y = x, y

    def __add__(self, o):
        return Pt(self.x + o.x, self.y + o.y)

    def __sub__(self, o):
        return Pt(self.x - o.x, self.y - o.y)

    def __eq__(self, o):
        return isinstance(o, Pt) and self.x == o.x and self.y == o.y

    def __hash__(self):
        return hash((self.x, self.y))

    def __repr__(self):
        return f"Pt({self.x}, {self.y})"

    def to_float(self):
        return (self.x.to_float(), self.y.to_float())


class Xf:
    """(a b c / d e f): maps (x, y) -> (ax + by + c, dx + ey + f)."""

    __slots__ = ("m",)

    def __init__(self, m):
        assert len(m) == 6
        self.m = tuple(m)

    @staticmethod
    def identity():
        z, o = K.ZERO, K.ONE
        return Xf([o, z, z, z, o, z])

    @staticmethod
    def translate(p: Pt):
        z, o = K.ZERO, K.ONE
        return Xf([o, z, p.x, z, o, p.y])

    @staticmethod
    def scale(k: K):
        z = K.ZERO
        return Xf([k, z, z, z, k, z])

    @staticmethod
    def rot60():
        # cos 60 = 1/2, sin 60 = sqrt(3)/2
        h, s, z = K.half(), hr3(), K.ZERO
        return Xf([h, -s, z, s, h, z])

    @staticmethod
    def flip_y():
        z, o = K.ZERO, K.ONE
        return Xf([o, z, z, z, -o, z])

    def mul(self, o: "Xf") -> "Xf":
        a, b, c, d, e, f = self.m
        A, B, C, D, E, G = o.m
        return Xf([
            a * A + b * D, a * B + b * E, a * C + b * G + c,
            d * A + e * D, d * B + e * E, d * C + e * G + f,
        ])

    def apply(self, p: Pt) -> Pt:
        a, b, c, d, e, f = self.m
        return Pt(a * p.x + b * p.y + c, d * p.x + e * p.y + f)

    def det(self) -> K:
        a, b, _, d, e, _ = self.m
        return a * e - b * d

    def is_reflected(self) -> bool:
        return self.det().to_float() < 0

    def denominator(self) -> int:
        return lcm(*[k.denominator() for k in self.m])

    def numerators(self):
        d = self.denominator()
        return tuple((k * K.from_int(d)).numerators() for k in self.m)

    def __eq__(self, o):
        return isinstance(o, Xf) and self.m == o.m

    def __hash__(self):
        return hash(self.m)

    def __repr__(self):
        return f"Xf({[str(k) for k in self.m]})"


def match_two(p1: Pt, p2: Pt, q1: Pt, q2: Pt) -> Xf:
    """The orientation-preserving similarity carrying p1 -> q1 and p2 -> q2."""
    u = p2 - p1
    v = q2 - q1
    den = u.x * u.x + u.y * u.y
    if den.is_zero():
        raise ZeroDivisionError("match_two on a degenerate segment")
    inv = den.inverse()
    sx = (v.x * u.x + v.y * u.y) * inv
    sy = (v.y * u.x - v.x * u.y) * inv
    linear = Xf([sx, -sy, K.ZERO, sy, sx, K.ZERO])
    return Xf.translate(q1).mul(linear).mul(Xf.translate(Pt(-p1.x, -p1.y)))


def _p(xh, yh) -> Pt:
    """Vertex at (xh, yh*sqrt(3))."""
    return Pt(K(Q5(F(xh)), Q5.ZERO), K(Q5.ZERO, Q5(F(yh))))


def hex_pt(x, y) -> Pt:
    """hatviz's hexPt: the triangular-lattice basis {(1,0), (1/2, sqrt3/2)}.

    hexPt(x, y) = (x + y/2, (sqrt3/2) * y), with x and y integers.
    """
    return _p(F(x) + F(y, 2), F(y, 2))


# The hat is a 13-gon. Verbatim from hatviz geometry.js.
HAT_OUTLINE = [
    hex_pt(0, 0), hex_pt(-1, -1), hex_pt(0, -2), hex_pt(2, -2),
    hex_pt(2, -1), hex_pt(4, -2), hex_pt(5, -1), hex_pt(4, 0),
    hex_pt(3, 0), hex_pt(2, 2), hex_pt(0, 3), hex_pt(0, 2),
    hex_pt(-1, 2),
]
