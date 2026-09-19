from tools.geometry import Xf
from tools.hatviz_port import level0, hat_polygon


def test_level0_has_four_metatiles():
    assert set(level0()) == {"H", "T", "P", "F"}


def test_hat_counts_match_the_paper():
    m = level0()
    assert len(m["H"].children) == 4
    assert len(m["T"].children) == 1
    assert len(m["P"].children) == 2
    assert len(m["F"].children) == 2


def test_h_has_exactly_one_reflected_hat():
    h = level0()["H"]
    refl = [c for c in h.children if c.xf.is_reflected()]
    assert len(refl) == 1
    assert refl[0].geom == "H1"


def test_level0_placements_contain_no_phi():
    # phi enters only via the substitution. Level-0 must be phi-free.
    for mt in level0().values():
        for ch in mt.children:
            for k in ch.xf.m:
                assert k.x.q == 0 and k.y.q == 0


def test_hat_polygon_has_13_vertices():
    assert len(hat_polygon(Xf.identity())) == 13


def test_outline_vertex_counts():
    m = level0()
    assert len(m["H"].outline) == 6
    assert len(m["T"].outline) == 3
    assert len(m["P"].outline) == 4
    assert len(m["F"].outline) == 5
