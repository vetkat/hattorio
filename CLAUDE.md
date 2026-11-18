# Hattorio

Hattorio is a Factorio mod. It divides each planet into cells of the
aperiodic "hat" tiling. The mod is in Lua. The offline tools in `tools/` are
in Python.

## Checks

On a fresh clone, run `make setup` once. It installs the npm tools and turns
on the git hook.

- `make fast` runs before each commit, through the git hook. It runs the
  version check, the quick Python tests, busted under Lua 5.2 and luacheck.
  It also runs markdownlint, the internal links and the prose check. It must
  stay under about 10 seconds.
- `make text` is the prose check. It reads Markdown, the locale file and the
  comments of the code. Fix the text when it fails. Add an entry to
  `.ste-allow` only for a false positive, and give the reason.
- `make check` runs before a PR. It adds the slow offline pipeline tests and
  the in-game tests in the Factorio headless server, with and without Space
  Age.

`docs/design/toolchain-decisions.md` describes the CI jobs, the version
rules, the changelog and the release workflow.

## Writing

- Write all prose in British English: Markdown, code comments, docstrings and
  commit messages.
- Use the /ste80-humanizer skill for new prose and for commit messages.
- In `mod-description-long.md`, keep the author's first-person voice.

## Skills

Use these skills on this repository:

- **/egm**: review design documents and plans in `docs/`, and find text that
  no longer agrees with the code.
- **/ste80-humanizer**: write and rewrite prose.
- **/simplify**: clean up changed code before a commit.

## Workflow

1. Create a branch from `main`.
2. Add each change that a player can see to `CHANGELOG.md`, under
   Unreleased. Update `ROADMAP.md` when a change affects it. Never edit
   `changelog.txt`: the build makes it from `CHANGELOG.md`.
3. Commit in this order. Run each command as a Bash call of its own:
   1. Run `/ste80-humanizer` in British English on changed prose and
      comments.
   2. Run `/simplify` on changed code.
   3. `git add` the files, then `make stamp`, then `git commit`. Do not use
      `git commit -a` or paths after `git commit`. The git hook refuses a
      commit from Claude Code without a current stamp.
4. Push the branch and open a PR. The PR title is a Conventional Commit, for
   example `fix: keep bands off water`. GitHub squash merges the PR, so the
   title becomes the commit message on `main`.

Merge or push to `main` only when the owner asks.

## Reference project

`~/Documents/Abominable-Ordnance` is a newer Factorio mod by the same author.
Hattorio took its CI, its version rules, `CHANGELOG.md` and `ROADMAP.md` from
it, and adapted them. Read it when you change these subjects. The details
are in `docs/superpowers/specs/2026-11-12-repo-and-ci-design.md` in that
repository.
