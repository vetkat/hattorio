"""Exact arithmetic over Q(phi, sqrt3), degree 4 over Q.

An element of Q(phi) is p + q*phi with phi^2 = phi + 1.
An element of K is x + y*sqrt(3) with x, y in Q(phi).

Division lives here and only here: matchTwo normalises by segment length.
The shipped Lua ring has no division at all.
"""
from __future__ import annotations

from fractions import Fraction as F
from math import lcm, sqrt

_PHI = (1 + sqrt(5)) / 2
_SQRT3 = sqrt(3)


class Q5:
    """p + q*phi, with phi^2 = phi + 1."""

    __slots__ = ("p", "q")

    def __init__(self, p, q=0):
        self.p = F(p)
        self.q = F(q)

    def __add__(self, o):
        return Q5(self.p + o.p, self.q + o.q)

    def __sub__(self, o):
        return Q5(self.p - o.p, self.q - o.q)

    def __neg__(self):
        return Q5(-self.p, -self.q)

    def __mul__(self, o):
        # (p + q phi)(r + s phi) = (pr + qs) + (ps + qr + qs) phi
        return Q5(
            self.p * o.p + self.q * o.q,
            self.p * o.q + self.q * o.p + self.q * o.q,
        )

    def inverse(self):
        # norm = p^2 + pq - q^2 ; conjugate is (p + q) - q phi
        n = self.p * self.p + self.p * self.q - self.q * self.q
        if n == 0:
            raise ZeroDivisionError("Q5 inverse of zero")
        return Q5((self.p + self.q) / n, -self.q / n)

    def __truediv__(self, o):
        return self * o.inverse()

    def __eq__(self, o):
        return isinstance(o, Q5) and self.p == o.p and self.q == o.q

    def __hash__(self):
        return hash((self.p, self.q))

    def __repr__(self):
        return f"Q5({self.p}, {self.q})"

    def to_float(self):
        return float(self.p) + float(self.q) * _PHI

    def is_zero(self):
        return self.p == 0 and self.q == 0


Q5.ZERO = Q5(0, 0)
Q5.ONE = Q5(1, 0)
Q5.PHI = Q5(0, 1)


class K:
    """x + y*sqrt(3), with x, y in Q(phi)."""

    __slots__ = ("x", "y")

    def __init__(self, x: Q5, y: Q5 = None):
        self.x = x
        self.y = y if y is not None else Q5.ZERO

    @staticmethod
    def from_int(n):
        return K(Q5(n, 0), Q5.ZERO)

    @staticmethod
    def half():
        return K(Q5(F(1, 2), 0), Q5.ZERO)

    def __add__(self, o):
        return K(self.x + o.x, self.y + o.y)

    def __sub__(self, o):
        return K(self.x - o.x, self.y - o.y)

    def __neg__(self):
        return K(-self.x, -self.y)

    def __mul__(self, o):
        # (x + y r3)(u + v r3) = (xu + 3yv) + (xv + yu) r3
        three = Q5(3, 0)
        return K(
            self.x * o.x + three * (self.y * o.y),
            self.x * o.y + self.y * o.x,
        )

    def inverse(self):
        # (x + y r3)^-1 = (x - y r3) / (x^2 - 3 y^2)
        three = Q5(3, 0)
        n = self.x * self.x - three * (self.y * self.y)
        if n.is_zero():
            raise ZeroDivisionError("K inverse of zero")
        ni = n.inverse()
        return K(self.x * ni, -self.y * ni)

    def __truediv__(self, o):
        return self * o.inverse()

    def __eq__(self, o):
        return isinstance(o, K) and self.x == o.x and self.y == o.y

    def __hash__(self):
        return hash((self.x, self.y))

    def __repr__(self):
        return f"K({self.x}, {self.y})"

    def is_zero(self):
        return self.x.is_zero() and self.y.is_zero()

    def to_float(self):
        return self.x.to_float() + self.y.to_float() * _SQRT3

    def denominator(self) -> int:
        return lcm(
            self.x.p.denominator,
            self.x.q.denominator,
            self.y.p.denominator,
            self.y.q.denominator,
        )

    def is_integral(self) -> bool:
        return self.denominator() == 1

    def numerators(self):
        """(a, b, c, d) with self == ((a + b phi) + (c + d phi) r3) / denominator()."""
        d = self.denominator()
        return (
            int(self.x.p * d),
            int(self.x.q * d),
            int(self.y.p * d),
            int(self.y.q * d),
        )


K.ZERO = K(Q5.ZERO, Q5.ZERO)
K.ONE = K(Q5.ONE, Q5.ZERO)
K.SQRT3 = K(Q5.ZERO, Q5.ONE)
K.PHI = K(Q5.PHI, Q5.ZERO)
