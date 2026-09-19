from tools.hatviz_port import level0
from tools.substitution import RULES, construct_patch, construct_metatiles, levels


def _walk(mt):
    for ch in mt.children:
        if isinstance(ch.geom, str):
            yield ch
        else:
            yield from _walk(ch.geom)


def test_rules_table_has_29_entries():
    assert len(RULES) == 29


def test_patch_child_count_matches_rules():
    assert len(construct_patch(level0()).children) == 29


def test_construct_metatiles_returns_four_shapes():
    nxt = construct_metatiles(construct_patch(level0()))
    assert set(nxt) == {"H", "T", "P", "F"}


def test_outlines_change_between_levels():
    a = [p.to_float() for p in level0()["H"].outline]
    b = [p.to_float() for p in construct_metatiles(construct_patch(level0()))["H"].outline]
    assert a != b


def test_levels_produces_requested_depth():
    ls = levels(3)
    assert len(ls) == 4
    for lv in ls:
        assert set(lv) == {"H", "T", "P", "F"}


def test_hat_count_grows_by_inflation_factor():
    counts = [sum(1 for _ in _walk(lv["H"])) for lv in levels(3)]
    assert counts[0] == 4
    for a, b in zip(counts, counts[1:]):
        assert 5.0 < b / a < 9.0


def test_hat_counts_are_squares_of_alternate_fibonacci():
    # An exact identity: the level-n H supertile holds F(2n+3)^2 hats.
    # 4, 25, 169, 1156, 7921 = 2^2, 5^2, 13^2, 34^2, 89^2.
    fib = [0, 1]
    while len(fib) < 16:
        fib.append(fib[-1] + fib[-2])
    counts = [sum(1 for _ in _walk(lv["H"])) for lv in levels(4)]
    assert counts == [fib[2 * n + 3] ** 2 for n in range(5)]
