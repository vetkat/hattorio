"""Build a mod zip that Factorio accepts.

The archive must contain one top-level directory called <name>_<version>,
with info.json at its root. Development files never ship: the tests, the
offline pipeline, the docs, the wiki source and the CI configuration.

changelog.txt is not in the repository. This script makes it from
CHANGELOG.md (tools/changelog.py) and writes it into the zip.

This uses zipfile and not the zip(1) binary, because not every system has
zip(1).
"""
from __future__ import annotations

import json
import pathlib
import zipfile

from tools import changelog

ROOT = pathlib.Path(__file__).resolve().parents[1]

# Everything that the game needs, and nothing more.
SHIP = [
    "info.json", "thumbnail.png",
    "data.lua", "data-final-fixes.lua", "settings.lua", "control.lua",
    "LICENSE", "THIRD_PARTY.md",
    "prototypes", "mod", "hat", "data", "locale",
]

EXCLUDE_SUFFIX = {".pyc"}
EXCLUDE_DIR = {"__pycache__", "tests"}


def files_under(path: pathlib.Path):
    if path.is_file():
        yield path
        return
    for p in sorted(path.rglob("*")):
        if p.is_dir():
            continue
        if p.suffix in EXCLUDE_SUFFIX:
            continue
        if any(part in EXCLUDE_DIR for part in p.parts):
            continue
        yield p


def main():
    info = json.loads((ROOT / "info.json").read_text(encoding="utf-8"))
    changelog_txt, problems = changelog.build(
        (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), info["version"])
    if problems:
        raise SystemExit("changelog: " + "; ".join(problems))
    stem = f"{info['name']}_{info['version']}"
    out_dir = ROOT / "build"
    out_dir.mkdir(exist_ok=True)
    out = out_dir / f"{stem}.zip"
    if out.exists():
        out.unlink()

    count = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for entry in SHIP:
            src = ROOT / entry
            if not src.exists():
                raise SystemExit(f"missing from the working tree: {entry}")
            for f in files_under(src):
                z.write(f, f"{stem}/{f.relative_to(ROOT)}")
                count += 1
        z.writestr(f"{stem}/changelog.txt", changelog_txt)
        count += 1

    print(f"built {out.relative_to(ROOT)} ({count} files, {out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
