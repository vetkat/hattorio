"""Compare the pinned Factorio version with the newest releases.

Factorio 2.1 refused to load Hattorio 1.0.0, and the players saw it first.
`watch.yml` runs this tool every three hours, and `factorio-version.yml`
runs it every day. So CI finds a new Factorio release before the players do.

    python3 -m tools.factorio_version bump                  # line for GITHUB_OUTPUT
    python3 -m tools.factorio_version plan SHA KEYS_FILE    # line for GITHUB_OUTPUT
    python3 -m tools.factorio_version retarget X.Y.Z

`bump` writes the newest stable release to .factorio-version when it is
newer than the pin, and prints `version=X.Y.Z`. Otherwise it prints nothing.

`plan` decides what `watch.yml` still has to do at commit SHA. KEYS_FILE
lists the cache keys of earlier runs, one per line. The output is one line,
`matrix`: the releases and modes to test in the game.

`retarget` rewrites factorio_version and the base dependency in info.json
for X.Y.Z. CI uses it only in a throwaway checkout, so that the in-game
tests can load the mod in a new minor version. A release for that version
still needs a PR.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://factorio.com/api/latest-releases"
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
CHANNELS = ("stable", "experimental")


def major_minor(version: str) -> str:
    """2.1.24 -> 2.1, the form of factorio_version in info.json."""
    return version.rsplit(".", 1)[0]


def base_dependency(version: str) -> str:
    return f"base >= {major_minor(version)}.0"


def read_pin() -> str:
    return (ROOT / ".factorio-version").read_text(encoding="utf-8").strip()


def write_pin(version: str) -> None:
    (ROOT / ".factorio-version").write_text(version + "\n", encoding="utf-8")


def read_info() -> dict:
    return json.loads((ROOT / "info.json").read_text(encoding="utf-8"))


def _numbers(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def versions(latest: object) -> dict[str, str]:
    """The headless version of each channel, or {} if the format changed."""
    found = {}
    for channel in CHANNELS:
        entry = latest.get(channel) if isinstance(latest, dict) else None
        headless = entry.get("headless") if isinstance(entry, dict) else None
        if not isinstance(headless, str) or not SEMVER.match(headless):
            return {}
        found[channel] = headless
    return found


def problems(latest: object, pinned: str) -> list[str]:
    if not versions(latest):
        return [f"{URL} has no stable and experimental headless versions; "
                "its format may have changed"]
    if not SEMVER.match(pinned):
        return [f".factorio-version holds {pinned!r}, not X.Y.Z"]
    return []


def bump_to(stable: str, pinned: str) -> str | None:
    """The new pin: the stable release when it is newer than the pin."""
    return stable if _numbers(stable) > _numbers(pinned) else None


MODES = ("base", "space-age")


def plan(found: dict[str, str], pinned: str, sha: str, keys: set[str]) -> list[dict]:
    """What watch.yml still has to do at commit sha. keys are the cache
    keys of earlier runs: a key marks a test as done."""
    releases = sorted({v for v in found.values() if v != pinned}, key=_numbers)
    matrix = [{"version": v, "mode": m} for v in releases for m in MODES
              if f"watch-{v}-{m}-{sha}" not in keys]
    return matrix


def retarget(info: dict, version: str) -> dict:
    dependencies = [base_dependency(version) if d.startswith("base ") else d
                    for d in info["dependencies"]]
    return {**info, "factorio_version": major_minor(version), "dependencies": dependencies}


def fetch() -> object:
    request = urllib.request.Request(URL, headers={"User-Agent": "hattorio-ci"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


USAGE = __doc__.split("\n\n")[2]


def main(argv: list[str]) -> int:
    command = argv[1:2]
    if command == ["retarget"] and len(argv) == 3 and SEMVER.match(argv[2]):
        info = retarget(read_info(), argv[2])
        (ROOT / "info.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
        print(f"factorio version: info.json now targets {info['factorio_version']}")
        return 0
    if not (command == ["bump"] and len(argv) == 2 or command == ["plan"] and len(argv) == 4):
        print(USAGE, file=sys.stderr)
        return 2
    try:
        latest = fetch()
    except (OSError, ValueError) as error:
        print(f"factorio version: cannot read {URL}: {error}", file=sys.stderr)
        return 1
    pinned = read_pin()
    errors = problems(latest, pinned)
    for problem in errors:
        print(f"factorio version: {problem}", file=sys.stderr)
    if errors:
        return 1
    releases = versions(latest)
    if command == ["plan"]:
        keys = set(pathlib.Path(argv[3]).read_text(encoding="utf-8").split())
        print(f"matrix={json.dumps(plan(releases, pinned, argv[2], keys))}")
        return 0
    new = bump_to(releases["stable"], pinned)
    if new is None:
        print(f"factorio version: {pinned} is the newest stable release", file=sys.stderr)
        return 0
    write_pin(new)
    print(f"factorio version: the pin moves from {pinned} to {new}", file=sys.stderr)
    print(f"version={new}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
