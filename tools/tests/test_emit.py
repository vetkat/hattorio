import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LIMIT = 2 ** 53


def _run(mod):
    subprocess.run([sys.executable, "-m", mod], cwd=ROOT, check=True)


def test_emit_produces_integer_only_lua():
    _run("tools.emit_lua")
    text = (ROOT / "data" / "hat_rules.lua").read_text()
    assert "GENERATED" in text
    body = text.split("levels = {", 1)[1].split("radius = {", 1)[0]
    assert "." not in body, "rule data must be integers only"


def test_every_emitted_coefficient_is_below_2_53():
    _run("tools.emit_lua")
    for name in ("hat_rules.lua", "hat_geometry.lua"):
        text = (ROOT / "data" / name).read_text()
        for m in re.finditer(r"-?\d+", text.split("radius = {")[0]):
            assert abs(int(m.group())) < LIMIT, f"{name}: {m.group()} exceeds 2^53"


def test_geometry_has_13_vertices():
    _run("tools.emit_lua")
    text = (ROOT / "data" / "hat_geometry.lua").read_text()
    assert "vertices = 13" in text


def test_rules_cover_every_level_and_shape():
    _run("tools.emit_lua")
    text = (ROOT / "data" / "hat_rules.lua").read_text()
    max_level = int(re.search(r"max_level = (\d+)", text).group(1))
    for i in range(max_level + 1):
        assert "[%d] = {" % i in text
    for s in ("H =", "T =", "P =", "F ="):
        assert s in text


def test_golden_fixture_is_written():
    _run("tools.export_golden")
    p = ROOT / "spec" / "fixtures" / "golden_depth3.lua"
    assert p.exists()
    assert len(p.read_text().splitlines()) > 1000
