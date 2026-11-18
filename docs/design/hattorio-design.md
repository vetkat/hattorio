# Hattorio design

Status: describes version 1.0.0
Date: 2026-11-10 (first draft 2026-09-19)

Hattorio is a Factorio mod. It divides the buildable area of each planet into
cells of the aperiodic "hat" monotile tiling, with unbuildable bands between
the cells.

The mod does NOT replace Factorio's square grid. That grid is part of the
engine, and Lua cannot reach it (see section 2). The mod changes where you may
build, and that is enough.

## 1. Goal

Make imported Cartesian blueprints useless, and make players build organic
factories that do not repeat.

The tiling is a means to that goal. Every decision below answers one
question: does it serve the goal?

### Non-goals

- A cosmetic change to the grid. Rejected: a buildable band puts no
  mechanical pressure on the player, and blueprints keep working.
- Parity with Hextorio. Its claiming, cores, trades and economy make a
  different game.
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
mall is about 30x30. These are the worst cases across all 12 orientations,
measured against the correct 13-gon hat:

| hat size | band | cell area | worst rectangle | drillable |
| --- | --- | --- | --- | --- |
| 20 | 1 | 221 t | 9x9 | 51.1% |
| 20 | 2 | 188 t | 5x15 | 39.8% |
| 26 | 2 | 346 t | 7x19 | 52.2% |
| 41 | 2 | 939 t | 19x19 | 68.2% |
| 41 | 3 | 858 t | 19x18 | 61.0% |
| 52 | 2 | 1,581 t | 14x42 | 74.9% |
| 64 | 3 | 2,315 t | 29x30 | 74.6% |

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

These values come from `Config.CELL_STATS`. That table holds a measurement for
every combination that the dropdowns offer, and a test checks that none is
missing.

A smelter block is about 20x20 and a mall is about 30x30. So every size up to
41 breaks real imported blueprints and still leaves room to build.

The average case is not easier than the worst case. The spread across
orientations is about 5% (221/228/233 tiles at 20/1). The reason is that
every cell is the same shape rotated, and only the rasterisation changes.

## 4. Gameplay rules

- **Bands are unbuildable, but you can walk and drive on them.** Only
  buildable structures get the band collision layer (section 9), so nothing
  keeps the player or vehicles inside a cell.
- **Undergrounds go under bands.** Underground belts and pipes-to-ground
  reach 4 to 10 tiles, so they can cross any band up to 3 wide. This is the
  intended connection between cells and the main source of spaghetti. Every
  crossing costs an underground pair, placed against an edge that is not
  parallel to an axis.
- **Rails are exempt** and can cross bands. The design considered removing
  trains completely, and rejected it because it takes away too much.
- **Mining drills are not exempt.** The mod raises resource richness to
  compensate (see section 8).
- **Tiles do not affect power poles, wires and bots.** Bots are the natural
  relief in the late game, and they arrive with normal progression.
- **Bands are permanent.** No technology, item or claim removes them. Bands
  are the identity of the mod, and players must not be able to optimise them
  away.

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

Measured against exact values from the offline pipeline:

```text
depth   coverage       relative error   absolute error
   8      26,660 t       5.7e-16          8e-12 tiles
  10     183,419 t       4.3e-16          7e-11 tiles
  12   1,194,588 t       5.3e-16          4e-10 tiles
```

The relative error stays at machine epsilon and does not grow with depth,
because the composition is well conditioned. Depth 12 covers the whole map
with an error of four ten-billionths of a tile.

Exact integers could not go past depth 4. The numerators of the level-6
rules are 1.4e14, so one composition makes a raw product near 1e28, far past
2^53. A reduction after the product comes too late. A cross-reduction before
it does not help either. The measured gcd of the operands is 1, because the
cancellation is additive (inside the sums) and not multiplicative.

So a transform is six plain doubles, and `hat/exact.lua` does not exist. The
exact arithmetic stays where it belongs: offline, in `tools/`, where it
derives the rules and proves them correct. Only the values ship.

Shipped Lua must never contain `math.sin`, `math.cos`, `math.random` or `^`.
An invariant test searches for them.

### Depth and coverage

The descent uses depth 12. At the default scale it covers about 1,112,791 tiles,
which is the whole Factorio map (its half-extent is about 1e6 tiles).
Coverage grows linearly with the hat size setting.

The mod derives the depth for each surface from the size setting and stores
it when it creates the surface. So a smaller hat size uses a deeper root and
does not lose coverage.

The descent at depth 12 takes 0.73 ms per chunk (about 39 hats
per chunk). That is three times faster than the exact-integer version was at
depth 4. The reason is that a composition is now six multiply-adds, not a
ring multiplication plus a gcd reduction.

### Identity

A hat's identity is its descent path: the child indices from the root to
the hat, packed with `string.char`. These are exact bytes, with no float
formatting. Each prefix is an ancestor, so `path:sub(1,k)` names the level-k
supertile. Any future region layer gets this for free.

The identity is explicitly *not* `string.format("%.3f", ...)`, because that
loses precision.

### Root placement

The mod moves the root by a fixed, exact ring translation, so that spawn does
not land on the centre of the H metatile, which has 3-fold symmetry. An
aperiodic tiling must not have a visible centre, and the centre is the worst
place to put the player.

## 6. Offline pipeline (`tools/`, Python, not shipped)

hatviz (BSD-3-Clause, isohedral/hatviz) does not store the substitution
rules as matrices. It holds a fixed combinatorial table with 29 entries in
`constructPatch` and calculates transforms at runtime with `matchTwo`.
`constructMetatiles` then derives the metatile outlines for each level from
the geometry. So the outlines change from level to level, and they converge
on the limiting shapes with phi proportions. The level-0 hat placements *are*
explicit and exact, and they contain no phi.

- `hatviz_port.py` implements `matchTwo`, `constructPatch` and
  `constructMetatiles` again, in exact arithmetic over Q(sqrt3, sqrt5). It
  records the outlines and transforms for each level.
- `exactify.py` is complete. It recovers the limiting
  metatiles with integer-relation recognition against a level-22
  normalisation. The results agree independently at level 14 (1e-8) and level
  22 (1e-14). All 36 coordinates are exact elements of `Q(phi)[sqrt3]`, with
  denominators that divide 100. If you substitute them, you get the same
  shapes scaled by phi^2 exactly, as ring elements. This is a true fixed
  point, not an approximation.

  The self-similar rule set that results has a maximum coefficient of
  **219**. The rules for each level have 4.8e26. Composition stays small
  (2,149 at depth 25, twelve orders of magnitude inside 2^53). So the rule set
  removes the depth cap, and does not only raise it.

  **That open question is now settled, and the answer is no.** A self-similar
  rule set cannot reach the hats exactly. The evidence:

  - The first try attached the hats from `level0()` to a self-similar descent.
    The counts are right (F(2n+3)^2) and the hats are congruent, but the gate
    reports overlaps and 0.9% gaps.
  - The second try anchored the hats again against the limit outlines, by
    combinatorics that do not depend on the frame (which hat vertices are on
    which outline vertices). This made it worse: the hats came out at four
    different scales. A chord of a rigid hat cannot match a deformed outline
    edge and stay congruent. H, P and F all deform in different ways (the edge
    ratio of H goes from 4:1 to phi^4-1, and the interior angles of F change
    completely).
  - The reason is structural. A substitution maps the 4 hats on a decorated
    tile to 25 smaller hats, so the decoration does not stay the same under
    scaling. Hats exist only at level 0, where they attach to the ORIGINAL
    shapes. The limit shapes are the attractor of the METATILE substitution
    alone.

  The limit shapes are still useful, because the rules for each level
  converge to them precisely. The linear parts are exactly the same at
  every level, and the sequences of child shapes match exactly. Only the
  translations are different. They differ by a factor that converges to
  exactly phi^(2L), with a relative spread of about phi^(-2L) (4.9e-5 at
  level 6, 4.8e-10 at level 12).

  **Correction, found during the implementation of the Lua descent.** An
  earlier draft of this section offered "cap at depth 6, ~14,000 tiles" as an
  option to ship. That is wrong for two reasons.

  First, depth 6 covers 3,498 tiles at the default scale, not 14,000. The
  earlier figure used an estimated metatile radius, not the emitted one.

  Second, and more important, Lua doubles cannot compose the rules for each
  level at depth 6 at all. The numerators at level 6 reach 1.4e14, so one
  composition makes a raw product near 1e28. The reduced result is only about
  1e9. But a reduction after the product comes too late. A cross-reduction
  before it does not help either. The measured gcd of the operands is 1,
  because the cancellation is additive and not multiplicative.

  The measured peaks of the raw product are:

  ```text
  depth 4   3.9e13   OK
  depth 5   5.7e16   overflow
  depth 6   2.3e20   overflow
  ```

  So the rules for each level stop at depth 4 = 546 tiles, and that is
  not enough to ship. `Ti.safe_depth()` encodes this limit. A test checks that
  the overflow still occurs, so the limit cannot move without notice.

  The self-similar rules compose very well (maximum coefficient 219, and only
  2,149 at depth 25), but they cannot reach the hats. So any design that can
  ship uses self-similar rules above a junction level and the rules for
  each level below it. The only question is where the junction goes:

  | junction | block radius | rel. error | seam | occurs every |
  | --- | --- | --- | --- | --- |
  | level 2 | 116 t | 1.2e-1 | 14.0 t | 116 t |
  | level 4 | 546 t | 2.3e-3 | 1.27 t | 546 t |
  | level 6 | 3,498 t | 4.9e-5 | 0.17 t | 3,498 t |

  Junction 4 needs no new machinery, but it leaves a seam of about 1.3 tiles
  every 546 tiles, and you can see that seam. Junction 6 leaves a seam of
  0.17 tiles every 3,498 tiles. That is less than one tile, so it disappears
  after rasterisation. But it needs two-word (106-bit) integer arithmetic
  in the ring to compose levels 5 and 6. The raw peak at depth 6 is 2.3e20,
  which is far inside 2^106 = 8.1e31.

  Seams of both sizes are fully deterministic. Each is a fixed deviation that
  is the same on every client, not float drift. So neither one is a risk for
  multiplayer.

  **Recommendation: two-word arithmetic with the junction at level 6.** This
  gives an unbounded map and sub-tile error, and only `hat/exact.lua` uses
  the wider integers.

  **Superseded.** Section 5 replaced this recommendation. The transforms are
  now plain doubles, so the mod needs no junction and no two-word integers,
  and `hat/exact.lua` does not exist.
- `verify.py` makes five checks:
  - no two hats overlap
  - a flood fill finds no gaps
  - the reflected density converges
  - the output matches the SVG output of hatviz
  - no coefficient goes past 2^53
- `emit_lua.py` writes the committed Lua data files. They contain doubles,
  written with `%.17g` so that each value round-trips exactly.

The attribution and the BSD-3-Clause notice ship with the mod.

## 7. Mod architecture

| Module | Responsibility | Factorio deps |
| --- | --- | --- |
| `hat/transform.lua` | affine transforms, six doubles | none |
| `hat/tiling.lua` | lazy descent, `hats_in_box()` | none |
| `hat/geometry.lua` | outline, edges, band distance | none |
| `hat/index.lua` | descent-path identity | none |
| `mod/config.lua` | settings -> geometry, measured cell stats | none |
| `mod/bands.lua` | area -> band tiles | none |
| `mod/surface.lua` | geometry per surface, stored once | settings, storage |
| `mod/terrain.lua` | paint bands, raise richness, warn | events, surfaces |
| `mod/outline.lua` | optional line overlay per player | rendering, storage |
| `mod/commands.lua` | `/hattorio-info` | commands |
| `prototypes/patch.lua` | band layer on buildable entities | data stage |

The first six modules have no Factorio dependencies, and they run under
plain Lua in CI. The risk is in those modules, and the tests cover them.
The collision layer blocks construction (section 9), so no runtime module
enforces it.

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
accumulator in place, for performance. The accumulator is local to
`hat/tiling.lua` and never leaves it.

## 8. Terrain generation

`on_chunk_generated` -> compute -> `set_tiles`. There is no cost per tick.

- **Band test:** find each hat that overlaps the chunk (with the query box
  made larger by the band width). Rasterise each of its 13 edges as a thick
  line. An exact endpoint key removes the copies of a shared edge, so the code
  walks each edge only once. This is about ten times cheaper than a
  point-in-polygon test for each tile, and it calculates the quantity that the
  mod needs.
- **Do not fill water.** Paint only where the existing tile is land, so that
  lakes and their vanilla shore transitions stay.
- **Ore is already in place** when the event fires. Leave it. The mod raises
  resource richness during map generation to compensate for the cuts. At the
  default settings (41/3) a 3x3 drill can reach about 61% of a patch, so the
  compensation factor is about 1.6x. `Config.CELL_STATS` holds the measured
  fraction for every combination.
- **The bands are continuous across chunk boundaries** by construction. Each
  chunk derives its bands from the tiling, never from the tiles of its
  neighbours.
- **Skip space platforms.** Only planets get bands.

## 9. Build enforcement

**The game enforces it natively, through a custom collision layer.** This
reverses an earlier decision in this document, which specified rejection in
the script.

In Factorio 2.0, mods can declare collision layers
(`{type="collision-layer", name="hattorio_band"}`, with 256 available). Two
prototypes collide only if they share a layer. The band tiles have that layer.
`data-final-fixes` adds it to buildable structures, but not to the character,
vehicles or rails.

The game then refuses the placement itself. The preview is red, blueprints
skip those tiles, bots never try to build there, and no ghosts remain.
Rejection in the script would place the entity and then remove it, which
looks worse. It would also need `on_built_entity`, `on_robot_built_entity`,
`script_raised_built`, `on_pre_build` and ghost cleanup to get close to what
one prototype field does for free.

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
- **Reflected hats get a slightly different tint** on their own edges. A
  reflected hat paints all 13 of its edges in variant B. Where a reflected hat
  and an unreflected hat share an edge, the reflected hat wins. This is
  deterministic.
- **Optional crisp outline:** `draw_line` with `draw_on_ground = true`, with
  sub-tile precision. It goes down the centre of the band, so the two match.
  It is a setting for each player, and it is off by default. The mod draws it
  only within 64 tiles of the player and draws it again after the player
  moves 24 tiles. Without the copies of shared edges, a full screen would
  hold about 7k objects at size 20 and about 19k at size 12.
- The mod does not use `draw_polygon`. It is a triangle strip, not a polygon,
  and it has no `draw_on_ground`, so fills would tint entities.

## 11. Settings

Per planet, startup:

| Setting | Default | Range |
| --- | --- | --- |
| `hattorio-hat-size-<planet>` | **41** (normal) | 15, 26, 41, 52 |
| `hattorio-band-width-<planet>` | **3** (normal) | 1, 2, 3, 4 |
| `hattorio-band-style` | liquid | liquid, void |
| `hattorio-band-colour` | violet | violet, cold, oily, ember, ink |
| `hattorio-richness-override` (map) | 0 = automatic | 0 - 10 |
| `hattorio-show-outline` (per player) | off | on, off |

Size and band are dropdowns, not sliders. You cannot read the difficulty
of a size from the number, and the interesting range is four values, not
seventy-six. Each choice has a label for its difficulty: 15 very hard, 26
hard, 41 normal, 52 easy. The band widths have labels too: 1 thin, 2 narrow,
3 normal, 4 wide.

**41/3 became the default after playtests.** The earlier default of 26/2
was too cramped in practice. Size 41 with band 3 gives a cell of 858 tiles in
which blueprints up to 17x17 stay reusable. That is enough room to build, and
every standard layout still breaks. Band 3 keeps the bands clearly visible at
that cell size, and band 2 does not.

Band style and band colour are independent. The style sets the shader on
the surface, and the colour sets its tint.

A third style with the lava shader from Vulcanus was built and removed
after playtests. It looked like a hazard, not a void, and it clashed with the
calm look of everything else. Its removal also took a Space Age conditional
out of the data stage.

Only size and band are per planet. Band style and colour are global. The
scope of the other two settings follows what they affect. Richness applies to
the whole map because all players share the ore. The outline is per player,
because it is only presentation and cannot change what anyone else sees.

**Why startup and not runtime.** The geometry controls the terrain. If the
geometry changed in an existing save, every generated chunk would be out of
date, and you would see the seam. Startup settings cannot change after the
game loads.

**How the mod makes a change safe.** The mod stores the scale, band, depth and
root offset for each surface when it creates the surface (section 12). If a
player changes the setting later, the change affects only NEW surfaces.
Existing surfaces keep the geometry that their terrain was built with. This
removes the out-of-date chunk problem by construction, without regeneration.
It is the idea worth taking from the `continuous_geometry` flag in Hextorio.

**The mod derives the depth. Nobody sets it.** Coverage grows linearly with
the hat size, so a smaller hat needs a deeper root.
`Ti.depth_covering(unit, cover)` picks the shallowest depth that reaches the
edge of the map. The mod calculates it once when it creates the surface and
stores it. The pipeline emits rules up to level 15, which leaves a margin
across the whole range of settings.

**`coverage()` is a circumradius, and the root is a hexagon.** A square region
inside that circle is NOT fully tiled, because its corners are outside the
root. A 2e6 x 2e6 map has a half-diagonal of 1.41e6, so ask for a generous
`cover`, never the half-width. A preview render with an untiled corner showed
this problem. A test now checks that the tiling covers every point in a box
well inside the root.

**Hats have a scale factor of 0.5.** `H_init` and related functions place
hats at half scale. So a descent at `unit` tiles per kite unit gives hats with
a circumradius of `0.5 * unit * 4.5826`. The pipeline emits the factor as
`hat_scale` and checks that every level-0 placement uses it. So a placement
that broke congruence would fail the build.

Callers must give a hat size and use `Ti.unit_for_hat_size()`. One manual
conversion already made cells at half the intended size.

The mod stores the scale, depth and root offset for each surface when it
creates the surface. A later change to a startup setting affects only new
surfaces. So chunks that already exist never go out of date, and no seam can
appear. This is the one idea worth taking from the `continuous_geometry` flag
in Hextorio.

## 12. Storage

Store only what the mod cannot calculate again: the geometry for each
surface (`storage.surfaces`) and the outline render objects for each player
(`storage.outlines`). The render objects are in `storage` because a module
local would be lost on load and the objects would leak. The mod needs no band
bitmap, because the collision system does the lookup (section 9). The mod
derives the tiling for each surface, and builds it again on load.

## 13. Testing

The tests use red-green-refactor with busted and luassert, and luacheck for
static analysis. The tests run under Lua 5.2 specifically. Lua 5.3 and later
add an integer subtype, which would hide the all-doubles behaviour that the
core depends on. Property-style tests are plain loops over fixed seeds, not a
generative library. The project uses no static type checker. See
`toolchain-decisions.md`.

1. **Offline (Python).** Overlap, gaps, density, SVG comparison and the
   coefficient limit. These tests find a sign error before any Lua exists.
2. **busted, pure Lua, no Factorio.** Transform composition, unique
   identities, band rasterisation, settings and the measured cell stats.
   There are also golden-file tests: the pipeline exports the exact set
   of hats for a known box, and `hat/tiling.lua` must produce the same hats.
   Further tests check that shipped Lua never uses `math.sin`, `math.cos`,
   `math.random` or `^`, that the locale files are well formed, and that the
   docs quote the current defaults.
3. **In the game.** A visual check, continuous bands across chunk boundaries,
   build rejection (including ghosts and bots), UPS under load, and a smoke
   test for desyncs with two clients.

## 14. Corrections to earlier documents

This section records them so that nobody has to work them out again.

- **hatviz does not store the substitution rules as matrices.** The earlier
  chat transcript says that it does. It does not (see section 6).
- **The hat is a 13-gon, not a 14-gon.** An earlier claim said that the
  14-vertex `HAT_OUTLINE` in the scaffold "matches Kaplan's exactly". That
  was wrong. The real outline in hatviz has 13 vertices in the `hexPt` basis,
  `hexPt(x,y) = (x + y/2, (sqrt3/2)*y)`. `H_init` uses `hat_outline[5]`, `[7]`,
  `[9]` and `[11]`, so a wrong vertex list gives wrong hat placements without
  any error.
- **The first version of every gameplay number in this document used the
  wrong hat.** The 14-gon in the first scaffold has an area of 22.08, and the
  real 13-gon has 13.86. That is 1.59x too large. It made the cell-size table,
  the largest-rectangle figures, the ore drillability numbers and the scale
  for equal area with Hextorio (52, not 41) wrong. The sections above give
  the recalculated values. A render of the tiling found the error: the
  measured band coverage was twice the predicted value.
- **Band coverage is not perimeter x width / 2.** Rounded corners and
  rasterisation at tile centres push it well above that estimate. The measured
  value is 28.0% at size 41 / band 2, against a prediction of 14.8%. Always
  measure it by rasterisation, never with a formula.
- **The area of a metatile is not the area of its hats.** Hats cross metatile
  boundaries, so an area check does not prove that H, T or F is valid. Use
  overlap and gap detection.
- **The coefficients of the rules for each level go past 2^53 at level 7**,
  and raw products overflow from depth 5. This stops exact-integer descent at
  depth 4, and it is why the core moved to doubles (see section 5).
- **Exact integer arithmetic was the wrong decision.** The
  brainstorm said it was necessary for determinism in multiplayer. It is not.
  Determinism needs only correctly rounded IEEE operations, and doubles have
  them. The exact machinery cost a depth limit, a gcd reduction in the hot
  path and about 200 lines of Lua. It gave nothing that the cheaper option
  did not.
- **"14 tile types and enormous transition tables"** assumed a colour for
  every hat. Only the band is a custom tile, on vanilla terrain.
- **The target runtime is not a choice.** Factorio embeds Lua 5.2.1. There
  is no integer subtype, every number is a double, and the limit is 2^53.
  LuaJIT NaN-boxing does not apply. The first toolchain notes listed this as
  an open question.
- **Most of the floating-point section in those notes did not matter**, and
  the move of the core to doubles replaced the rest. What remains is in
  `toolchain-decisions.md`: the 2^53 limit, and the fact that `tostring` uses
  `%.14g` and loses precision. That is why a hat's identity is a descent
  path.
- **Teal and Luau are both out.** Luau is the wrong runtime. Teal has no
  definitions for the Factorio API, so every API call would be an untyped
  escape hatch anyway.
- **`factorio_version = "2.0"` does not load on Factorio 2.1.** At the time of
  the first draft of this document, 2.1 was experimental and 2.0.77 was
  stable. The document said that "2.0" loads on both. That was wrong. Factorio
  2.1 refuses a mod that names another minor version, so 1.0.0 did not load on
  2.1. Release 1.0.1 targets 2.1.

  Now `.factorio-version` pins the release that the tests use, and
  `watch.yml` tests each new release (`toolchain-decisions.md`).
- **`draw_polygon` is a triangle strip** and has no `draw_on_ground`.
- **The rasterisation problem is real here.** For a short time a line overlay
  looked like a way to avoid it. But bands are terrain, so the stair steps come
  back. They fall inside the band. This is why the ragged hexagons in
  Hextorio look deliberate.
- **The `hex_lattice.lua` method from Hextorio does not transfer.** To snap a
  grid to integers, the grid must be periodic. phi is irrational, and nothing
  changes that.

## 15. Out of scope

Claims on cells, cores, trades, ore gating by cell, impassable band variants,
band removal and any territory layer. The design of `hat/tiling.lua` and the
descent-path hierarchy lets a later version add these features
without changes to the core.

## 16. Open items for review

1. **Starting area: decided, no grace area.** At the default 41/3, the spawn
   cell holds about 858 buildable tiles. That is enough for a burner start.
   Bands are walkable, so everything is reachable before underground belts
   arrive. A grace area would weaken the premise exactly where a new player
   forms an impression. The cell size setting is the escape hatch.
2. **Default cell size: decided, 41/3.** Playtests chose it (section 11).
   The earlier defaults, 20/2 and then 26/2, were too cramped.
3. **Resource compensation: decided, measured per combination.** The factor
   comes from the drill reach in `Config.CELL_STATS` for each size and band.
   It is about 1.6x at the default settings, and a map setting can override
   it.
