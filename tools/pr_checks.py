"""Checks that only make sense on a pull request.

1. The PR title is a Conventional Commit. PRs are squash merged, so the
   title becomes the commit message on main.
2. A PR that changes a file that ships in the mod zip also changes
   CHANGELOG.md, unless it has the label no-changelog.
3. The PR description has a "Review angles" section with a verdict for
   each angle, and no open Critical or Important finding. Dependabot PRs
   and PRs with the label no-review skip this rule.

CI runs this on pull_request events. It reads the event from
GITHUB_EVENT_PATH.

    python3 -m tools.pr_checks
"""
from __future__ import annotations

import json
import os
import pathlib
import re
import subprocess
import sys

from tools import package

TYPES = ("feat", "fix", "docs", "style", "refactor", "perf", "test",
         "build", "ci", "chore", "revert")
TITLE = re.compile(r"^(?P<type>[a-z]+)(?:\([\w./-]+\))?!?: \S")
MAX_TITLE = 72
LABEL = "no-changelog"
REVIEW_LABEL = "no-review"
BOTS = ("dependabot[bot]",)
ANGLES = ("Multiplayer safety", "Save compatibility", "Mod compatibility",
          "Performance (UPS)", "Test quality", "Security")
# pass, n/a, fixed: <what>, or minor: <what>. Anything else, such as
# "Important: <what>", is an open finding that blocks the merge.
VERDICT = re.compile(r"^(pass|n/a|(fixed|minor):\s*\S.*)$", re.IGNORECASE)


def title_problems(title: str) -> list[str]:
    match = TITLE.match(title)
    if not match or match["type"] not in TYPES:
        return [f"PR title {title!r} is not a Conventional Commit, "
                f"for example 'fix: keep bands off water'. Types: {', '.join(TYPES)}"]
    if len(title) > MAX_TITLE:
        return [f"PR title has {len(title)} characters; the limit is {MAX_TITLE}"]
    return []


def is_mod_code(path: str) -> bool:
    """True for a file that ships in the mod zip."""
    return any(path == entry or path.startswith(entry + "/") for entry in package.SHIP)


def changelog_problems(changed: list[str], labels: list[str]) -> list[str]:
    if LABEL in labels or "CHANGELOG.md" in changed:
        return []
    code = [path for path in changed if is_mod_code(path)]
    if not code:
        return []
    return [f"this PR changes mod files ({', '.join(code[:3])}) but not CHANGELOG.md. "
            f"Add an entry under Unreleased, or add the label {LABEL}."]


def review_section(body: str) -> str | None:
    match = re.search(r"^## Review angles[ \t]*$(.*?)(?=^## |\Z)", body,
                      re.MULTILINE | re.DOTALL)
    return match[1] if match else None


def review_problems(body: str | None, labels: list[str], author: str) -> list[str]:
    if REVIEW_LABEL in labels or author in BOTS:
        return []
    section = review_section(body or "")
    if section is None:
        return ["the PR description has no '## Review angles' section. "
                "Copy it from .github/pull_request_template.md."]
    verdicts = {}
    for line in section.splitlines():
        match = re.match(r"^- ([^:]+):(.*)$", line.strip())
        if match:
            verdicts[match[1].strip()] = match[2].strip()
    problems = []
    for angle in ANGLES:
        verdict = verdicts.get(angle)
        if verdict is None:
            problems.append(f"the review section has no line for {angle}")
        elif not VERDICT.match(verdict):
            problems.append(f"{angle}: {verdict!r} is not pass, n/a, fixed: or minor:. "
                            "Fix an open Critical or Important finding before merge.")
    return problems


def main(env: dict[str, str]) -> int:
    event = json.loads(pathlib.Path(env["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    pull = event["pull_request"]
    labels = [label["name"] for label in pull.get("labels", [])]
    diff = subprocess.run(
        ["git", "diff", "--name-only", f"{pull['base']['sha']}...{pull['head']['sha']}"],
        capture_output=True, text=True, check=True)
    found = (title_problems(pull["title"])
             + changelog_problems(diff.stdout.splitlines(), labels)
             + review_problems(pull.get("body"), labels, pull["user"]["login"]))
    for problem in found:
        print(f"pr check: {problem}", file=sys.stderr)
    if not found:
        print("pr check: the title, the changelog and the review angles are fine")
    return 1 if found else 0


if __name__ == "__main__":
    raise SystemExit(main(dict(os.environ)))
