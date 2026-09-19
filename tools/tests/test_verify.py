import math

from tools.substitution import levels
from tools.verify import (verify_all, flatten, reflected_density,
                          max_coefficient, check_no_overlaps, check_no_gaps)

PHI = (1 + 5 ** 0.5) / 2


def test_depth_2_patch_is_valid():
    assert verify_all(2) == []


def test_no_overlaps_at_depth_3():
    assert check_no_overlaps(flatten(levels(3)[3]["H"])) == []


def test_no_gaps_at_depth_3():
    assert check_no_gaps(flatten(levels(3)[3]["H"])) == []


def test_reflected_density_approaches_theory():
    hats = flatten(levels(3)[3]["H"])
    assert abs(reflected_density(hats) - 1.0 / (PHI ** 4 + 1)) < 0.05


def test_coefficients_stay_within_2_53():
    assert max_coefficient(flatten(levels(4)[4]["H"])) < 2 ** 53


def test_flatten_returns_transform_and_chirality():
    hats = flatten(levels(1)[1]["H"])
    assert len(hats) == 25
    assert isinstance(hats[0][1], bool)
