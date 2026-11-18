# Toolchain

This page lists the tools that the project actually uses, and the reasons. It
leaves out every proposal that the project did not adopt. The reasons for the
arithmetic choices are in sections 5 and 14 of `hattorio-design.md`.

## Runtime: Lua 5.2.1

This is not a choice. Factorio embeds Lua 5.2.1, and the mod runs inside it.

This has two effects on the code:

- **No integer subtype.** Every number is a double, which is exact only up to
  2^53. For this reason the tiling core stores values and not exact integers.
  See design section 5.
- **`tostring` uses `%.14g` and loses precision.** For this reason a hat's
  identity is a packed descent path (`hat/index.lua`) and never a formatted
  coordinate. The first scaffold made the identity from
  `string.format("%.3f", ...)`. That can give two hats the same id, or give
  one hat two ids.

When the pipeline writes floats for Lua to read, it uses `%.17g`. This format
round-trips a double exactly. A test checks that every written value survives
the round trip.

## Testing: busted and luassert

All the work used red-green-refactor. The tests are in
`spec/*_spec.lua`, and busted finds them through `.busted`.

The tests must run under Lua 5.2 specifically. Lua 5.3 and later add an
integer subtype, so on 5.4 the tests would hide the all-doubles behaviour that
the core depends on. CI pins 5.2 for the same reason.

On Arch, `lua52-busted` installs the rock outside PATH, and its shebang points
at Lua 5.5, where its modules do not exist. The Makefile uses a `busted` on
PATH if there is one. If not, it uses the rock path.

**Property-style tests are plain loops over fixed seeds**, not a generative
library. The project considered `lua-quickcheck` and dropped it. No luarocks
package on Arch includes a CLI, so you can install it only if you build it
from source. Fixed seeds are also easier to reproduce.

## In-game tests: factorio-test

busted cannot run the parts that need the game: the chunk event, the tile
prototypes and `set_tiles`. The tests in `tests/ingame/` run in the Factorio
headless server with the [factorio-test](https://mods.factorio.com/mod/factorio-test)
mod. `make ingame` runs them once with the base game only and once with
Space Age. The CI job `ingame` does the same.

`.factorio-version` pins the Factorio release, and `.factorio-test-version`
pins factorio-test. `tools/ingame.sh` downloads the headless server for the
pinned release. The server is a free download and needs no login. The
factorio-test zip is in `tools/vendor/`.

The tests compare the tiles that the game paints with the bands that
`mod/bands.lua` calculates. Each band position must hold the band tile. Each
test makes a new chunk, because the mod paints only when a chunk generates.
The mod never paves water, so the tests on nauvis turn water off in the map
generator first. Another test makes a chunk with lab tiles: the mod paints
bands on lab tiles too.

## Static analysis: luacheck

`make lint` and CI run luacheck over all the Lua in the repository: `hat/`,
`mod/`, `prototypes/`, `spec/`, `tests/` and the stage entry points such as
`control.lua`. The standard is zero warnings.

**No static type checker.** The project considered Teal and rejected it. It has
no definitions for the Factorio API, so every call to the game would become
an untyped escape hatch. It also adds a build step from `.tl` to `.lua`. The
design phase chose LuaLS annotations, but nobody added them, and the code
has none today. If you want types, use LuaLS annotations, and adopt them
as a deliberate decision.

## Prose check

`make text` checks the prose of the repository: the Markdown files, the
locale file and the comments of the code. The code comments are those of
Lua, of Python (comments and docstrings), and the full-line `#` comments of
shell scripts, workflows and the Makefile. Indented comment lines are tables
or examples, so the check skips them. It skips code spans too.

The check has three parts:

- the checker of the ste80-humanizer skill, a copy in `tools/vendor/`
- cspell with the en-GB dictionary, and the project words in `cspell.json`
- a ban on en dashes

`.ste-allow` lists the findings that are false positives, each with a
reason. An example is "the preview is red", which the checker reads as a
passive.

## Layout

```text
hat/     tiling core, no Factorio dependencies, loads under plain lua5.2
tools/   offline pipeline (Python 3, stdlib only), dev renderers and CI tools
data/    generated Lua data; regenerate with `make data`, never hand-edit
spec/    busted tests, plus fixtures exported from the pipeline
tests/   in-game tests for factorio-test; they never ship
wiki/    source for the GitHub wiki; publish with `make wiki`
```

The important split is this: `hat/` has no Factorio dependencies, so it runs
in CI under plain Lua, and `tools/` never ships. The exact arithmetic stays
offline, where it costs nothing. Only the values ship.

## Verification strategy

The project considered formal verification and dropped it. No practical tools exist
for Lua. The mechanised semantics for Lua are research artefacts, not
verifiers.

In its place, three layers of checks run:

1. **Offline proofs** (`tools/verify.py`). The pipeline checks the generated
   tiling for overlapping hats and for gaps (with a flood fill). It checks
   that the density of reflected hats converges to 1/(phi^4+1), and that the
   hat counts match F(2n+3)^2 exactly.
2. **Golden fixtures.** The pipeline exports a reference patch, and the Lua
   descent must produce the same patch. This tests the code that ships against
   arithmetic with a proof of correctness.
3. **Invariant tests.** `spec/invariants_spec.lua` searches the shipped
   modules for `math.sin`, `math.cos`, `math.random` and `^`. None of these
   give the same bits on all platforms.

## Functional core

The `hat/` modules are pure. They have no mutable state and do not use the
Factorio API, and every function is total over its inputs. Side effects
belong in the layer that talks to Factorio.

The determinism constraint led to this design. The result also matches SUPER
(side effects at the edge, uncoupled logic, pure and total functions, explicit
data flow, replaceable by value). Design section 7 gives the three rules that
make this explicit.

There is one deliberate exception. The descent changes its output accumulator
in place, for speed. The accumulator is local to `hat/tiling.lua` and never
leaves it.

## Continuous integration

`.github/workflows/check.yml` runs on each pull request and on each push to
`main`. Each job calls a make target, so a check gives the same result on
your machine and in CI:

| Job | Make targets |
| --- | --- |
| `python` | `make version`, `make pytest` |
| `lua` | `make test`, `make lint` |
| `text` | `make markdown`, `make links` |
| `ingame` | `make ingame`, once for each mode |

The job `all-checks` passes only when every other job passes. Branch
protection needs this job, and the `pr` job of `.github/workflows/pr.yml`.

The `pr` job runs `tools/pr_checks.py`. It has a workflow of its own, so an
edit of the PR title or a label runs only this small job. It checks two
rules. The PR title must be a Conventional Commit,
because a squash merge makes the title the commit message on `main`. A PR
that changes a file in the mod zip must also change `CHANGELOG.md`, unless
it has the label `no-changelog`.

`make fast` runs the checks that take seconds. The git hook in `.githooks/`
runs it before each commit. `make setup` turns the hook on. The slow tests of
the offline pipeline have the pytest marker `pipeline`. `make fast` leaves
them out, and `make check` and CI run them.

`.github/workflows/watch.yml` runs every three hours. It asks
factorio.com for the newest stable and experimental releases. When a release
differs from `.factorio-version`, it runs the in-game tests in that release,
with and without Space Age. For a new minor version, it first changes
`factorio_version` in its own checkout, because the game does not load a mod
that names another minor version.

The workflow also fails when the stable release is newer than the pin, as a
reminder to move the pin. It tests each release once for each commit on
`main`, so a failure notifies the maintainer once. A run with nothing new to
test starts no test runner.

Factorio 2.1 refused to load Hattorio 1.0.0, which said "2.0", and the
players found the problem first. With this workflow, CI finds a new release
within three hours. It usually finds it while the release is still
experimental, before the players get it.

`.github/workflows/weekly.yml` checks the external links in the Markdown
files each Monday. Dependabot opens a pull request when a GitHub Action or
an npm tool has a new version.

GitHub turns off the schedules of a public repository after 60 days with no
commit, and it sends a warning email first. Hattorio can go quiet for longer
than that. So each run of `watch.yml` also calls the GitHub API to enable
`watch.yml` and `weekly.yml` again, which resets the count. The
[keepalive-workflow](https://github.com/gautamkrishnar/keepalive-workflow)
action does the same in its API mode. GitHub does not document this effect.
If the schedules stop anyway, enable them again on the Actions tab.

## Versions

Hattorio uses [semantic versioning](https://semver.org/spec/v2.0.0.html).
You set the version in `info.json` by hand:

- **Major**: an existing save breaks, or the mod makes different terrain for
  an existing save. A change to the cell geometry or to the band placement
  for the same settings is major, because new chunks would not match the old
  ones. The removal of a setting or a prototype is major too.
- **Minor**: a new feature or setting, a new default that applies only to new
  maps, or a move to a new Factorio minor version.
- **Patch**: a fix or a text change that makes no difference to the terrain.

1.0.1 moved to Factorio 2.1 and was a patch. Factorio 2.1 did not load 1.0.0
at all, so the move was a fix.

## Changelog

`CHANGELOG.md` uses the
[Keep a Changelog 1.0.0](https://keepachangelog.com/en/1.0.0/) format. It is
the only changelog that people edit. Add each change that a player can see
under `Unreleased`. The `pr` job refuses a PR that changes a file in the mod
zip but not `CHANGELOG.md`, unless the PR has the label `no-changelog`.

Factorio reads `changelog.txt` from the mod zip. The in-game mod browser
needs a strict format, and the mod portal shows the same file as plain text.
`tools/package.py` makes `changelog.txt` from `CHANGELOG.md` with
`tools/changelog.py`, and the file is not in the repository.

The tool maps the headings of Keep a Changelog to Factorio's categories.
Added becomes Features. Changed, Deprecated and Removed become Changes.
Fixed and Security become Bugfixes. The tool wraps long entries at 80
characters, so the portal shows readable lines. `make version` and the build
check the result against the rules in Factorio's
[changelog format](https://lua-api.factorio.com/latest/auxiliary/changelog-format.html).

## Releases

`info.json` is the only source of truth for the version. Everything else must
agree with it. `tools/check_version.py` checks this on every push, not only
when you make a release:

- `factorio_version` and the `base` dependency in `info.json` must name the
  major and minor version of `.factorio-version`
- without a tag, the newest section of `CHANGELOG.md` must be `Unreleased`
  or the version in `info.json`
- with a tag, the tag must be `v<version>`, the newest versioned section of
  `CHANGELOG.md` must be that version with a date, and `Unreleased` must have
  no entries
- the `changelog.txt` that the build makes must follow Factorio's format

To make a release, open a PR. It sets the version in `info.json`, and it
renames `Unreleased` in `CHANGELOG.md` to the version and the date. Add a new
empty `Unreleased` section above it. Merge the PR, then tag the merge commit
and push the tag:

```bash
git tag v1.0.2 && git push origin v1.0.2
```

`.github/workflows/release.yml` then does these steps:

1. It fails unless the tagged commit is on `main`.
2. It runs every job of `check.yml`.
3. It checks the version against the tag and builds the zip.
4. It makes a GitHub release with the zip. The notes are the section of
   `CHANGELOG.md` for the version.
5. It uploads the zip to the Factorio mod portal.
6. It sends `mod-description-long.md` to the portal as the long description.

The portal steps need a repository secret called `FACTORIO_API_KEY`. Get the
key from <https://factorio.com/profile>. It needs the *ModPortal: Upload Mods*
permission for the upload, and the *ModPortal: Edit Mods* permission for the
description. The portal steps run in a GitHub environment called
`mod-portal`. You can give that environment a required reviewer, so that a
person approves before the workflow publishes anything.

A manual run of the release workflow has four modes. `dry-run` checks and
builds. `check-credentials` tests the key. `publish` checks, builds and
uploads. `description` only sends the long description.

**You cannot withdraw a release from the portal.** For this reason every check
runs before the upload step and not after it. Also, a branch push never
starts the upload. Only a tag starts it, or a manual run that asks for it
explicitly.
