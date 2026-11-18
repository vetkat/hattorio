# Changelog

All notable changes to Hattorio are in this file. The format follows
[Keep a Changelog 1.0.0](https://keepachangelog.com/en/1.0.0/), and the mod
uses [semantic versioning](https://semver.org/spec/v2.0.0.html). The version
rules for this mod are in
[toolchain-decisions.md](docs/design/toolchain-decisions.md#versions).

This is the only changelog that people edit. The build makes Factorio's
`changelog.txt` from it, and the GitHub release notes come from it too.

## [Unreleased]

## [1.0.1] - 2026-11-17

### Fixed

- Factorio 2.1 did not load the mod. The mod now targets Factorio 2.1 and
  needs base 2.1.0 or later. Version 1.0.0 stays available for Factorio 2.0.

## [1.0.0] - 2026-11-10

### Changed

- Rewrote the documentation and the code comments in plain British English.
- Corrected documentation that no longer matched the mod.

## [0.1.1] - 2026-09-20

### Changed

- Corrected the mod description. Hattorio divides each planet into cells;
  it does not replace Factorio's square grid, which is part of the engine.
- Corrected the cell size setting description, which quoted buildable tile
  counts measured at an earlier default band width.

## [0.1.0] - 2026-09-20

### Added

- Planets are divided into cells of the aperiodic hat monotile tiling.
- Cells are separated by narrow unbuildable bands. Undergrounds tunnel
  beneath them; rails cross them; bots and power ignore them.

[Unreleased]: https://github.com/vetkat/hattorio/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/vetkat/hattorio/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/vetkat/hattorio/compare/v0.1.1...v1.0.0
[0.1.1]: https://github.com/vetkat/hattorio/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/vetkat/hattorio/releases/tag/v0.1.0
