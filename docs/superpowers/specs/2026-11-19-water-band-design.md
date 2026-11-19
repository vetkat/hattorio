# Band positions over water

Issue #21. Status: design, for approval by the owner.

## Intent

The mod paints no band over water (design §8, "Do not fill water"). So a
band position that is water has no band tile and no band layer. Two things
can then turn it into land, and the band gets a gap that you can build
across:

- **Landfill and other floor tiles.** Landfill goes only on water. The 1.0.2
  patch blocks floor tiles only on tiles that have the band layer. On
  Nauvis, a player who fills a lake that a band crosses gets a land gap.
  This needs no luck, so it will happen in most games.
- **Set-tile stamps.** An Aquilo stamp from a later chunk can turn ammonia
  ocean at a band position into ice. #22 protects band tiles from stamps,
  but not this water.

Design §4 says that an underground belt must cross every band. A land gap
breaks that rule.

## Goals

- Every band position has the band layer, also where the ground is water.
- Landfill, foundation and the other floor tiles cannot go on a band
  position over water.
- No set-tile stamp turns a band position over water into land.
- Lakes stay lakes: the same look, the same shores, the same collision.

## Non-goals

- Old chunks. Chunks that generated before this change keep plain water,
  as with every other terrain change.
- A visible band over water. The owner chose the look that is the same as
  the water.

## Approaches

- **A. A band copy of each water tile,** painted at band positions. It
  covers landfill and stamps. It costs one tile prototype per water tile.
- **B. Repaint land on band positions at runtime,** after each tile
  placement. It covers landfill but not stamps, which raise no event. It
  costs an event handler on each tile placement.
- **C. Accept and document the gap.** It covers nothing and breaks §4.

The owner chose A, because it is the only approach that closes both gaps.
It reuses the two existing patches and adds no work per tick.

A spike on Nauvis (seed 7, `water` and `deepwater`) compared two looks:
water that looks the same, and darker water. In both, the shore transitions looked
the same as vanilla, and no seam showed between a copy and its lake. The
owner chose the look that is the same as the water.

## Design

- **Data stage, in `data-final-fixes`.** For each tile prototype whose
  collision mask has `water_tile` and does not have `out_of_map`, the mod
  adds a copy named `hattorio-band-water-<name>`. The copy:
  - adds the band layer to the collision mask, and keeps every other layer
  - keeps the graphics, the effect, the colours, the map colour and the
    fluid of the original
  - sets `transition_merges_with_tile` to the original, so no seam shows
  - has no autoplace and does not appear in blueprints
  - goes into `water_tile_type_names`, so that land tiles draw their shore
    transitions to it

  This covers water, shallow water, the Aquilo ammonia ocean, Vulcanus
  lava, the Fulgora oil oceans and the water tiles of other mods.
- **The painter.** At a band position that is water, the painter places the
  copy of that water tile. It skips a tile that has no copy, such as
  out-of-map.
- **No new patch.** The floor-tile condition (1.0.2) and the set-tile mask
  (1.1.0) already contain the band layer. So they refuse the copy, as they
  refuse a band tile.

## Consequences

- **Offshore pumps.** The offshore pump is in the list of structures that
  collide with the band. So you cannot place an offshore pump on a band
  position over water. Most of the shore stays open.
- **The look gives no hint.** You see that a band crosses a lake only from
  the red preview when you try to place landfill there.
- **Every structure** that collides with the band also cannot go on the
  copy. Over water, that adds only the offshore pump and the water-only
  structures of other mods.

## Tests

In-game tests, each one failing without the change:

- A new chunk with water at band positions holds the copy there, and land
  band tiles elsewhere.
- No item that places a tile can place it on a copy. This extends the
  existing test in `tests/ingame/collision_test.lua`.
- With Space Age: `aquilo-tiles-outer-explosion` does not replace a copy of
  the ammonia ocean. Its mask has `ground_tile` and `resource`, so without
  the band layer it replaces ocean. `nuke-effects-nauvis` cannot serve
  here, because its mask has `water_tile` and it never replaces water.
- With Space Age: the ammonia ocean on Aquilo and lava on Vulcanus get
  copies.

## Left to the builder

- The exact selection of water tiles, if a tile in base or Space Age does
  not fit the rule above.
- The text in the design document (§8, §16), the changelog and the issue.
