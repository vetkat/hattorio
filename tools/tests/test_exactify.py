import pytest

from tools.exactify import (LIMIT_OUTLINES, limit_shapes, self_similar_rules,
                            verify_fixed_point, max_rule_coefficient,
                            rederive_outlines)


def test_fixed_point_holds_exactly():
    assert verify_fixed_point() == []


def test_rule_coefficients_are_small():
    # per-level rules reach 4.8e26 by level 12; the self-similar set must not.
    assert max_rule_coefficient() < 1000


def test_rule_shape_counts():
    r = self_similar_rules()
    assert {k: len(v) for k, v in r.items()} == {"H": 10, "T": 1, "P": 5, "F": 6}


def test_outline_vertex_counts():
    assert {k: len(v) for k, v in LIMIT_OUTLINES.items()} == {"H": 6, "T": 3, "P": 4, "F": 5}


def test_denominators_divide_100():
    for pts in LIMIT_OUTLINES.values():
        for xt, yt in pts:
            assert 100 % xt[2] == 0 and 100 % yt[2] == 0


@pytest.mark.slow
def test_constants_rederive_from_the_substitution():
    """The constants are recovered, not invented. Slow: re-runs recognition."""
    assert rederive_outlines() == LIMIT_OUTLINES
