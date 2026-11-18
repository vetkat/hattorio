"""Exit 1 when the all-checks job of a PR failed and no later run passed.

factorio-version.yml runs this on the open PR that moves the pin. CI on a
PR from the App emails nobody, so the daily job fails instead, and GitHub
emails the maintainer about the failed scheduled run.

    gh pr view <url> --json statusCheckRollup --jq .statusCheckRollup \\
        | python3 -m tools.pr_status
"""
from __future__ import annotations

import json
import sys

JOB = "all-checks"


def red(rollup: object) -> bool:
    """True when all-checks failed, none passed and none is still running.

    A PR edit cancels the run it replaces, and that run reports a red
    all-checks beside the new one, so one green or running result wins.
    """
    runs = [item for item in rollup if isinstance(item, dict) and item.get("name") == JOB
            ] if isinstance(rollup, list) else []
    if any(run.get("status") != "COMPLETED" or run.get("conclusion") == "SUCCESS"
           for run in runs):
        return False
    return any(run.get("conclusion") == "FAILURE" for run in runs)


def main(text: str) -> int:
    try:
        rollup = json.loads(text)
    except ValueError:
        rollup = None
    if red(rollup):
        print(f"pr status: {JOB} failed on this PR", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.stdin.read()))
