import json
import pathlib
import subprocess
import sys
import zipfile

from tools import changelog

ROOT = pathlib.Path(__file__).resolve().parents[2]


def test_mod_package_has_the_right_shape():
    """The zip must hold one <name>_<version>/ directory, with info.json at its
    root, the tiling core, its data and a changelog.txt that Factorio accepts.
    It must hold no development files."""
    subprocess.run([sys.executable, "-m", "tools.package"], cwd=ROOT, check=True)
    info = json.loads((ROOT / "info.json").read_text())
    stem = f"{info['name']}_{info['version']}"
    z = zipfile.ZipFile(ROOT / "build" / f"{stem}.zip")
    names = z.namelist()

    assert f"{stem}/info.json" in names
    assert f"{stem}/hat/tiling.lua" in names
    assert f"{stem}/data/hat_rules.lua" in names
    assert f"{stem}/control.lua" in names
    for forbidden in ("/spec/", "/tests/", "/docs/", "/tools/", "/wiki/", "__pycache__",
                      "CHANGELOG.md"):
        assert not any(forbidden in n for n in names), forbidden

    text = z.read(f"{stem}/changelog.txt").decode("utf-8")
    assert f"Version: {info['version']}\n" in text
    assert changelog.factorio_problems(text) == []
