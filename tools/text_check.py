"""Check the prose in Markdown, locale files and the comments of the code.

The code is Lua, Python (comments and docstrings), and the full-line #
comments of shell scripts, workflows and the Makefile.

The rules: the findings of the humanizer checker in `tools/vendor/`, no en dash
(the checker only flags em dashes), and cspell with the en-GB dictionary.
.ste-allow lists accepted exceptions. Each entry names a rule, a file
pattern, an optional word and a reason:

    spelling | docs/superpowers/reviews/*.md | color | quotes the old spec

    python3 -m tools.text_check            # every tracked file
    python3 -m tools.text_check FILE ...   # only these files
"""
from __future__ import annotations

import fnmatch
import pathlib
import re
import subprocess
import sys
import tempfile
from typing import NamedTuple

from tools import prose
from tools.vendor import ste_check

ROOT = pathlib.Path(__file__).resolve().parents[1]
EN_DASH = "–"
# Copied code keeps its upstream text.
SKIP = ("tools/vendor/",)
EXTRACT = {
    "markdown": prose.markdown_prose,
    "lua": prose.lua_prose,
    "locale": prose.locale_prose,
    "python": prose.python_prose,
    "hash": prose.hash_prose,
}
LUA_NAMES = (".luacheckrc", ".busted")
HASH_NAMES = ("Makefile", ".githooks/pre-commit", ".gitignore")
CSPELL_BIN = "node_modules/.bin/cspell"
CSPELL = re.compile(r"^(?P<file>.+?):(?P<line>\d+):\d+ - Unknown word \((?P<word>[^)]+)\)")


class Finding(NamedTuple):
    path: str
    line: int
    rule: str
    message: str
    excerpt: str


class Allow(NamedTuple):
    rule: str
    path: str  # an `fnmatch` pattern
    word: str  # empty: any finding of this rule in these files
    reason: str


def kind(path: str) -> str | None:
    if path.startswith(SKIP):
        return None
    if path.endswith(".md"):
        return "markdown"
    if path.endswith(".lua") or path in LUA_NAMES:
        return "lua"
    if path.endswith(".py"):
        return "python"
    if path.endswith((".sh", ".yml", ".yaml", ".toml")) or path in HASH_NAMES:
        return "hash"
    if path.startswith("locale/") and path.endswith(".cfg"):
        return "locale"
    return None


def prose_of(path: str, text: str) -> str:
    found = kind(path)
    return EXTRACT[found](text) if found else ""


def _style(path: str, text: str) -> list[Finding]:
    # The checker skips Markdown code itself, so it gets the Markdown without
    # its link definitions, which are not prose.
    if kind(path) == "markdown":
        source = prose.without_link_definitions(text)
    elif kind(path) == "locale":
        return _locale_style(path, text)
    else:
        source = prose_of(path, text)
    return [Finding(path, f.line, f.rule, f.message, f.excerpt)
            for f in ste_check.check(source, False)]


def _locale_style(path: str, text: str) -> list[Finding]:
    # Each locale entry stands alone. Checked together, a section of short
    # names reads as one long sentence.
    found = []
    for no, value in enumerate(prose_of(path, text).split("\n"), 1):
        if value:
            found += [Finding(path, no, f.rule, f.message, f.excerpt)
                      for f in ste_check.check(value + "\n", False)]
    return found


def _dashes(path: str, prose_text: str) -> list[Finding]:
    return [Finding(path, no, "en-dash", "en dash: use 'to', a hyphen or a comma",
                    line.strip()[:100])
            for no, line in enumerate(prose_text.split("\n"), 1) if EN_DASH in line]


def check_files(texts: dict[str, str]) -> list[Finding]:
    found: list[Finding] = []
    for path in sorted(texts):
        if kind(path) is None:
            continue
        found += _style(path, texts[path]) + _dashes(path, prose_of(path, texts[path]))
    return found


def parse_allow(text: str) -> tuple[list[Allow], list[str]]:
    allows, problems = [], []
    for no, line in enumerate(text.splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = [field.strip() for field in line.split("|")]
        if len(fields) != 4:
            problems.append(f".ste-allow line {no}: use 'rule | path | word | reason'")
            continue
        rule, path, word, reason = fields
        if not rule or rule == "*" or not path or not reason:
            problems.append(f".ste-allow line {no}: an entry needs a rule (not *), "
                            "a path and a reason")
            continue
        allows.append(Allow(rule, path, word, reason))
    return allows, problems


def allowed(finding: Finding, allows: list[Allow]) -> bool:
    return any(a.rule == finding.rule
               and fnmatch.fnmatchcase(finding.path, a.path)
               and (not a.word or a.word.lower() in finding.excerpt.lower())
               for a in allows)


def spelling_findings(output: str) -> list[Finding]:
    """Read cspell's output. Each copy of the prose has the name <path>.txt."""
    found = []
    for line in output.splitlines():
        match = CSPELL.match(line.strip())
        if match:
            path = match["file"].removeprefix("./").removesuffix(".txt")
            found.append(Finding(path, int(match["line"]), "spelling",
                                 "not in the en-GB dictionary", match["word"]))
    return found


def missing_tools(root: pathlib.Path) -> list[str]:
    """The tools that the text check needs and cannot find under root."""
    if not (root / CSPELL_BIN).exists():
        return ["cspell is missing: run `npm ci`, then try again"]
    return []


def spelling(cspell: pathlib.Path, config: pathlib.Path,
             prose_by_path: dict[str, str]) -> list[Finding]:
    """Run cspell once over copies of the prose, named <path>.txt."""
    names = []
    with tempfile.TemporaryDirectory() as tmp:
        for path, text in prose_by_path.items():
            target = pathlib.Path(tmp, path + ".txt")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
            names.append(path + ".txt")
        if not names:
            return []
        result = subprocess.run(
            [str(cspell), "--no-progress", "--no-summary",
             "--no-color", "--dot", "--config", str(config), *names],
            cwd=tmp, capture_output=True, text=True)
    if result.returncode not in (0, 1):
        raise SystemExit(f"text check: cspell failed:\n{result.stdout}{result.stderr}")
    return spelling_findings(result.stdout)


def tracked(root: pathlib.Path) -> list[str]:
    result = subprocess.run(["git", "ls-files", "-z"], cwd=root,
                            capture_output=True, text=True, check=True)
    return [p for p in result.stdout.split("\0") if p and (root / p).is_file()]


def relative(path: str) -> str:
    return pathlib.Path(path).resolve().relative_to(ROOT).as_posix()


def main(argv: list[str]) -> int:
    missing = missing_tools(ROOT)
    for tool in missing:
        print(f"text check: {tool}", file=sys.stderr)
    if missing:
        return 1
    paths = [relative(p) for p in argv[1:]] or tracked(ROOT)
    texts = {p: (ROOT / p).read_text(encoding="utf-8") for p in paths if kind(p)}
    allow_file = ROOT / ".ste-allow"
    allow_text = allow_file.read_text(encoding="utf-8") if allow_file.exists() else ""
    allows, problems = parse_allow(allow_text)
    findings = check_files(texts) + spelling(
        ROOT / CSPELL_BIN, ROOT / "cspell.json",
        {p: prose_of(p, t) for p, t in texts.items()})
    left = sorted(f for f in findings if not allowed(f, allows))
    for problem in problems:
        print(f"text check: {problem}", file=sys.stderr)
    for f in left:
        print(f"{f.path}:{f.line}: {f.rule}: {f.message} ({f.excerpt})")
    if left:
        print(f"text check: {len(left)} finding(s). Fix the text, or add an entry "
              "with a reason to .ste-allow.", file=sys.stderr)
    return 1 if left or problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
