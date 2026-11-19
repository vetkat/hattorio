# Changelog

All notable changes to Hattorio are in this file. The format follows
[Keep a Changelog 1.0.0](https://keepachangelog.com/en/1.0.0/), and the mod
uses [semantic versioning](https://semver.org/spec/v2.0.0.html). The version
rules for this mod are in
[toolchain-decisions.md](docs/design/toolchain-decisions.md#versions).

This is the only changelog that people edit. The build makes Factorio's
`changelog.txt` from it, and the GitHub release notes come from it too.

## [Unreleased]

## [1.1.0] - 2026-11-19

### Added

- Another mod can give a surface the cells of a planet, through the remote
  interface `hattorio`. A mod that gives each team its own copy of a planet
  can use it, so that all teams build on the same floor plan.
  [The design document](docs/design/hattorio-design.md#8-terrain-generation) describes
  the interface.

### Fixed

- A chunk that another mod filled with a copy of a tiled chunk got its ore
  richness raised a second time, when the game called that mod first.
- A new surface could get the geometry of a deleted surface. The game gives
  the index of a deleted surface to a new one, and the mod kept the geometry
  for the index.
- On Aquilo, a few band tiles near a chunk border turned into snow or ice.
  Crude oil, lithium brine and fluorine vents stamp snow and ice around
  themselves. A stamp from a new chunk reached the bands of the chunk next
  to it. No set-tile effect replaces a band tile now. The crater of a
  nuke also leaves the bands in place.

## [1.0.2] - 2026-11-18

### Fixed

- You could pave a band with a floor tile and then build on it. Stone brick,
  concrete and landfill did this, and in Space Age also foundation, ice
  platform and the Gleba soils. No floor tile can go on a band now.
- You could build a cargo bay on a band. It is blocked now, like the other
  structures.

### Changed

- Clearer descriptions for the band appearance, band colour, ore richness
  and band width settings.
- The band width labels now call the default width of 3 "normal", like the
  default cell size. The labels are 1 thin, 2 narrow, 3 normal and 4 wide.

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

[Unreleased]: https://github.com/vetkat/hattorio/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/vetkat/hattorio/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/vetkat/hattorio/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/vetkat/hattorio/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/vetkat/hattorio/compare/v0.1.1...v1.0.0
[0.1.1]: https://github.com/vetkat/hattorio/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/vetkat/hattorio/releases/tag/v0.1.0
