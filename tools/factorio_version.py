"""Compare the pinned Factorio version with the newest releases.

Factorio 2.1 refused to load Hattorio 1.0.0, and the players saw it first.
`watch.yml` runs this tool every three hours. So CI finds a new Factorio
release before the players do.

    python3 -m tools.factorio_version                       # fail if a newer stable exists
    python3 -m tools.factorio_version plan SHA KEYS_FILE    # lines for GITHUB_OUTPUT
    python3 -m tools.factorio_version retarget X.Y.Z

`plan` decides what `watch.yml` still has to do at commit SHA. KEYS_FILE
lists the cache keys of earlier runs, one per line. The output has three
lines:

    matrix   the releases and modes to test in the game
    remind   true when the stable release is newer than the pin, and no
             earlier run at this commit sent the reminder
    stable   the stable release

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
    found = versions(latest)
    if not found:
        return [f"{URL} has no stable and experimental headless versions; "
                "its format may have changed"]
    if not SEMVER.match(pinned):
        return [f".factorio-version holds {pinned!r}, not X.Y.Z"]
    if _numbers(found["stable"]) > _numbers(pinned):
        return [f"Factorio {found['stable']} is the stable release, but .factorio-version "
                f"pins {pinned}. Open a PR that moves the pin."]
    return []


MODES = ("base", "space-age")


def plan(found: dict[str, str], pinned: str, sha: str, keys: set[str]) -> dict:
    """What watch.yml still has to do at commit sha. keys are the cache
    keys of earlier runs: a key marks a test or a reminder as done."""
    releases = sorted({v for v in found.values() if v != pinned}, key=_numbers)
    matrix = [{"version": v, "mode": m} for v in releases for m in MODES
              if f"watch-{v}-{m}-{sha}" not in keys]
    newer = _numbers(found["stable"]) > _numbers(pinned)
    remind = newer and f"watch-pin-{found['stable']}-{sha}" not in keys
    return {"matrix": matrix, "remind": remind}


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
    if not (command == [] or (command == ["plan"] and len(argv) == 4)):
        print(USAGE, file=sys.stderr)
        return 2
    try:
        latest = fetch()
    except (OSError, ValueError) as error:
        print(f"factorio version: cannot read {URL}: {error}", file=sys.stderr)
        return 1
    pinned = read_pin()
    found = problems(latest, pinned)
    if command == ["plan"] and versions(latest):
        keys = set(pathlib.Path(argv[3]).read_text(encoding="utf-8").split())
        result = plan(versions(latest), pinned, argv[2], keys)
        print(f"matrix={json.dumps(result['matrix'])}")
        print(f"remind={'true' if result['remind'] else 'false'}")
        print(f"stable={versions(latest)['stable']}")
        return 0
    for problem in found:
        print(f"factorio version: {problem}", file=sys.stderr)
    if not found:
        print(f"factorio version: {pinned} is the newest stable release")
    return 1 if found else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
