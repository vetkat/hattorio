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
modest mall is ~30x30. Worst-case largest axis-aligned square that fits
in one cell, measured across all 12 orientations:

| hat size | band | cell interior | largest square |
|---|---|---|---|
| 12 | 1 | 111 tiles | 5x5 |
| 16 | 1 | 224 | 9x9 |
| 20 | 2 | 310 | 10x10 |
| 26 | 3 | 501 | 13x13 |
| 41 | 3 | 1,415 | 19x19 |

**Orientations are unreachable.** Hats occur at 30/60 degree
orientations. Factorio rotates blueprints in 90 degree steps, so a
layout fitted to one cell cannot be re-used in a differently oriented
one. Players must hand-build each cell.

Reflected hats (~1 in 8, density 1/(phi^4+1) ~ 0.1273) compound this
further.

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

### Ring

Every coordinate is four integers, `(a + b*phi) + (c + d*phi)*sqrt(3)`,
with `phi^2 = phi + 1` and `sqrt(3)^2 = 3` closing multiplication
exactly. Hat vertices are exact integer points in the triangular basis
`{(1,0), (1/2, sqrt(3)/2)}`; the 12 orientations are integer matrices
there (60 degrees is `[[1,-1],[1,0]]`). Only the substitution's `phi^2`
leaves Z, which is what the ring is for.

`hat/exact.lua` provides add, sub, mul, negate, equality, to_float.
There is deliberately **no division** — the descent only composes.
Division occurs solely in offline rule extraction, where exact
rationals are free.

### Determinism is not exactness

Factorio has no server authority; every client simulates independently
and a divergence is a desync.

- IEEE `+ - * /` and `sqrt` are deterministic across platforms.
- `sin`, `cos` and `^`/`pow` are **not**.
- Exactness is needed only where error accumulates: composing
  transforms down 9-12 levels, where drift eventually splits a shared
  edge.
- Determinism alone suffices for leaf queries — pruning tests, band
  distance tests — which run in plain floats.

Rule: **exact ring for composition, deterministic floats for leaf
queries.**

### Depth and coverage

**Measured, and more constrained than first estimated.** The per-level
substitution rules are exact rationals converging on irrational limits,
so their numerators blow up with level:

```
level 6:  numerators 1.4e14   OK
level 7:  numerators 1.7e16   exceeds 2^53 = 9.0e15
```

Lua 5.2 has no integer subtype, so a rule coefficient above 2^53 is not
exactly representable. **Maximum emittable depth is 6**, which covers:

```
hat size 20 (default)  ->  ~14,000 tiles from spawn
hat size 41            ->  ~28,800 tiles
hat size 90            ->  ~63,200 tiles
```

Beyond that radius the mod must fall back to vanilla terrain. For a
genuinely unbounded map the limiting metatiles must be exactified
(section 6) — one rule set, small exact coefficients, any depth.

Two separate ceilings, not to be confused:

- **Rule data**, above: binds at level 7. The hard limit today.
- **Composition during descent**, which is fine: intermediate
  coefficients grow ~18x per level and peak at 3.6e14 at depth 11,
  24x inside 2^53. Hats land back on the clean kite lattice, so the
  ugly rationals cancel. This requires the Lua transform multiply to
  **reduce by gcd after every composition**; without reduction the
  denominators multiply and overflow almost immediately.

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
- `exactify.py` — **load-bearing, not optional.** Runs deep, fits the
  converged outlines to exact Z[phi][sqrt3], and verifies the fixed
  point. Without it the mod is capped at depth 6. The outlines do
  converge cleanly (drift 2.4e-10 by level 12) and the limiting H is a
  hexagon whose edge ratio is exactly phi^4 - 1 = sqrt5*phi^2, so the
  target is well characterised — but the fit is unwritten research, not
  a port. Until it lands, ship the depth-6 cap.
- `verify.py` — pairwise overlap, flood-fill gap detection, reflected
  density convergence, direct diff against hatviz's own SVG output, and
  the 2^53 coefficient assertion.
- `emit_lua.py` — writes committed Lua data files containing nothing
  but integer literals.

Attribution and the BSD-3-Clause notice ship with the mod.

## 7. Mod architecture

| Module | Responsibility | Factorio deps |
|---|---|---|
| `hat/exact.lua` | the number ring | none |
| `hat/transform.lua` | affine matrices over the ring | none |
| `hat/tiling.lua` | lazy descent, `hats_in_box()` | none |
| `hat/geometry.lua` | outline, edges, band distance | none |
| `hat/index.lua` | descent-path identity | none |
| `hat/surface.lua` | per-surface scale, depth, root offset | storage |
| `terrain/bands.lua` | chunk -> band tiles | surface API |
| `build/enforce.lua` | build rejection + whitelist | events |
| `render/outline.lua` | optional crisp lines | rendering |

The first **six** have zero Factorio dependencies and run under plain
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
- **Ring and transform values are immutable.** Lua tables are mutable
  by reference, so this is discipline rather than guarantee: every
  operation returns a new table, none mutates an argument. Asserted by
  property tests.
- **Totality comes free.** The ring has no division, so no operation
  is partial — there is no divide-by-zero to define behaviour for.

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

Script-side, not collision masks — precise, whitelistable, and it
touches no prototypes, so it does not break other mods.

- Hooks: `on_built_entity`, `on_robot_built_entity`,
  `script_raised_built`, `on_pre_build`, plus ghost handling so bots do
  not retry forever.
- Whitelist: rails, and any entity type that tunnels.
- Rejection returns the item and shows flying text.
- Band membership is a cached per-chunk bitmap in `storage` — the hot
  path must not re-run geometry.

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
| `hattorio-hat-size-<planet>` | 20 (centre-to-vertex, tiles) | 8-90 |
| `hattorio-band-width-<planet>` | 2 | 1-6 |

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

Per DECISIONS.md: red-green-refactor, busted + luassert, luacheck,
lua-quickcheck. Static typing via LuaLS annotations plus FMTK's
generated Factorio API definitions — no build step, ships as plain Lua,
runs unmodified under busted.

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
- **Metatile area does not equal its hats' area.** Hats straddle
  metatile boundaries, so an area check is not a validity test for
  H, T or F. Use overlap plus gap detection.
- **Per-level rule coefficients exceed 2^53 at level 7.** This caps
  depth at 6 until exactify lands; see section 5.
- **"14 tile types and enormous transition tables"** assumed colouring
  every hat. Only the band is a custom tile, against vanilla terrain.
- **Target runtime is not a choice.** Factorio embeds Lua 5.2.1. No
  integer subtype, all doubles, 2^53 ceiling. LuaJIT NaN-boxing does
  not apply. DECISIONS.md lists this as an open question.
- **Most of DECISIONS.md's floating-point section is moot.** There is
  no IEEE-sensitive code in the core. Comparison policy is exact
  integer equality. FPBench, FPTaylor, Gappa and Herbie are not needed.
  What survives: the 2^53 ceiling (now an asserted obligation),
  `tostring` being lossy `%.14g` (the reason identity is a descent
  path), and `%` being floor-mod.
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

1. **Starting area.** At default settings the spawn cell has ~310
   buildable tiles, which is tight for a starting base. Options: a
   grace radius with bands suppressed, guaranteeing spawn in a
   large-orientation cell, or leaving it as intended difficulty.
   Needs a decision.
2. **Default cell size is a guess.** 20/2 is reasoned, not playtested.
   Expect to tune it.
3. **Resource compensation factor** (~2.2x) is derived from drill
   reachability at default settings; it should vary with the size
   setting rather than being a constant.
