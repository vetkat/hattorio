# Hattorio — design

Status: draft for review
Date: 2026-09-19

A Factorio mod that replaces the buildable plane with the cells of an
aperiodic "hat" monotile tiling, separated by unbuildable bands.

## 1. Goal

Make imported cartesian blueprints useless, and force players to build
organic, non-repeating factories.

The tiling is the means, not the end. Every decision below is judged on
whether it serves that goal.

### Non-goals

- A cosmetic grid overhaul. Rejected: a buildable band exerts no
  mechanical force and blueprints keep working.
- Hextorio parity. Its claiming, cores, trades and economy are a
  different game.
- Territory, claiming, or ownership mechanics. Deferred entirely.

## 2. What the engine forbids

These are settled and must not be relitigated during implementation.

- **Tiles are 1x1 and axis-aligned.** Tile storage, collision boxes,
  belt transport lines, pipe and inserter connections, the pathfinder
  and blueprints are C++ and assume a square grid. No mod makes the
  unit of construction hat-shaped.
- **Entities are axis-aligned integer boxes** in 4 (or 8) directions.
  Nothing rotates to 30 degrees.
- **Blueprints rotate in 90 degree steps.** This is what makes the
  mechanism work, see section 3.

The mod therefore shapes *where* you may build, never *what shape*
things are.

## 3. Mechanism: why blueprints break

Two effects compound.

**Cells are too small.** A standard city block is 100x100 and even a
modest mall is ~30x30. Worst case across all 12 orientations, measured
against the correct 13-gon hat:

| hat size | band | cell area | worst rectangle | drillable |
|---|---|---|---|---|
| 20 | 1 | 221 t | 9x9 | 51.1% |
| 20 | 2 | 188 t | 5x15 | 39.8% |
| 26 | 2 | 346 t | 7x19 | 52.2% |
| 41 | 2 | 939 t | 19x19 | 68.2% |
| 41 | 3 | 858 t | 19x18 | 61.0% |
| 52 | 2 | 1,581 t | 14x42 | 74.9% |
| 64 | 3 | 2,315 t | 29x30 | 74.6% |

**Every cell is a different shape.** This, not orientation, is what
actually breaks blueprints.

Hats occur in 12 classes: 6 rotations at multiples of 60 degrees, times
2 chiralities, all near-uniform in frequency (~14.5% per unreflected
class, ~2.1% per reflected). Factorio rotates blueprints in 90 degree
steps, so 0/180, 60/240 and 120/300 each collapse to one class, and
2.0 can flip, which maps reflected onto unreflected. **Orientation
alone would therefore need only about 3 layouts** -- an earlier draft
of this document claimed 12, which overstated the case.

What does the work is sub-tile placement. Hat positions are irrational
multiples of the tile pitch, so every cell sits at a different offset
and rasterises differently. Measured over 1,156 hats:

| | size 20 / band 2 | size 41 / band 2 |
|---|---|---|
| orientation classes | 12 | 12 |
| **distinct buildable tile-masks** | **624** | **918** |
| most common single mask | 1.1% of cells | 0.5% of cells |

No single cell shape covers more than about 1% of the map. A layout
that fills a cell must be fitted to that cell.

**What still survives**, and it is the honest limit of the mechanism: a
blueprint with margin transfers fine. Anything up to the worst-case
inscribed square fits every cell:

| size / band | universally reusable | cell area |
|---|---|---|
| 20 / 2 | up to 8x8 | 189 t |
| 26 / 2 | up to 11x11 | 347 t |
| 41 / 2 | up to 18x18 | 944 t |
| 52 / 2 | up to 23x23 | 1,584 t |

A smelter block is ~20x20 and a mall ~30x30, so every size up to 41
defeats real imported blueprints while leaving room to build.

Average case is not more forgiving than worst case: the spread across
orientations is ~5% (221/228/233 tiles at 20/1), because it is one
shape rotated and only the rasterisation differs.

## 4. Gameplay rules

- **Bands are unbuildable, but walkable and drivable.** Enforcement is
  script-side, so no collision mask confines the player to a cell.
- **Undergrounds tunnel.** Underground belts and pipes-to-ground reach
  4-10 tiles, so any band up to 3 is spannable. This is the intended
  inter-cell connection and the main source of spaghetti: every
  crossing costs an underground pair placed against a non-axis-aligned
  edge.
- **Rails are exempt** and may cross bands. Removing trains entirely
  was considered and rejected as too large a subtraction.
- **Mining drills are not exempt.** Instead, resource richness is
  raised to compensate, see section 8.
- **Power poles, wires and bots** are unaffected by tiles. Bots are the
  natural late-game relief valve and arrive with normal progression.
- **Bands are permanent.** No tech, item or claim removes them. This is
  the mod's identity and it must not be optimisable away.

## 5. Geometry and arithmetic

### Doubles, not exact integers

**This reverses an earlier decision in this document.** The original
design carried every coordinate as four exact integers in
`Z[phi][sqrt3]`. That came from conflating two different things, and
implementation proved it both unnecessary and unworkable.

The desync risk in Factorio is `math.sin`, `math.cos` and `^`/`pow`,
whose libm implementations genuinely differ between platforms. But
IEEE-754 requires `+ - * /` and `sqrt` to be **correctly rounded**, so
they are bit-identical everywhere. Lua's interpreter executes each as
its own VM instruction, so no compiler FMA contraction can fuse them,
and Factorio 2.0 is x86-64 only, so there is no x87 80-bit excess
precision either. **Doubles are exactly as deterministic as integers
here.** They are only less accurate.

Measured against exact ground truth from the offline pipeline:

```
depth   coverage       relative error   absolute error
   8      26,660 t       5.7e-16          8e-12 tiles
  10     183,419 t       4.3e-16          7e-11 tiles
  12   1,194,588 t       5.3e-16          4e-10 tiles
```

Relative error sits at machine epsilon and **does not grow with
depth** — the composition is well conditioned. Depth 12 covers the
whole map with an error of four ten-billionths of a tile.

Exact integers, by contrast, could not reach past **depth 4**:
level-6 rule numerators are 1.4e14, so a single composition produces a
raw product near 1e28, far past 2^53. Reducing afterwards is too late,
and cross-reducing beforehand does not help — measured operand gcd is
1, because the cancellation is additive, inside the sums, rather than
multiplicative.

So a transform is six plain doubles and `hat/exact.lua` does not exist.
The exact arithmetic stays where it belongs: **offline**, in
`tools/`, deriving the rules and proving them correct. Only the values
ship.

What must never appear in shipped Lua: `math.sin`, `math.cos`,
`math.random`, `^`. An invariant test greps for them.

### Depth and coverage

**Depth 12**, which covers ~1,112,791 tiles at the default scale —
the entire Factorio map, whose half-extent is ~1e6 tiles. Coverage
scales linearly with the hat-size setting.

Depth is derived per surface from the size setting and stored at
surface creation, so a smaller hat size simply uses a deeper root
rather than losing coverage.

Descent cost at depth 12 is **0.73 ms per chunk** (~39 hats/chunk),
measured — three times faster than the exact-integer version managed at
depth 4, because a composition is now six multiply-adds rather than a
ring multiply plus a gcd reduction.

### Identity

The **descent path** — child indices from root to hat, packed with
`string.char`. Exact bytes, no float formatting. Prefixes are
ancestors, so `path:sub(1,k)` names the level-k supertile, which any
future region layer gets for free.

Explicitly *not* `string.format("%.3f", ...)`, which is lossy.

### Root placement

The root is offset by a fixed exact ring translation so spawn does not
land on the H metatile's 3-fold symmetric centre. An aperiodic tiling
should have no visible centre, and that is the worst place to put the
player.

## 6. Offline pipeline (`tools/`, Python, not shipped)

hatviz (BSD-3-Clause, isohedral/hatviz) does **not** store substitution
rules as matrices. It holds a fixed 29-entry combinatorial table in
`constructPatch`, computes transforms at runtime via `matchTwo`, and
derives each level's metatile outlines geometrically in
`constructMetatiles` — so the outlines change level to level,
converging on the limiting phi-proportioned shapes. Level-0 hat
placements *are* explicit and exact, and contain no phi.

- `hatviz_port.py` — reimplements `matchTwo`, `constructPatch`,
  `constructMetatiles` in exact arithmetic over Q(sqrt3, sqrt5).
  Captures per-level outlines and transforms.
- `exactify.py` — **DONE and verified.** The limiting metatiles were
  recovered by integer-relation recognition against a level-22
  normalisation, agreeing independently at level 14 (1e-8) and level 22
  (1e-14). All 36 coordinates are exact elements of Q(phi)[sqrt3] with
  denominators dividing 100. Substituting them reproduces them scaled
  by phi^2 **exactly, as ring elements** — a true fixed point, not an
  approximation. The resulting self-similar rule set has max
  coefficient **219**, against 4.8e26 for the per-level rules, and
  composition stays tiny (2,149 at depth 25, twelve orders inside
  2^53). The depth cap is removed, not merely raised.

  **That open question is now settled, and the answer is negative.**
  A self-similar rule set cannot reach the hats exactly. Evidence:

  - Attaching `level0()`'s hats to a self-similar descent gives the
    right counts (F(2n+3)^2) and congruent hats, but the gate reports
    overlaps and 0.9% gaps.
  - Re-anchoring the hats against the limit outlines by their
    frame-independent combinatorics (which hat vertices coincide with
    which outline vertices) makes it worse: four distinct hat scales.
    A rigid hat's chord cannot match a deformed outline edge and stay
    congruent, and H, P and F all deform differently (H's edge ratio
    goes 4:1 -> phi^4-1; F's interior angles change outright).
  - The reason is structural. Substituting a decorated tile maps 4 hats
    to 25 smaller ones, so the decoration is not scale-invariant. Hats
    exist only at level 0, anchored to the ORIGINAL shapes. The limit
    shapes are the attractor of the METATILE substitution alone.

  What the limit shapes are still good for: the per-level rules
  converge to them precisely. The linear parts are **exactly identical
  at every level** and the child shape sequences match exactly; only
  the translations differ, by a factor converging to exactly phi^(2L)
  with relative spread ~phi^(-2L) (4.9e-5 at level 6, 4.8e-10 at
  level 12).

  **Correction, found while implementing the Lua descent.** An earlier
  draft of this section offered "cap at depth 6, ~14,000 tiles" as a
  shipping option. That is wrong twice over.

  First, depth 6 covers **3,498 tiles** at the default scale, not
  14,000; the earlier figure came from an estimated metatile radius
  rather than the emitted one.

  Second and decisively, **the per-level rules cannot be composed at
  depth 6 in Lua doubles at all.** Level-6 numerators reach 1.4e14, so
  a single composition produces a raw product near 1e28. The reduced
  result is only ~1e9, but reducing afterwards is too late, and
  cross-reducing beforehand does not help: measured gcd between the
  operands is 1, because the cancellation is additive rather than
  multiplicative. Measured raw-product peaks:

  ```
  depth 4   3.9e13   OK
  depth 5   5.7e16   overflow
  depth 6   2.3e20   overflow
  ```

  Per-level rules are therefore limited to **depth 4 = 546 tiles**,
  which is unshippable. `Ti.safe_depth()` encodes this, and a test
  asserts the overflow still occurs so the ceiling cannot drift
  silently.

  The self-similar rules, by contrast, compose beautifully — max
  coefficient 219, reaching only 2,149 at depth 25 — but cannot reach
  the hats. So any shippable design uses **self-similar rules above a
  junction level and per-level rules below it**, and the only question
  is where the junction sits:

  | junction | block radius | rel. error | seam | occurs every |
  |---|---|---|---|---|
  | level 2 | 116 t | 1.2e-1 | 14.0 t | 116 t |
  | level 4 | 546 t | 2.3e-3 | 1.27 t | 546 t |
  | level 6 | 3,498 t | 4.9e-5 | 0.17 t | 3,498 t |

  Junction 4 needs no new machinery but leaves a ~1.3-tile seam every
  546 tiles, which is visible. Junction 6 leaves a 0.17-tile seam every
  3,498 tiles — below one tile, so invisible after rasterisation — but
  requires **two-word (106-bit) integer arithmetic** in the ring to
  compose levels 5 and 6. The depth-6 raw peak of 2.3e20 sits far
  inside 2^106 = 8.1e31.

  Seams of either size are fully deterministic: a fixed, identical
  deviation on every client, not float drift, so neither threatens
  multiplayer.

  **Recommendation: two-word arithmetic with the junction at level 6.**
  Unbounded map, sub-tile error, and the wider integers are confined to
  `hat/exact.lua`.
- `verify.py` — pairwise overlap, flood-fill gap detection, reflected
  density convergence, direct diff against hatviz's own SVG output, and
  the 2^53 coefficient assertion.
- `emit_lua.py` — writes committed Lua data files containing nothing
  but integer literals.

Attribution and the BSD-3-Clause notice ship with the mod.

## 7. Mod architecture

| Module | Responsibility | Factorio deps |
|---|---|---|
| `hat/transform.lua` | affine matrices, six doubles | none |
| `hat/tiling.lua` | lazy descent, `hats_in_box()` | none |
| `hat/geometry.lua` | outline, edges, band distance | none |
| `hat/index.lua` | descent-path identity | none |
| `hat/surface.lua` | per-surface scale, depth, root offset | storage |
| `terrain/bands.lua` | chunk -> band tiles | surface API |
| `build/enforce.lua` | build rejection + whitelist | events |
| `render/outline.lua` | optional crisp lines | rendering |

The first **five** have zero Factorio dependencies and run under plain
Lua in CI. That is where the risk lives and where it gets tested.

### Functional-core discipline

The layout satisfies SUPER (Radfar) — side effects at the edge,
uncoupled logic, pure and total functions, explicit data flow,
replaceable by value — arrived at from the determinism constraint
rather than from the principle. Three rules make it explicit:

- **`hat/surface.lua` is pure.** It takes surface config as a
  parameter; it does not read `storage`. The read happens in
  `control.lua`, so every side effect lives in one of the three
  Factorio-facing modules.
- **Transform values are immutable.** Lua tables are mutable by
  reference, so this is discipline rather than guarantee: every
  operation returns a new table, none mutates an argument. Asserted by
  test.
- **Totality.** The only division is by a squared length in
  `dist_to_segment`, guarded by a zero test, so no operation is
  partial.

The single deliberate exception is the descent's output accumulator,
which is mutated in place for performance. It is local to
`hat/tiling.lua` and never escapes.

## 8. Terrain generation

`on_chunk_generated` -> compute -> `set_tiles`. No per-tick cost.

- **Band test:** for each hat overlapping the chunk (query box expanded
  by band width), rasterise each of its 13 edges as a thick line.
  Shared edges dedup by exact endpoint key so each is walked once.
  Roughly an order of magnitude cheaper than per-tile point-in-polygon,
  and it computes the quantity actually wanted.
- **Do not fill water.** Paint only where the existing tile is land, so
  lakes and their vanilla shore transitions survive.
- **Ore is already placed** when the event fires. Leave it. Resource
  richness is raised at map-gen to compensate for slicing — at default
  settings only ~45% of a patch is reachable by a 3x3 drill, so the
  compensation factor is ~2.2x.
- **Chunk-boundary continuity** holds by construction: each chunk
  derives bands from the tiling, never from neighbours' tiles.
- **Skip space platforms.** Planets only.

## 9. Build enforcement

**Native, via a custom collision layer.** This reverses an earlier
decision in this document, which specified script-side rejection.

Factorio 2.0 lets mods declare collision layers
(`{type="collision-layer", name="hattorio_band"}`, 256 available), and
two prototypes collide only if they share a layer. The band tiles carry
that layer; `data-final-fixes` adds it to buildable structures but not
to the character, vehicles or rails.

The game then refuses the placement itself: red preview, blueprints
skip those tiles, bots never attempt them, and no ghosts are left
behind. Script rejection would place the entity and then remove it,
which is visibly worse, and would need `on_built_entity`,
`on_robot_built_entity`, `script_raised_built`, `on_pre_build` and
ghost cleanup to approximate what one prototype field gets for free.

The cost is that `data-final-fixes` must enumerate the entity types to
patch. That list is explicit rather than heuristic, so an unpatched
modded entity fails open (buildable on bands) rather than breaking.

No per-chunk band bitmap is needed in `storage` as a result — the
collision system does the lookup.

## 10. Visuals

- **Band tiles are the primary visual**, per-planet tinted (dark basalt
  on Vulcanus, ice on Aquilo, and so on). Custom tiles cloned from a
  vanilla prototype so transition graphics are inherited, with
  `walking_speed_modifier` zeroed.
- **Reflected hats get a subtly different tint** on their own edges. A
  reflected hat paints all 13 of its edges in variant B; where a
  reflected and unreflected hat share an edge, reflected wins.
  Deterministic.
- **Optional crisp outline**, `draw_line` with `draw_on_ground = true`,
  sub-tile precision, drawn down the band's centre so the two coincide.
  Runtime toggle. Default on at large cell sizes, off at small ones:
  after shared-edge dedup a full screen is ~7k objects at size 20 and
  ~19k at size 12.
- `draw_polygon` is **not used**. It is a triangle strip, not a
  polygon, and has no `draw_on_ground`, so fills would tint entities.

## 11. Settings

Per planet, startup:

| Setting | Default | Range |
|---|---|---|
| `hattorio-hat-size-<planet>` | **26** (centre-to-vertex, tiles) | 15-90 |
| `hattorio-band-width-<planet>` | **2** | 1-6 |

Both are genuine player settings, per planet, exactly as Hextorio does
it. 26/2 gives a 347-tile cell where blueprints up to 11x11 -- about
one assembler cluster -- stay reusable while everything larger must be
hand-fitted. Hextorio parity would be size 52; 41 is a middle option.

**Why startup rather than runtime.** The geometry determines terrain,
so changing it under an existing save would leave every generated
chunk stale and seam visibly. Startup settings are fixed at load.

**How a change is made safe.** Scale, band, depth and root offset are
stored per surface at creation (section 12). A player who changes the
setting later affects only NEW surfaces; existing ones keep the
geometry their terrain was built with. That removes the stale-chunk
problem by construction rather than by regeneration, and is the idea
worth taking from Hextorio's `continuous_geometry` flag.

**Depth is derived, not set.** Coverage scales linearly with hat size,
so a smaller hat needs a deeper root. `Ti.depth_covering(unit, cover)`
picks the shallowest depth that reaches the map edge; it is computed
once at surface creation and stored. Rules are emitted to level 15,
which leaves margin across the whole settings range.

**`coverage()` is a circumradius, and the root is a hexagon.** A square
region inscribed in that circle is NOT fully tiled -- its corners fall
outside the root. A 2e6 x 2e6 map has a half-diagonal of 1.41e6, so
`cover` must be asked for generously, never as the half-width. This
was caught by a preview render showing an untiled corner; a test now
asserts zero uncovered points in a box well inside the root.

**Hats carry a 0.5 scale factor.** `H_init` and friends place hats at
half scale, so a descent at `unit` tiles per kite unit yields hats of
circumradius `0.5 * unit * 4.5826`. The factor is emitted as
`hat_scale`, and the pipeline asserts every level-0 placement shares
it, so a placement that broke congruence would fail the build. Callers
should state a hat size and use `Ti.unit_for_hat_size()`; doing the
conversion by hand produced cells at half the intended size once
already.

Runtime-global: outline visibility, outline width, outline alpha.

Scale, depth and root offset are **stored per surface at creation**. Changing
a startup setting later affects only new surfaces, so already-generated
chunks never go stale and no seam can appear. This is the one idea
worth taking from Hextorio's `continuous_geometry` flag.

## 12. Storage

Persist only what cannot be recomputed: per-surface scale, depth and
root offset, and the per-chunk band bitmap cache. Render objects are derived
state. `on_configuration_changed` drops and rebuilds them.

## 13. Testing

Red-green-refactor with busted + luassert, and luacheck for static
analysis. Tests run under **Lua 5.2 specifically** — 5.3+ adds an
integer subtype that would mask the all-doubles behaviour the core
depends on. Property-style tests are plain loops over fixed seeds
rather than a generative library. No static type checker is in use.
See `toolchain-decisions.md`.

1. **Offline (Python).** Overlap, gap, density, SVG diff, coefficient
   bound. Catches a sign error before any Lua exists.
2. **busted, pure Lua, no Factorio.** Property tests on the ring's
   algebraic laws (associativity, distributivity, `phi^2 = phi + 1`,
   agreement with an arbitrary-precision reference); transform
   composition; identity uniqueness. Plus **golden-file tests** — the
   pipeline exports the exact hat set for a known box and
   `hat/tiling.lua` must reproduce it byte-identically.
3. **In-game.** Visual check, band continuity across chunk boundaries,
   build-rejection behaviour including ghosts and bots, UPS under load,
   and a two-client desync smoke test.

## 14. Corrections to earlier documents

Recorded so they are not re-derived.

- **hatviz does not store substitution rules as matrices.** The earlier
  chat transcript says it does. It does not; see section 6.
- **The hat is a 13-gon, not a 14-gon.** An earlier claim that the
  scaffold's 14-vertex `HAT_OUTLINE` "matches Kaplan's exactly" was
  wrong. hatviz's real outline has 13 vertices in the `hexPt` basis,
  `hexPt(x,y) = (x + y/2, (sqrt3/2)*y)`. Since `H_init` indexes
  `hat_outline[5]`, `[7]`, `[9]` and `[11]`, a wrong vertex list
  silently produces wrong hat placements.
- **Every gameplay number in this document was first computed against
  the wrong hat.** The 14-gon in the original scaffold has area 22.08
  where the real 13-gon has 13.86 -- an overstatement of 1.59x. That
  invalidated the cell-size table, the largest-rectangle figures, the
  ore drillability numbers and the Hextorio-equal-area scale (52, not
  41). All are recomputed above. Caught by rendering the tiling and
  noticing measured band coverage was twice the predicted value.
- **Band coverage is not perimeter x width / 2.** Corner rounding and
  tile-centre rasterisation push it well above that estimate: 28.0%
  measured at size 41 / band 2 against 14.8% predicted. Measure it by
  rasterising, never by formula.
- **Metatile area does not equal its hats' area.** Hats straddle
  metatile boundaries, so an area check is not a validity test for
  H, T or F. Use overlap plus gap detection.
- **Per-level rule coefficients exceed 2^53 at level 7**, and raw
  products overflow from depth 5, capping exact-integer descent at
  depth 4. This is what forced the move to doubles; see section 5.
- **Exact integer arithmetic was the wrong call, and it was mine.**
  The brainstorm presented it as necessary for multiplayer
  determinism. It is not: determinism needs only correctly-rounded
  IEEE operations, which doubles have. The exact machinery cost a
  depth ceiling, a gcd reduction in the hot path, and ~200 lines of
  Lua, and bought nothing the cheaper option lacked.
- **"14 tile types and enormous transition tables"** assumed colouring
  every hat. Only the band is a custom tile, against vanilla terrain.
- **Target runtime is not a choice.** Factorio embeds Lua 5.2.1. No
  integer subtype, all doubles, 2^53 ceiling. LuaJIT NaN-boxing does
  not apply. The original toolchain notes listed this as an open
  question.
- **Most of those notes' floating-point section was moot**, and the
  rest was superseded once the core moved to doubles. What survives is
  in `toolchain-decisions.md`: the 2^53 ceiling, and `tostring` being
  lossy `%.14g`, which is why identity is a descent path.
- **Teal and Luau are both out.** Luau is the wrong runtime; Teal has
  no Factorio API definitions, so every API call would be an untyped
  escape hatch anyway.
- **Factorio 2.1.19 exists but is experimental.** Stable is 2.0.77.
  Develop against stable; declare `factorio_version = "2.0"`, which
  loads on both.
- **`draw_polygon` is a triangle strip** and has no `draw_on_ground`.
- **The rasterisation problem is real here.** It was briefly thought
  avoidable via a line overlay; bands are terrain, so stair-stepping
  returns. It lands inside the band, which is why Hextorio's ragged
  hexes read as deliberate.
- **Hextorio's `hex_lattice.lua` trick does not transfer.** Snapping a
  grid to integers needs periodicity. phi is irreducibly irrational.

## 15. Out of scope

Claiming, cores, trades, ore gating by cell, impassable band variants,
band removal, and any territory layer. `hat/tiling.lua` and the
descent-path hierarchy are designed so these can be added without
changing the core.

## 16. Open items for review

1. **Starting area — decided: no grace area.** At the default 26/2 the
   spawn cell holds ~347 buildable tiles, enough for a burner start,
   and bands are walkable so nothing is unreachable before underground
   belts arrive. A grace area would undercut the premise exactly where
   a new player forms their impression. First thing to revisit after
   playtesting; the cell-size setting is the escape hatch meanwhile.
2. **Default cell size is a guess.** 20/2 is reasoned, not playtested.
   Expect to tune it.
3. **Resource compensation factor** (~2.2x) is derived from drill
   reachability at default settings; it should vary with the size
   setting rather than being a constant.
