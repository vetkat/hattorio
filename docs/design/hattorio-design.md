# Hattorio design

Status: describes version 1.0.2
Date: 2026-11-18 (first draft 2026-09-19)

Hattorio is a Factorio mod. It divides the buildable area of each planet into
cells of the aperiodic "hat" monotile tiling, with unbuildable bands between
the cells.

The mod does NOT replace Factorio's square grid. That grid is part of the
engine, and Lua cannot reach it (see section 2). The mod changes where you may
build, and that is enough.

[`toolchain-decisions.md`](toolchain-decisions.md) describes the tools, the
tests, CI and the releases.

## 1. Goal

Make imported Cartesian blueprints useless, and make players build organic
factories that do not repeat.

The tiling is a means to that goal. Every decision below answers one
question: does it serve the goal?

### Non-goals

- A cosmetic change to the grid. Rejected: a buildable band puts no
  mechanical pressure on the player, and blueprints keep working.
- Parity with [Hextorio](https://mods.factorio.com/mod/hextorio). Its claims,
  cores, trades and economy make a different game.
- Mechanics for territory, claims or ownership. Deferred completely.

## 2. What the engine forbids

This section settles these points. Do not argue them again during
implementation.

- **Tiles are 1x1 and aligned to the axes.** Tile storage, collision boxes,
  belt transport lines, pipe and inserter connections, the pathfinder and
  blueprints are all C++ code, and they all expect a square grid. No mod can
  give the unit of construction a hat shape.
- **Entities are integer boxes aligned to the axes**, in 4 (or 8)
  directions. Nothing rotates to 30 degrees.
- **Blueprints rotate in 90 degree steps.** This is why the mechanism works
  (see section 3).

So the mod controls *where* you may build. It never controls *what shape*
things have.

## 3. Mechanism: why blueprints break

Two effects add together.

**Cells are too small.** A standard city block is 100x100, and even a modest
mall is about 30x30. `Config.CELL_STATS` in `mod/config.lua` holds the
measured cell area, the largest square that fits every cell, and the
drillable fraction for every size and band that the dropdowns offer. The
table at the end of this section gives the values at band 3.

**Every cell has a different shape.** This is what really breaks blueprints.
Orientation does not.

Hats occur in 12 classes: 6 rotations at multiples of 60 degrees, times 2
chiralities. The frequencies are nearly uniform (about 14.5% for each
unreflected class and about 2.1% for each reflected class). Factorio rotates
blueprints in 90 degree steps, so 0/180, 60/240 and 120/300 each collapse to
one class. Factorio 2.0 and later can also flip, which maps reflected classes
onto unreflected ones. So orientation alone would need only about 3
layouts.

An earlier draft of this document said 12, which overstated the case.

The real cause is the placement at sub-tile offsets. Hat positions are
irrational multiples of the tile pitch. So every cell sits at a different
offset and rasterises in a different way. Measured over 1,156 hats:

| | size 26 / band 2 | **size 41 / band 3 (default)** |
| --- | --- | --- |
| orientation classes | 12 | 12 |
| **distinct buildable tile masks** | **624** | **885** |
| most common single mask | 1.1% of cells | **0.5% of cells** |

No single cell shape covers more than about 1% of the map. You must fit a
layout that fills a cell to that cell.

**What still works** is the real limit of the mechanism: a blueprint with a
margin transfers without problems. Anything up to the worst-case inscribed
square fits every cell.

At the default band width of 3:

| size / band | reusable in every cell | cell area |
| --- | --- | --- |
| 15 / 3 | up to 5x5 | 63 t |
| 26 / 3 | up to 10x10 | 294 t |
| **41 / 3** | **up to 17x17** | **858 t** |
| 52 / 3 | up to 22x22 | 1,473 t |

These values come from `Config.CELL_STATS`, and a test checks that no
combination is missing.

A smelter block is about 20x20 and a mall is about 30x30. So every size up to
41 breaks real imported blueprints and still leaves room to build.

The average case is not easier than the worst case. Across orientations the
cell area spreads by about 5%. The measurement was at size 20, band 1 (221,
228 and 233 tiles), which the dropdowns no longer offer. The reason is that
every cell is the same shape rotated, and only the rasterisation changes.

## 4. Gameplay rules

- **Bands are unbuildable, but you can walk and drive on them.** Only
  buildable structures get the band collision layer (section 9), so nothing
  keeps the player or vehicles inside a cell.
- **Undergrounds go under bands.** This is the intended connection between
  cells and the main source of spaghetti. Every crossing costs an
  underground pair, placed against an edge that is not parallel to an axis.
  Underground belts and pipes-to-ground reach 4 to 10 tiles.
- **Some crossings at width 4 need the fast underground belt.** The basic
  underground belt crosses at most 4 tiles. Along the better axis, a band on
  an edge at 30 or 60 degrees is about 1.15 times its width wide. At width 4
  that is about 4.6 tiles before rounding. A script measured all 16
  combinations of size and width. At each one, every cell has at least one
  crossing of at most 4 band tiles, and every cell can reach every other
  cell.
- **Rails are exempt** and can cross bands. The design considered removing
  trains completely, and rejected it because it takes away too much.
- **Mining drills are not exempt.** The mod raises resource richness to
  compensate (see section 8).
- **Power poles are not exempt, but wires cross bands.** Bots ignore bands.
  They are the natural relief in the late game, and they arrive with normal
  progression.
- **Bands are permanent.** No technology, item or claim removes them. Bands
  are the identity of the mod, and players must not be able to optimise them
  away.
- **The start has no grace area.** At the default 41/3, the spawn cell holds
  about 858 buildable tiles. That is enough for a burner start. Bands are
  walkable, so everything is reachable before underground belts arrive. A
  grace area would weaken the premise exactly where a new player forms an
  impression. The cell size setting is the escape hatch.

## 5. Geometry and arithmetic

### Doubles, not exact integers

**This reverses an earlier decision in this document.** The first design
stored every coordinate as four exact integers in `Z[phi][sqrt3]`. That
design confused two different things. The implementation showed that it was
both unnecessary and unworkable.

The desync risk in Factorio is `math.sin`, `math.cos` and `^`/`pow`, because
their libm implementations really are different on different platforms. But
IEEE-754 requires correct rounding for `+ - * /` and `sqrt`, so they give
the same bits everywhere. The Lua interpreter runs each operation as a
separate VM instruction, so no compiler can contract two of them into an FMA.
Factorio runs on 64-bit x86 and ARM processors, which do double arithmetic
without the 80-bit excess precision of x87. Here, doubles are exactly as
deterministic as integers. They are only less accurate.

Measured against exact values from the offline pipeline, at an older hat
scale:

```text
depth   coverage       relative error   absolute error
   8      26,660 t       5.7e-16          8e-12 tiles
  10     183,419 t       4.3e-16          7e-11 tiles
  12   1,194,588 t       5.3e-16          4e-10 tiles
```

The relative error stays at machine epsilon and does not grow with depth,
because the composition is well conditioned. At depth 12 the error is four
ten-billionths of a tile.

Exact integers could not go past depth 4. The numerators of the level-6
rules are 1.4e14, so one composition makes a raw product near 1e28, far past
2^53. A reduction after the product comes too late. A cross-reduction before
it does not help either. The measured gcd of the operands is 1, because the
cancellation is additive (inside the sums) and not multiplicative.

So a transform is six plain doubles, and `hat/exact.lua` does not exist. The
exact arithmetic stays where it belongs: offline, in `tools/`, where it
derives the rules and checks them. Only the values ship.

The modules in `hat/` must never contain `math.sin`, `math.cos`,
`math.random` or `^`. An invariant test searches those four modules for
them. It does not search `mod/` or `prototypes/`.

### Depth and coverage

The mod derives the depth for each surface from the size setting, and stores
it when it creates the surface. Nobody sets it. Coverage grows linearly with
the hat size, so a smaller hat needs a deeper root.
`Ti.depth_covering(unit, cover)` picks the shallowest depth whose root
reaches `Config.REQUIRED_COVER`, which is 1.6e6 tiles:

| size | depth | root coverage |
| --- | --- | --- |
| 15 | 12 | 1.67e6 t |
| 26 | 12 | 2.89e6 t |
| 41 | 11 | 1.74e6 t |
| 52 | 11 | 2.21e6 t |

The pipeline emits rules up to level 15, so every size has a margin.

The coverage is a circumradius, and the root is a hexagon. A square region
inside that circle is NOT fully tiled, because its corners are outside the
root. A Factorio map is 2e6 x 2e6, and its half-diagonal is 1.41e6. That is
why `REQUIRED_COVER` is above the half-diagonal and not the half-width. A
preview render with an untiled corner showed this problem. A test now checks
that the tiling covers every point in a box well inside the root.

`H_init` and related functions place hats at half scale. So a descent at
`unit` tiles per kite unit gives hats with a circumradius of
`0.5 * unit * 4.5826`. The pipeline emits the factor as `hat_scale` and
checks that every level-0 placement uses it. Callers give a hat size and use
`Ti.unit_for_hat_size()`. One manual conversion once made cells at half the
intended size.

A measurement on 2026-11-18 gave 0.41 to 0.60 ms per chunk for the descent,
with 9 to 25 hats per chunk. Size 52 is the fastest and size 15 the slowest.
The first measurement, at depth 12 and an older hat scale, gave 0.73 ms. That
was three times faster than the exact-integer version at depth 4, because a
composition is now six multiply-adds, not a ring multiplication plus a gcd
reduction.

### Identity

A hat's identity is its descent path: the child indices from the root to
the hat, packed with `string.char`. These are exact bytes, with no float
formatting. Each prefix is an ancestor, so `path:sub(1,k)` names the level-k
supertile. Any future region layer gets this for free.

The identity is explicitly *not* `string.format("%.3f", ...)`, because that
loses precision.

### Root placement

The root sits at the origin, with no offset. So spawn is on the centre of the
H metatile, which has 3-fold symmetry. An aperiodic tiling should not have a
visible centre, and the centre is the worst place to put the player.

An earlier version of this document said that the mod moves the root by a
fixed translation and stores the offset for each surface. The mod never did
this. `Ti.new` accepts a `root_xf`, but no caller passes one, so
`hat/tiling.lua` uses the identity.

The offset cannot come in a minor release. On an existing save, a new offset
would move every band on the new chunks, and a seam would appear at the edge
of the old terrain. So the mod must store the offset for each surface, with
zero for the existing surfaces. The change needs a MAJOR version. The plan is
to add it in 2.0.

## 6. Offline pipeline (`tools/`, Python, not shipped)

[hatviz](https://github.com/isohedral/hatviz) (BSD-3-Clause) does not store
the substitution rules as matrices. It holds a fixed combinatorial table with
29 entries in `constructPatch` and calculates transforms at runtime with
`matchTwo`. `constructMetatiles` then derives the metatile outlines for each
level from the geometry. So the outlines change from level to level, and
they converge on the limiting shapes with phi proportions. The level-0 hat
placements *are* explicit and exact, and they contain no phi.

- `hatviz_port.py` implements `matchTwo`, `constructPatch` and
  `constructMetatiles` again, in exact arithmetic over Q(sqrt3, sqrt5). It
  records the outlines and transforms for each level.
- `exactify.py` recovers the limiting metatiles with integer-relation
  recognition against a level-22 normalisation. The results agree
  independently at level 14 (1e-8) and level 22 (1e-14). All 36 coordinates
  are exact elements of `Q(phi)[sqrt3]`, with denominators that divide 100.
  If you substitute them, you get the same shapes scaled by phi^2 exactly, as
  ring elements. The self-similar rule set that results has a maximum
  coefficient of 219, against 4.8e26 for the rules for each level.
- `verify.py` and the pipeline tests check the generated tiling. The list of
  checks is in [`toolchain-decisions.md`](toolchain-decisions.md#offline-checks).
- `emit_lua.py` writes the committed Lua data files. They contain doubles,
  written with `%.17g` so that each value round-trips exactly.

The mod does not use the self-similar rules, because they cannot reach the
hats. A substitution maps the 4 hats on a decorated tile to 25 smaller hats.
So the decoration does not stay the same under scaling, and hats exist only
at level 0. An earlier draft planned a junction between the self-similar rules
and the rules for each level, with two-word integer arithmetic. The move to
doubles (section 5) made the junction unnecessary, so the mod uses the rules
for each level at every depth.

The attribution and the BSD-3-Clause notice ship with the mod.

## 7. Mod architecture

| Module | Responsibility | Factorio deps |
| --- | --- | --- |
| `hat/transform.lua` | affine transforms, six doubles | none |
| `hat/tiling.lua` | lazy descent, `hats_in_box()` | none |
| `hat/geometry.lua` | outline, edges, band distance | none |
| `hat/index.lua` | descent-path identity | none |
| `data/` | generated rules and hat geometry | none |
| `mod/config.lua` | settings -> geometry, measured cell stats | none |
| `mod/bands.lua` | area -> band tiles | none |
| `mod/planets.lua` | the set of surfaces that get bands | none |
| `mod/colours.lua` | the band colour options | none |
| `mod/surface.lua` | geometry per surface, stored once | settings, storage |
| `mod/terrain.lua` | paint bands, raise richness, warn | events, surfaces |
| `mod/outline.lua` | optional line overlay per player | rendering, storage |
| `mod/commands.lua` | `/hattorio-info` | commands |
| `mod/interface.lua` | the remote interface for other mods | remote |
| `prototypes/settings.lua` | the settings | settings stage |
| `prototypes/collision.lua` | the `hattorio_band` layer | data stage |
| `prototypes/tiles.lua` | the band tiles | data stage, settings |
| `prototypes/patch.lua` | band layer on buildable entities | data stage |

The modules with no Factorio dependencies run under plain Lua in CI. The risk
is in those modules, and the tests cover them. The collision layer blocks
construction (section 9), so no runtime module enforces it.

### Functional-core discipline

The layout meets SUPER (Radfar): side effects at the edge, uncoupled logic,
pure and total functions, explicit data flow, replaceable by value. The
determinism constraint led to this layout, and the principle came after. Three
rules make it explicit:

- **`mod/config.lua` is pure.** It takes the setting values as parameters
  and does not read `settings` or `storage`. `mod/surface.lua` does those
  reads, so every side effect is in a module that talks to Factorio.
- **Transform values are immutable.** Lua tables are mutable by reference,
  so this is a discipline and not a guarantee. Every operation returns a new
  table, and no operation changes an argument. A test checks this.
- **Totality.** The only division is by a squared length in
  `dist_to_segment`, and a test for zero guards it. So no operation is
  partial.

There is one deliberate exception. The descent changes its output
accumulator in place, for performance. `hat/tiling.lua` makes the
accumulator, fills it and returns it as the result. No caller sees it while
the descent changes it.

## 8. Terrain generation

`on_chunk_generated` -> compute -> `set_tiles`. There is no cost per tick.

- **Band test:** find each hat that overlaps the chunk (with the query box
  made larger by the band width). Rasterise each of its 13 edges as a thick
  line, into the bounding box of that edge only. The code rasterises an edge
  that two hats share twice, once for each hat. Before this change, the code tested
  every tile against every edge, which took 39.7 ms per chunk. Now it takes
  about 1.3 ms.
- **Do not fill water.** Paint only where the existing tile is land, so that
  lakes and their vanilla shore transitions stay.
- **Ore is already in place** when the event fires. Leave it. The mod raises
  resource richness during map generation to compensate for the cuts. At the
  default settings (41/3) a 3x3 drill can reach about 61% of a patch, so the
  compensation factor is about 1.6x. `Config.CELL_STATS` holds the measured
  fraction for every combination, and a map setting can override the factor.
- **The bands are continuous across chunk boundaries** by construction. Each
  chunk derives its bands from the tiling, never from the tiles of its
  neighbours.
- **Only the five vanilla planets get bands.** `mod/planets.lua` lists
  nauvis, vulcanus, fulgora, gleba and aquilo. Space platforms and planets
  from other mods keep vanilla terrain. Another mod can give a surface the
  cells of one of the five planets (see below).
- **Another mod can give a surface the cells of a planet.** A mod that
  makes more than one surface for a planet, such as one surface for each
  team, calls the remote interface when it creates the surface:
  `remote.call("hattorio", "set_surface_planet", surface.index, "nauvis")`.
  Chunks that exist already keep their ground, as on a real planet when a
  player adds the mod to a save.
- **The call returns true if the surface has the tiling of that planet.** It
  returns false for a space platform, an unknown planet or surface, and a
  surface that has another planet already. The planet of a surface does not
  change. A second call with the same planet returns true.
- **The first surface of a planet reads the startup settings.** A later
  surface of that planet takes the stored geometry of the real planet, or of
  another surface of the planet. So all its copies have the same cells. One
  gap stays. In Space Age, a copy of Vulcanus can exist before the real
  Vulcanus. If a startup setting changes before the game creates the real
  planet, the two get different cells.
- **The interface is a public contract.** `mod/interface.lua` also has
  `get_surface_planet`, which returns the planet of a surface or nil, and
  `interface_version`, which returns 1. A call keeps its name and its
  arguments. Each change that a caller can see raises the version.
- **The mod forgets a deleted surface.** The game can give the index of a
  deleted surface to a new one. So `on_surface_deleted` removes the planet
  and the geometry of that index.
- **A copied chunk keeps its ore.** A mod can fill a chunk with a copy of
  the same chunk of another tiled surface. The game reports each copy in
  `on_area_cloned`. The copy must have the same area, its tiles and its
  entities, and a source with the same planet, cell size and band width.
  The mod then records each chunk that the copy covers.
- **The order of the two mods does not matter.** If the chunk event
  of that tick comes after the copy, the mod leaves the chunk alone. If it
  comes first, the copy replaces the work of the mod. Either way, the ore
  richness goes up only once.

## 9. Build enforcement

**The game enforces it natively, through a custom collision layer.** This
reverses an earlier decision in this document, which specified rejection in
the script.

In Factorio 2.0, mods can declare collision layers
(`{type="collision-layer", name="hattorio_band"}`, with 256 available). Two
prototypes collide only if they share a layer. `data-final-fixes` adds the
layer to buildable structures, but not to the character, vehicles or rails.

The band tile has the band layer and no other layer. So the character and
vehicles cross it. The tile is not a fluid, so an offshore pump cannot use
it. It is not minable, and it cannot be part of a blueprint.

The game refuses the placement itself. The preview is red, blueprints skip
those tiles, bots never try to build there, and no ghosts remain. Rejection
in the script would place the entity and then remove it, which looks worse.
It would also need `on_built_entity`, `on_robot_built_entity`,
`script_raised_built`, `on_pre_build` and ghost cleanup to get close to what
one prototype field does for free.

Floor tiles need a second patch. An item such as stone brick, concrete or
landfill cannot place its tile on a tile that has a layer of its
`place_as_tile.condition`. The band tile has only the band layer, so no
condition matched it. Up to 1.0.1 you could pave a band and then build on
the new tile. Since 1.0.2, `data-final-fixes` adds the band layer to the
condition of every item that places a tile.

The cost is that `data-final-fixes` must list the entity types to patch. The
list is explicit and not a heuristic. So a modded entity that is not patched
fails open (it is buildable on bands) and does not break.

As a result, `storage` needs no band bitmap for each chunk. The collision
system does the lookup.

## 10. Visuals

- **Band tiles are the main visual.** The custom tiles are copies of
  `deepwater`, so they inherit its transition graphics. Two startup settings
  control the look: the style (animated liquid or flat void) and the colour
  (one of five near-black options). The colour is the same on every planet,
  so the mod looks like one thing and not like five.
- **Reflected hats get a stronger tint** on their own edges. A reflected hat
  paints all 13 of its edges in variant B. Where a reflected hat and an
  unreflected hat share an edge, the reflected hat wins. This is
  deterministic.
- **Optional crisp outline:** `draw_line` with `draw_on_ground = true`, with
  sub-tile precision. It goes down the centre of the band, so the two match.
  It is a setting for each player, and it is off by default.
- **The outline covers 64 tiles around the player.** The mod draws it again
  after the player moves 24 tiles. It draws all 13 edges of each hat, so a
  shared edge gets two lines. In a box of 128 x 128 tiles that is about 490
  lines at size 41 and about 2,100 at size 15.
- The mod does not use `draw_polygon`. It is a triangle strip, not a polygon,
  and it has no `draw_on_ground`, so fills would tint entities.

## 11. Settings

| Setting | Scope | Default | Range |
| --- | --- | --- | --- |
| `hattorio-hat-size-<planet>` | startup, planet | **41** | 15, 26, 41, 52 |
| `hattorio-band-width-<planet>` | startup, planet | **3** | 1, 2, 3, 4 |
| `hattorio-band-style` | startup | liquid | liquid, void |
| `hattorio-band-colour` | startup | violet | violet, cold, oily, ember, ink |
| `hattorio-richness-override` | runtime, map | 0 = automatic | 0 - 10 |
| `hattorio-show-outline` | runtime, player | off | on, off |

Size and band are dropdowns, not sliders. You cannot read the difficulty
of a size from the number, and the interesting range is four values, not
seventy-six. Each choice has a label for its difficulty: 15 very hard, 26
hard, 41 normal, 52 easy. The band widths have labels too: 1 thin, 2 narrow,
3 normal, 4 wide.

**41/3 became the default after playtests.** The first draft of this document
proposed 20/2. The code started at 26/2, then used 41/2 for a short time.
Both were too cramped in practice.

Size 41 with band 3 gives a cell of 858
tiles in which blueprints up to 17x17 stay reusable. That is enough room to
build, and every standard layout still breaks. Band 3 keeps the bands clearly
visible at that cell size, and band 2 does not.

Band style and band colour are independent. The style sets the shader on
the surface, and the colour sets its tint.

A third style with the lava shader from Vulcanus was built and removed
after playtests. It looked like a hazard, not a void, and it clashed with the
calm look of everything else. Its removal also took a Space Age conditional
out of the data stage.

Only size and band are per planet. Band style and colour apply to every
planet. The scope of each setting follows what it affects. Richness applies to the
whole map because all players share the ore. The outline is per player,
because it is only presentation and cannot change what anyone else sees.

The mod applies the richness override when a chunk generates. So a change
during a game affects only new chunks, and the ore richness changes at the
edge of the old terrain.

**Why startup and not runtime.** The geometry controls the terrain. If the
geometry changed in an existing save, every generated chunk would be out of
date, and you would see the seam. Startup settings cannot change after the
game loads.

**How the mod makes a change safe.** The mod stores the scale, band and depth
for each surface when it creates the surface (section 12). If a player
changes the setting later, the change affects only NEW surfaces. Existing
surfaces keep the geometry that their terrain was built with. So chunks that
already exist never go out of date, and no seam can appear. This is the idea
worth taking from the `continuous_geometry` flag in Hextorio.

## 12. Storage

Store only what the mod cannot calculate again: the geometry for each
surface (`storage.surfaces`) and the outline render objects for each player
(`storage.outlines`). The render objects are in `storage` because a module
local would be lost on load and the objects would leak. The mod needs no band
bitmap, because the collision system does the lookup (section 9). The mod
derives the tiling for each surface, and builds it again on load.

## 13. Testing

The tests run in three layers. `toolchain-decisions.md` gives the tools and
the reasons for them.

1. **Offline (Python).** The pipeline checks the generated tiling before any
   Lua exists ([offline checks](toolchain-decisions.md#offline-checks)).
2. **busted, pure Lua, no Factorio.** Transform composition, unique
   identities, band rasterisation, settings and the measured cell stats.
   There are also golden-file tests: the pipeline exports the exact set
   of hats for a known box, and `hat/tiling.lua` must produce the same hats.
   An invariant test checks that the modules in `hat/` never use
   `math.sin`, `math.cos`, `math.random` or `^`. Further tests check that the
   locale files are well formed, and that the docs quote the current
   defaults.
3. **In the game.** The in-game tests check that the painted tiles match the
   calculated bands, also on lab tiles. A visual check, build rejection
   (including ghosts and bots), UPS under load and a smoke test for desyncs
   with two clients are manual.

## 14. Corrections to earlier documents

- **hatviz does not store the substitution rules as matrices** (section 6).
- **The hat is a 13-gon, not a 14-gon.** The real outline in hatviz has 13
  vertices in the `hexPt` basis, `hexPt(x,y) = (x + y/2, (sqrt3/2)*y)`.
  `H_init` uses `hat_outline[5]`, `[7]`, `[9]` and `[11]`, so a wrong vertex
  list gives wrong hat placements without any error.
- **The first gameplay numbers used the wrong hat.** The 14-gon has an area
  of 22.08 and the 13-gon 13.86. So the cell sizes, the rectangles, the
  drillable fractions and the scale for equal area with Hextorio (52, not 41)
  were all wrong.
- **Band coverage is not perimeter x width / 2.** Rounded corners and
  rasterisation push it well above that (28.0% against 14.8% at size 41,
  band 2). Measure it by rasterisation.
- **The area of a metatile is not the area of its hats.** Hats cross
  metatile boundaries. Use overlap and gap detection.
- **The rules for each level go past 2^53 at level 7**, and raw products
  overflow from depth 5. This stopped exact-integer descent at depth 4
  (section 5).
- **Exact integer arithmetic was the wrong decision.** Determinism needs
  only correctly rounded IEEE operations, and doubles have them. The exact
  machinery cost a depth limit, a gcd reduction in the hot path and about
  200 lines of Lua.
- **Only the band is a custom tile.** "14 tile types and enormous transition
  tables" assumed a colour for every hat.
- **The target runtime is not a choice.** Factorio embeds Lua 5.2.1. Every
  number is a double, and LuaJIT NaN-boxing does not apply.
- **`tostring` uses `%.14g` and loses precision.** This is why a hat's
  identity is a descent path (`toolchain-decisions.md`).
- **Teal and Luau are both out.** Luau is the wrong runtime. Teal has no
  definitions for the Factorio API.
- **`factorio_version = "2.0"` does not load on Factorio 2.1.** Factorio 2.1
  refuses a mod that names another minor version, so 1.0.0 did not load on
  it. Release 1.0.1 targets 2.1, and `watch.yml` now tests each new release.
- **`draw_polygon` is a triangle strip** and has no `draw_on_ground`.
- **A line overlay does not avoid the rasterisation problem.** Bands are
  terrain, so the stair steps come back. They fall inside the band.
- **The `hex_lattice.lua` method from Hextorio does not transfer.** It needs
  a periodic grid, and phi is irrational.
- **The root offset was never built** (section 5).

## 15. Out of scope

Claims on cells, cores, trades, ore gating by cell, impassable band variants,
band removal and any territory layer. The design of `hat/tiling.lua` and the
descent-path hierarchy lets a later version add these features
without changes to the core.

Cells of different areas, for example Voronoi cells from noise, are also out
of scope. They need a second tiling next to the hat (section 17).

## 16. Risks and limits

- **Width 4 and the basic underground belt.** Some crossings at width 4 need
  the fast underground belt (section 4).
- **A seam when the mod joins an existing save.** The mod paints only new
  chunks. Chunks that exist before you add the mod keep vanilla terrain,
  and the mod prints a warning.
- **The richness override changes only new chunks** (section 11).
- **Modded entity types fail open.** A type that is not in the patch list is
  buildable on bands (section 9).
- **Planets from other mods get no bands** (section 8).
- **Spawn is on the centre of the H metatile** (section 5).

## 17. Alternatives

- **A cosmetic grid** (section 1): no pressure on the player.
- **Exact integer arithmetic** (sections 5 and 14): a depth limit and no gain
  in determinism.
- **Self-similar rules with a junction** (section 6): they cannot reach the
  hats, and doubles made the junction unnecessary.
- **Rejection in the script** (section 9): it places and then removes the
  entity, and it needs four event handlers and ghost cleanup.
- **A grace area at spawn** (section 4): it weakens the premise at the start.
- **No trains** (section 4): it takes away too much.
- **A cheaper irregular tiling.** It could also break blueprints. The mod
  uses the hat because the hat is its theme.
