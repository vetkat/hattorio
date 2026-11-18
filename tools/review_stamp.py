"""Block an agent commit until the agent runs the review skills.

A hook cannot run a skill, but it can refuse the commit until the agent
runs them. `make stamp` saves the hash of the staged tree. Two hooks
then work together:

- The git pre-commit hook runs `python3 -m tools.review_stamp check` for a
  commit from Claude Code (`CLAUDECODE` is set). During a commit, git points
  `git write-tree` at the exact index that it is about to commit, so the
  check holds for -a, -i, -o and paths too.
- The Claude Code PreToolUse hook runs `python3 -m tools.review_stamp`
  before each Bash command. It makes sure that the git hook runs: it
  refuses a commit while core.hooksPath is not .githooks, and a commit
  with --no-verify.

    python3 -m tools.review_stamp stamp   # make stamp
    python3 -m tools.review_stamp check   # the git pre-commit hook
    python3 -m tools.review_stamp         # the Claude Code hook (JSON on stdin)
"""
from __future__ import annotations

import json
import os
import pathlib
import re
import subprocess
import sys
from typing import TextIO

# git commit at the start of a command line, or after `;`, `&`, `|`, `(` or a
# shell keyword, with git's own options before it.
COMMIT = re.compile(
    r"(?:^|[;&|(]|\bthen\b|\bdo\b)[ \t]*git\s+"
    r"(?:(?:-C|-c)\s+\S+\s+|--?[\w-]+(?:=\S+)?\s+)*commit(?![\w-])", re.MULTILINE)
# --no-verify, or -n alone or in a cluster such as -qn, before the command ends.
NO_VERIFY = re.compile(r"^[^;&|\n]*?\s(?:--no-verify\b|-[a-zA-Z]*n[a-zA-Z]*\b)")

REVIEW_STEPS = """The staged files have no current review stamp. Before you commit:
1. Run /ste80-humanizer (British English) on staged prose and comments.
2. Run /simplify on staged code.
3. Stage the results, then run `make stamp`.
Then commit again. A commit with -a or with paths changes what is
committed, so stage first and commit without them."""


def is_commit(command: str) -> bool:
    return COMMIT.search(command) is not None


def guard(command: str, hooks_path: str | None) -> tuple[int, str]:
    """The Claude Code hook. Exit code 2 blocks the command."""
    match = COMMIT.search(command)
    if match is None:
        return 0, ""
    if hooks_path != ".githooks":
        return 2, "The git hook is not active. Run `make setup`, then commit again."
    if NO_VERIFY.match(command[match.end():]):
        return 2, "Do not commit with --no-verify or -n: the git hook must run."
    return 0, ""


def check(tree: str | None, stamp: str | None) -> tuple[int, str]:
    """The git pre-commit hook. A non-zero exit code stops the commit."""
    if tree is None or stamp != tree:
        return 1, REVIEW_STEPS
    return 0, ""


def git(*args: str) -> str | None:
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def stamp_file() -> pathlib.Path | None:
    path = git("rev-parse", "--git-path", "review-stamp")
    return pathlib.Path(path) if path else None


def report(code: int, message: str) -> int:
    if message:
        print(message, file=sys.stderr)
    return code


def main(argv: list[str], stdin: TextIO, env: dict[str, str]) -> int:
    if argv[1:] == ["stamp"]:
        tree, path = git("write-tree"), stamp_file()
        if tree is None or path is None:
            return report(1, "review stamp: not in a git repository")
        path.write_text(tree + "\n", encoding="utf-8")
        print(f"review stamp: {tree}")
        return 0
    if argv[1:] == ["check"]:
        if not env.get("CLAUDECODE"):
            return 0  # a human commit: the review skills are the agent's job
        path = stamp_file()
        stamp = path.read_text(encoding="utf-8").strip() if path and path.exists() else None
        return report(*check(git("write-tree"), stamp))
    try:
        command = json.load(stdin)["tool_input"]["command"]
    except (ValueError, KeyError, TypeError):
        return 0
    if not isinstance(command, str) or not is_commit(command):
        return 0
    return report(*guard(command, git("config", "--get", "core.hooksPath")))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv, sys.stdin, dict(os.environ)))
