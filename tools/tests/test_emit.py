import json
import math
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def _run(mod):
    subprocess.run([sys.executable, "-m", mod], cwd=ROOT, check=True)


def test_rules_cover_every_level_and_shape():
    _run("tools.emit_lua")
    text = (ROOT / "data" / "hat_rules.lua").read_text()
    assert "GENERATED" in text
    max_level = int(re.search(r"max_level = (\d+)", text).group(1))
    assert max_level >= 12, "depth 12 is needed to cover the map"
    for i in range(max_level + 1):
        assert "[%d] = {" % i in text
    for s in ("H =", "T =", "P =", "F ="):
        assert s in text


def test_every_emitted_float_round_trips_exactly():
    """%.17g must reproduce the double bit for bit, or the Lua descent
    silently diverges from the pipeline that validated it."""
    _run("tools.emit_lua")
    for name in ("hat_rules.lua", "hat_geometry.lua"):
        text = (ROOT / "data" / name).read_text()
        for m in re.finditer(r"-?\d+\.?\d*(?:e[-+]?\d+)?", text):
            tok = m.group()
            v = float(tok)
            assert float("%.17g" % v) == v, f"{name}: {tok} does not round-trip"


def test_emitted_values_are_finite():
    _run("tools.emit_lua")
    text = (ROOT / "data" / "hat_rules.lua").read_text()
    for m in re.finditer(r"-?\d+\.?\d*(?:e[-+]?\d+)?", text):
        v = float(m.group())
        assert math.isfinite(v)


def test_geometry_has_13_vertices():
    _run("tools.emit_lua")
    text = (ROOT / "data" / "hat_geometry.lua").read_text()
    assert "vertices = 13" in text
    assert re.search(r"circumradius = 4\.58", text)


def test_golden_fixture_is_written():
    _run("tools.export_golden")
    p = ROOT / "spec" / "fixtures" / "golden_depth3.lua"
    assert p.exists()
    assert len(p.read_text().splitlines()) > 1000


def test_mod_package_has_the_right_shape():
    """The zip must hold one <name>_<version>/ directory with info.json at its
    root, the tiling core and its data, and no development files."""
    import zipfile
    subprocess.run([sys.executable, "tools/package.py"], cwd=ROOT, check=True)
    info = json.loads((ROOT / "info.json").read_text())
    stem = f"{info['name']}_{info['version']}"
    z = zipfile.ZipFile(ROOT / "build" / f"{stem}.zip")
    names = z.namelist()

    assert f"{stem}/info.json" in names
    assert f"{stem}/hat/tiling.lua" in names
    assert f"{stem}/data/hat_rules.lua" in names
    assert f"{stem}/control.lua" in names
    for forbidden in ("/spec/", "/docs/", "/tools/", "/wiki/", "__pycache__"):
        assert not any(forbidden in n for n in names), forbidden
