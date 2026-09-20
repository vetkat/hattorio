"""Build a mod zip Factorio will accept.

The archive must contain a single top-level directory named <name>_<version>
with info.json at its root. Development files -- tests, the offline pipeline,
docs, wiki source, CI config -- never ship.

Uses zipfile rather than the zip(1) binary, which is not installed everywhere.
"""
from __future__ import annotations

import json
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]

# Everything the game needs, and nothing else.
SHIP = [
    "info.json", "changelog.txt", "thumbnail.png",
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
    info = json.loads((ROOT / "info.json").read_text())
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

    print(f"built {out.relative_to(ROOT)} ({count} files, {out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
