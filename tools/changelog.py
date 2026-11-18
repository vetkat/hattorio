"""Turn CHANGELOG.md into Factorio's changelog.txt.

CHANGELOG.md uses the Keep a Changelog 1.0.0 format, and it is the only
changelog that people edit. Factorio reads changelog.txt from the mod zip,
so package.py renders it at build time. Git never tracks the file.

The in-game mod browser needs the strict format in Factorio's auxiliary
docs (lua-api.factorio.com/latest/auxiliary/changelog-format.html). The mod
portal shows the same file as plain text. The function `factorio_problems()`
checks the rendered text against the strict format. The function `render()`
wraps long entries, so the plain text stays readable on the portal.

    python3 -m tools.changelog              # print changelog.txt
    python3 -m tools.changelog notes        # the release notes of info.json's version
    python3 -m tools.changelog notes 0.1.0  # the release notes of 0.1.0
"""
from __future__ import annotations

import json
import pathlib
import re
import sys
import textwrap
from typing import NamedTuple

ROOT = pathlib.Path(__file__).resolve().parents[1]

# Factorio does not load a mod whose changelog blocks lack this line.
SEPARATOR = "-" * 99

CATEGORY = {
    "Added": "Features",
    "Changed": "Changes",
    "Deprecated": "Changes",
    "Removed": "Changes",
    "Fixed": "Bugfixes",
    "Security": "Bugfixes",
}
ORDER = ("Features", "Changes", "Bugfixes")
# The width of a rendered line, the indent included.
WIDTH = 80

RELEASE = re.compile(
    r"^## \[(?P<version>[^\]]+)\](?: - (?P<date>\d{4}-\d{2}-\d{2}))?\s*$")
GROUP = re.compile(r"^### (?P<name>\S.*?)\s*$")
ITEM = re.compile(r"^- (?P<text>.+)$")
CONTINUATION = re.compile(r"^ {2,}(?P<text>\S.*)$")


class Release(NamedTuple):
    version: str  # "Unreleased" or X.Y.Z
    date: str | None
    groups: tuple[tuple[str, tuple[str, ...]], ...]


class Parsed(NamedTuple):
    releases: tuple[Release, ...]
    problems: tuple[str, ...]


def parse(text: str) -> Parsed:
    # This function creates these lists, so it can safely fill them in place.
    releases: list[tuple[str, str | None, list]] = []
    problems: list[str] = []
    group: tuple[str, list[str]] | None = None
    for no, line in enumerate(text.splitlines(), 1):
        if line.startswith("## "):
            group = None
            match = RELEASE.match(line)
            if match:
                releases.append((match["version"], match["date"], []))
            else:
                problems.append(f"line {no}: release heading not understood: {line}")
        elif line.startswith("###"):
            match = GROUP.match(line)
            name = match["name"] if match else ""
            if not releases:
                problems.append(f"line {no}: heading {name!r} is outside a release")
                group = None
                continue
            if name not in CATEGORY:
                problems.append(
                    f"line {no}: unknown heading {name!r}, use one of {', '.join(CATEGORY)}")
            group = (name, [])
            releases[-1][2].append(group)
        elif ITEM.match(line):
            if group is None:
                problems.append(f"line {no}: list item outside a ### heading")
            else:
                group[1].append(ITEM.match(line)["text"])
        elif CONTINUATION.match(line) and group is not None and group[1]:
            group[1][-1] += " " + CONTINUATION.match(line)["text"]
    frozen = tuple(
        Release(version, date, tuple((name, tuple(items)) for name, items in groups))
        for version, date, groups in releases)
    return Parsed(frozen, tuple(problems))


def _by_category(release: Release) -> dict[str, tuple[str, ...]]:
    result: dict[str, tuple[str, ...]] = {}
    for heading, items in release.groups:
        category = CATEGORY.get(heading)
        if category:
            result[category] = result.get(category, ()) + items
    return result


def render(releases: tuple[Release, ...], current_version: str) -> str:
    """Factorio's changelog.txt. Unreleased becomes current_version."""
    released = {r.version for r in releases if r.version != "Unreleased"}
    blocks = []
    for release in releases:
        if release.version == "Unreleased":
            if current_version in released:
                continue
            version = current_version
        else:
            version = release.version
        by_category = _by_category(release)
        if not any(by_category.values()):
            continue
        lines = [SEPARATOR, f"Version: {version}"]
        if release.date:
            lines.append(f"Date: {release.date}")
        for category in ORDER:
            if by_category.get(category):
                lines.append(f"  {category}:")
                lines.extend(_wrap(item) for item in by_category[category])
        blocks.append("\n".join(lines))
    return "\n".join(blocks) + "\n" if blocks else ""


def _wrap(item: str) -> str:
    return textwrap.fill(item, width=WIDTH, initial_indent="    - ",
                         subsequent_indent="      ", break_long_words=False,
                         break_on_hyphens=False)


FACTORIO_VERSION = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def factorio_problems(text: str) -> list[str]:
    """Where text breaks Factorio's rules for changelog.txt."""
    problems: list[str] = []
    seen_versions: set[str] = set()
    lines = text.split("\n")
    category = None
    seen_lines: set[str] = set()
    for no, line in enumerate(lines, 1):
        if "\t" in line:
            problems.append(f"changelog.txt line {no}: a tab")
        if line != line.rstrip():
            problems.append(f"changelog.txt line {no}: trailing whitespace")
        if line == SEPARATOR:
            following = lines[no] if no < len(lines) else ""
            match = re.match(r"^Version: (.*)$", following)
            if not match:
                problems.append(f"changelog.txt line {no + 1}: no 'Version: ' line "
                                "after the separator")
                continue
            version = match[1]
            numbers = FACTORIO_VERSION.match(version)
            if (not numbers or any(int(n) > 65535 for n in numbers.groups())
                    or version == "0.0.0"):
                problems.append(f"changelog.txt line {no + 1}: version {version!r} "
                                "is not X.Y.Z with numbers from 0 to 65535")
            if version in seen_versions:
                problems.append(f"changelog.txt line {no + 1}: version {version} is there twice")
            seen_versions.add(version)
            category = None
        elif re.match(r"^  \S.*:$", line):
            category, seen_lines = line, set()
        elif line.startswith("    - ") or line.startswith("      "):
            if category is None:
                problems.append(f"changelog.txt line {no}: an entry outside a category")
            elif line[6:] in seen_lines:
                problems.append(f"changelog.txt line {no}: a duplicate line in {category.strip()}")
            seen_lines.add(line[6:])
        elif line and not line.startswith(("Version: ", "Date: ")):
            problems.append(f"changelog.txt line {no}: not understood: {line!r}")
    if text and not text.startswith(SEPARATOR + "\n"):
        problems.append("changelog.txt must start with exactly 99 dashes")
    return problems


def notes(releases: tuple[Release, ...], version: str) -> str:
    """The Markdown of one version's section, for the GitHub release."""
    for release in releases:
        if release.version == version:
            parts = [f"### {heading}\n\n" + "".join(f"- {item}\n" for item in items)
                     for heading, items in release.groups if items]
            return "\n".join(parts)
    return ""


def build(text: str, version: str) -> tuple[str, list[str]]:
    """changelog.txt for version from the text of CHANGELOG.md, and the
    problems with the source or with the result."""
    parsed = parse(text)
    if parsed.problems:
        return "", list(parsed.problems)
    rendered = render(parsed.releases, version)
    return rendered, factorio_problems(rendered)


def main(argv: list[str]) -> int:
    text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    version = json.loads((ROOT / "info.json").read_text(encoding="utf-8"))["version"]
    rendered, problems = build(text, version)
    for problem in problems:
        print(f"changelog: {problem}", file=sys.stderr)
    if problems:
        return 1
    if argv[1:2] == ["notes"]:
        sys.stdout.write(notes(parse(text).releases, argv[2] if len(argv) > 2 else version))
    else:
        sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
