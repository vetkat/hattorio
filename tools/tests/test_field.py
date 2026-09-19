from fractions import Fraction as F
from tools.field import Q5, K


def test_phi_squared_is_phi_plus_one():
    assert Q5.PHI * Q5.PHI == Q5.PHI + Q5.ONE


def test_q5_inverse():
    a = Q5(F(3), F(5))
    assert a * a.inverse() == Q5.ONE


def test_sqrt3_squared_is_three():
    assert K.SQRT3 * K.SQRT3 == K.from_int(3)


def test_k_division():
    a = K(Q5(F(2), F(1)), Q5(F(0), F(3)))
    assert a * a.inverse() == K.ONE
    assert (a / a) == K.ONE


def test_to_float_matches_reference():
    phi = (1 + 5 ** 0.5) / 2
    a = K(Q5(F(1), F(2)), Q5(F(3), F(0)))
    assert abs(a.to_float() - ((1 + 2 * phi) + 3 * 3 ** 0.5)) < 1e-12


def test_integrality_and_denominator():
    assert K.from_int(7).is_integral()
    assert K.from_int(7).denominator() == 1
    h = K.half()
    assert not h.is_integral()
    assert h.denominator() == 2
    assert K.from_int(3).numerators() == (3, 0, 0, 0)


def test_inverse_phi_squared_is_integral():
    # 1/phi^2 == 2 - phi, an integer element. Load-bearing: the substitution
    # downscale must never introduce a denominator.
    inv = K.from_int(1) / (K.PHI * K.PHI)
    assert inv == K.from_int(2) - K.PHI
    assert inv.is_integral()
