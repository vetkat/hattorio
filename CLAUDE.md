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
- Write in the tone of the reference project (`README.md` and
  `docs/design.md` there). It is plain and dry. Say what the mod does, and
  give the numbers.
- Address the player as "you". Do not write "I" or "we": name who acts, such
  as the mod, the pipeline or a test.
- Do not sell. Do not stage a point, and do not end on a punchline. The
  subject can be funny, but the sentences stay flat.
- Use bold only for a label at the start of a paragraph or a list item, and
  for a warning. Do not use bold for emphasis inside a sentence.

## Skills

Use these skills on this repository:

- **/egm**: review design documents and plans in `docs/`, and find text that
  no longer agrees with the code.
- **/ste80-humanizer**: write and rewrite prose.
- **/simplify**: clean up changed code before a commit.

## Review angles

Code review checks the angles that match the paths a PR changes.

- **`control.lua`, `mod/`, or code that reads or writes `storage`:**
  multiplayer safety (no desync), save compatibility
  (`on_configuration_changed`, new `storage` keys), and compatibility with
  other mods.
- **`mod/interface.lua`:** the remote interface is a public contract. Do
  not rename or remove a call. Raise `interface_version` for each change
  that a caller can see.
- **`prototypes/`, `data*.lua`, `settings.lua`:** compatibility with other
  mods and with Space Age.
- **Event handlers, `on_nth_tick`, `hat/`:** performance (UPS).
- **`spec/`, `tests/`:** test quality. Each test fails for the right
  reason.
- **`.github/`, `tools/`, `Makefile`:** security, with `/security-review`.

A PR merges only with no open Critical or Important finding. Review in
rounds:

1. The reviewers check the PR: EGM for a design document or a plan, the
   angles above for code.
2. Fix every Critical and Important finding, and each minor one that is
   cheap to fix. A code fix gets a test that fails first.
3. The same reviewers check the changed text or diff again.
4. Stop when a round finds no new Critical or Important finding. After 5
   rounds, stop and give the open findings to the owner.

The PR description gives one verdict for each angle: `pass`, `n/a`,
`fixed: <what>` or `minor: <what>`. The CI job `pr` refuses any other
verdict, a blank one, or a missing section. The label `no-review` skips
this check, and Dependabot PRs skip it too.

## Workflow

1. Create a branch from `main`.
2. Add each change that a player can see to `CHANGELOG.md`, under
   Unreleased. Update `ROADMAP.md` when a change affects it. Never edit
   `changelog.txt`: the build makes it from `CHANGELOG.md`.
   `description.yml` sends `mod-description-long.md` to the mod portal as
   soon as a change to it reaches `main`. So describe a new feature there
   only in the PR for its release. A fix to the text can go in any PR.
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
