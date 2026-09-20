"""Verify the version is consistent everywhere it appears.

info.json is the single source of truth. Everything else must agree with it:
the changelog must document that version, and a release tag must name it.
Drift here is how a mod portal page ends up describing a build nobody has.

    python3 tools/check_version.py            # info.json vs changelog
    python3 tools/check_version.py v0.2.0     # also check a release tag
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def changelog_versions(text: str) -> list[str]:
    return re.findall(r"^Version:\s*(\S+)\s*$", text, re.MULTILINE)


def main(argv: list[str]) -> int:
    info = json.loads((ROOT / "info.json").read_text())
    version = info["version"]
    problems = []

    if not SEMVER.match(version):
        problems.append(f"info.json version {version!r} is not X.Y.Z")

    changelog = (ROOT / "changelog.txt").read_text()
    versions = changelog_versions(changelog)
    if version not in versions:
        problems.append(
            f"changelog.txt has no 'Version: {version}' entry "
            f"(found: {', '.join(versions) or 'none'})")
    elif versions[0] != version:
        problems.append(
            f"changelog.txt leads with {versions[0]}, but info.json says {version}; "
            "the newest release must come first")

    # Factorio refuses to load a mod whose changelog separator is malformed,
    # and the message it gives is not obvious.
    first = changelog.splitlines()[0] if changelog else ""
    if len(first) != 99 or set(first) != {"-"}:
        problems.append("changelog.txt must start with exactly 99 dashes")

    if len(argv) > 1:
        tag = argv[1]
        expected = f"v{version}"
        if tag != expected:
            problems.append(f"tag {tag} does not match info.json ({expected})")

    if problems:
        for p in problems:
            print(f"version check: {p}", file=sys.stderr)
        return 1

    print(f"version check: {info['name']} {version} consistent"
          + (f", tag {argv[1]}" if len(argv) > 1 else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
