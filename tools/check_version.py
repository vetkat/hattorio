"""Check that the version is the same everywhere it appears.

info.json is the only source of truth for the mod version, and everything
else must agree with it. CHANGELOG.md must document that version, and a
release tag must name it. If they drift apart, the mod portal page can
describe a build that nobody has.

Without a tag, the newest section of CHANGELOG.md is Unreleased or the
version in info.json. With a tag, the tag names the version in info.json,
the newest versioned section is that version and has a date, and
Unreleased has no entries. In both cases, the changelog.txt that the build
makes from CHANGELOG.md must follow Factorio's format.

.factorio-version pins the Factorio release that the tests use. The
factorio_version and the base dependency in info.json must name the same
major and minor version. Factorio 2.1 refuses to load a mod that says
"2.0", so a mismatch can make the mod unusable.

    python3 -m tools.check_version            # every commit
    python3 -m tools.check_version v1.0.1     # a release tag
"""
from __future__ import annotations

import sys

from tools import changelog
from tools.factorio_version import SEMVER, base_dependency, major_minor, read_info, read_pin

REQUIRED_KEYS = ("name", "version", "title", "author", "factorio_version",
                 "description", "dependencies")


def manifest_problems(info: dict, pin: str) -> list[str]:
    missing = [key for key in REQUIRED_KEYS if key not in info]
    if missing:
        return [f"info.json has no {key!r}" for key in missing]
    if not SEMVER.match(pin):
        return [f".factorio-version holds {pin!r}, not X.Y.Z"]
    problems = []
    if not SEMVER.match(str(info["version"])):
        problems.append(f"info.json version {info['version']!r} is not X.Y.Z")
    if info["factorio_version"] != major_minor(pin):
        problems.append(
            f"info.json factorio_version is {info['factorio_version']!r}, but "
            f".factorio-version pins {pin}, so it must be {major_minor(pin)!r}")
    base = base_dependency(pin)
    if base not in info["dependencies"]:
        problems.append(f"info.json dependencies must contain {base!r}")
    return problems


def _has_entries(release: changelog.Release) -> bool:
    return any(items for _, items in release.groups)


def changelog_problems(version: str, releases: tuple[changelog.Release, ...],
                       tag: str | None) -> list[str]:
    if not releases:
        return ["CHANGELOG.md has no release sections"]
    if tag is None:
        newest = releases[0].version
        if newest in ("Unreleased", version):
            return []
        return [f"the newest section of CHANGELOG.md is {newest}, but info.json says {version}"]
    problems = []
    if tag != f"v{version}":
        problems.append(f"tag {tag} does not match info.json (v{version})")
    if any(r.version == "Unreleased" and _has_entries(r) for r in releases):
        problems.append("CHANGELOG.md still has entries under Unreleased; "
                        "move them into the release section")
    versioned = [r for r in releases if r.version != "Unreleased"]
    if not versioned or versioned[0].version != version:
        problems.append(f"CHANGELOG.md has no section for {version} at the top")
    elif versioned[0].date is None:
        problems.append(f"the {version} section of CHANGELOG.md has no date")
    return problems


def problems(info: dict, changelog_text: str, pin: str, tag: str | None) -> list[str]:
    found = manifest_problems(info, pin)
    if found:
        return found
    _, found = changelog.build(changelog_text, info["version"])
    if found:
        return found
    return changelog_problems(info["version"], changelog.parse(changelog_text).releases, tag)


def main(argv: list[str]) -> int:
    info, pin = read_info(), read_pin()
    changelog_text = (changelog.ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    tag = argv[1] if len(argv) > 1 and argv[1] else None
    found = problems(info, changelog_text, pin, tag)
    for problem in found:
        print(f"version check: {problem}", file=sys.stderr)
    if found:
        return 1
    print(f"version check: {info['name']} {info['version']} consistent, "
          f"Factorio {pin}" + (f", tag {tag}" if tag else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
