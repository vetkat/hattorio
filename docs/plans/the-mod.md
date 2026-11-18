# Hattorio mod implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task by task. The steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the finished tiling core into a Factorio mod that people can
play: buildable cells in the shape of hats, with unbuildable bands between
them.

**Architecture:** The band tiles have a custom collision layer. Buildings
collide with it and the character does not, so the game blocks construction
natively and no script has to reject it. The mod paints the terrain once, at
chunk generation, from the tiling core. The mod derives everything that it
can derive. `storage` holds only the geometry for each surface and a cache of
band bitmaps.

**Tech stack:** Factorio 2.0.77, Lua 5.2.1, busted, luacheck. Uses `hat/`
from plan 1.

**Spec:** `docs/design/hattorio-design.md`

## Global constraints

- **Factorio 2.0.77** stable. `info.json` declares
  `factorio_version = "2.0"`, which loads on 2.0 and 2.1. (This was wrong.
  Factorio 2.1 does not load a mod that says "2.0". See the design document,
  section 14.)
- **Lua 5.2.1.** There is no integer subtype. All numbers are doubles.
- **Never use `math.sin`, `math.cos`, `math.random` or `^` in shipped Lua.**
  They do not give identical bits on all platforms, and a difference is a
  desync. `+ - * /` and `sqrt` are safe.
- **`hat/` must keep zero Factorio dependencies.** New mod code goes in
  `mod/`, never in `hat/`.
- **Defaults: hat size 41, band width 3**, per planet, as startup settings.
  The dropdowns offer sizes 15, 26, 41 and 52 and band widths 1 to 4.
  `mod/config.lua` still clamps any other value to 15-90 and 1-6.
- **The mod stores the geometry for each surface when it creates the
  surface.** A later change to the settings must affect only new surfaces.
- **Bands are permanent.** No technology, item or mechanic removes them.
- **Rails are exempt** and cross bands. Undergrounds go under them. Bands do
  not affect power or bots.
- Generated files keep their `-- GENERATED` header. Regenerate them with
  `make data`.

## What we can and cannot test here

We could unit test almost all of plan 1. We cannot do that for this plan, and
it is better to say so than to pretend.

- **We can test under busted** (without Factorio): settings validation, the
  geometry for each surface and band rasterisation. Tasks 3, 5 and 6 put as
  much logic as possible into these pure modules.
- **We cannot test without the game:** prototypes that load, collision masks
  that really block, chunk events that fire, and desync behaviour. Tasks 2,
  4, 7, 9 and 10 end with an explicit **in-game checklist** and not with an
  assertion. Those checklists are the deliverable. Do not mark such a task
  done only because the code looks right.

## File structure

```text
info.json                     mod manifest
changelog.txt                 Factorio's strict changelog format
thumbnail.png                 144x144, generated from the tiling renderer
data.lua                      loads prototypes/
data-final-fixes.lua          patches entity collision masks, after all mods
settings.lua                  loads prototypes/settings.lua
control.lua                   runtime entry point, event wiring only
locale/en/hattorio.cfg        setting names and descriptions

prototypes/collision.lua      the hattorio_band collision layer
prototypes/tiles.lua          band tile prototypes, one pair per planet
prototypes/settings.lua       startup settings, per planet
prototypes/patch.lua          adds the layer to buildable entity masks

mod/planets.lua               which planets are tiled, and their palette
mod/config.lua                PURE: validate settings -> geometry numbers
mod/surface.lua               per-surface geometry, reads/writes storage
mod/bands.lua                 PURE: hats + band width -> band tile positions
mod/terrain.lua               chunk generation -> set_tiles
spec/config_spec.lua          busted
spec/bands_spec.lua           busted
```

The important split is this: `mod/config.lua` and `mod/bands.lua` make **no
calls to the Factorio API**, so they run under plain Lua in CI, the same as
`hat/`. `mod/surface.lua` and `mod/terrain.lua` are the shell that talks to
the game.

---

### Task 1: Mod skeleton

**Files:**

- Create: `info.json`, `changelog.txt`, `data.lua`, `control.lua`,
  `settings.lua`, `locale/en/hattorio.cfg`
- Modify: `.github/workflows/check.yml`

**Interfaces:**

- Consumes: nothing
- Produces: a mod directory that Factorio will load

- [ ] **Step 1: Write the manifest**

`info.json`:

```json
{
  "name": "hattorio",
  "version": "0.1.0",
  "title": "Hattorio",
  "author": "vetkat",
  "factorio_version": "2.0",
  "description": "Replaces the square grid with the aperiodic hat monotile tiling. Cells never repeat, so neither can your blueprints.",
  "dependencies": ["base >= 2.0.0", "? space-age"]
}
```

`changelog.txt`: Factorio's format is strict. It needs exactly 99 dashes, an
indent of two spaces for `Date:` and the category, and four for the entries.

```text
---------------------------------------------------------------------------------------------------
Version: 0.1.0
Date: 2026-09-20
  Major Features:
    - Planets are divided into cells of the aperiodic hat monotile tiling.
    - Cells are separated by narrow unbuildable bands. Undergrounds tunnel
      beneath them; rails cross them; bots and power ignore them.
```

- [ ] **Step 2: Write the entry points**

`data.lua`:

```lua
require("prototypes.collision")
require("prototypes.tiles")
```

`data-final-fixes.lua`:

```lua
require("prototypes.patch")
```

`settings.lua`:

```lua
require("prototypes.settings")
```

`control.lua`:

```lua
require("mod.terrain")
```

`locale/en/hattorio.cfg`:

```ini
[mod-setting-name]
hattorio-hat-size-nauvis=Cell size (Nauvis)
hattorio-band-width-nauvis=Band width (Nauvis)

[mod-setting-description]
hattorio-hat-size-nauvis=Distance from a cell's centre to its furthest corner, in tiles. Larger cells give more room and let larger blueprints be reused.
hattorio-band-width-nauvis=Width of the unbuildable band between cells, in tiles. Keep below underground belt reach or cells become isolated.
```

- [ ] **Step 3: Validate the manifest**

Run:

```bash
python3 -c "import json; d=json.load(open('info.json')); \
  assert d['factorio_version']=='2.0'; \
  assert all(k in d for k in ('name','version','title','author','description','dependencies')); \
  print('info.json ok:', d['name'], d['version'])"
```

Expected: `info.json ok: hattorio 0.1.0`

- [ ] **Step 4: Add the manifest check to CI**

In `.github/workflows/check.yml`, in the `pipeline` job, after the pytest
step:

```yaml
      - name: validate info.json
        run: python3 -c "import json; json.load(open('info.json'))"
```

- [ ] **Step 5: Commit**

```bash
git add info.json changelog.txt data.lua data-final-fixes.lua settings.lua control.lua locale .github
git commit -m "feat(mod): manifest, entry points and locale"
```

---

### Task 2: Collision layer and band tiles

The game blocks construction natively, not through a script. The band tile
has a custom collision layer. Building masks include that layer, and the
masks of the character and of vehicles do not. So the game itself refuses
the placement: the preview is red, blueprints skip those tiles, and bots
never try. Rejection in a script would place the entity and then remove it,
and it would leave ghosts that bots try to build again for ever.

**Files:**

- Create: `prototypes/collision.lua`, `prototypes/tiles.lua`,
  `mod/planets.lua`

**Interfaces:**

- Consumes: nothing
- Produces:
  - a collision layer called `hattorio_band`
  - tiles `hattorio-band-<planet>` and `hattorio-band-<planet>-mirror`
  - `mod/planets.lua`, which returns this table:

    ```lua
    { [name] = { base_tile = <string>, map_color = {r,g,b}, mirror_color = {r,g,b} } }
    ```

- [ ] **Step 1: Declare the collision layer**

`prototypes/collision.lua`:

```lua
-- A layer the band tiles carry and buildings are given in data-final-fixes.
-- Two prototypes collide only if they share a layer, so the character and
-- vehicles -- which never receive this one -- cross bands freely.
data:extend({
  { type = "collision-layer", name = "hattorio_band" },
})
```

- [ ] **Step 2: Declare the planet palette**

`mod/planets.lua`:

```lua
-- Which surfaces get tiled, and what the band looks like there.
-- base_tile is a vanilla tile whose graphics and transitions are cloned;
-- only the name, colours and collision mask are changed.
return {
  nauvis   = { base_tile = "stone-path", map_color = { 43, 47, 54 },
               mirror_color = { 20, 121, 201 } },
  vulcanus = { base_tile = "stone-path", map_color = { 38, 26, 24 },
               mirror_color = { 176, 64, 32 } },
  fulgora  = { base_tile = "stone-path", map_color = { 46, 38, 56 },
               mirror_color = { 150, 96, 200 } },
  gleba    = { base_tile = "stone-path", map_color = { 34, 46, 32 },
               mirror_color = { 120, 170, 70 } },
  aquilo   = { base_tile = "stone-path", map_color = { 48, 56, 62 },
               mirror_color = { 120, 180, 210 } },
}
```

- [ ] **Step 3: Generate the tile prototypes**

`prototypes/tiles.lua`:

```lua
local planets = require("mod.planets")

-- A TilePrototype needs name, type, collision_mask, layer, variants and
-- map_color. Cloning a vanilla tile inherits variants and transitions, which
-- is the expensive part to author. walking_speed_modifier is left at its
-- default of 1, so a band grants no free concrete.
local function band_tile(name, base, color)
  local t = table.deepcopy(data.raw.tile[base])
  t.name = name
  t.map_color = color
  t.walking_speed_modifier = nil
  t.minable = nil
  t.mined_sound = nil
  t.can_be_part_of_blueprint = false
  t.collision_mask = {
    layers = { hattorio_band = true },
  }
  t.autoplace = nil
  t.order = "z[hattorio]"
  return t
end

local tiles = {}
for planet, cfg in pairs(planets) do
  tiles[#tiles + 1] = band_tile("hattorio-band-" .. planet, cfg.base_tile, cfg.map_color)
  tiles[#tiles + 1] = band_tile("hattorio-band-" .. planet .. "-mirror",
                                cfg.base_tile, cfg.mirror_color)
end
data:extend(tiles)
```

- [ ] **Step 4: In-game check (you cannot unit test this)**

Start Factorio with the mod enabled and check these points in order:

1. The game **loads without a prototype error**. A missing required field
   (`collision_mask`, `layer`, `variants`, `map_color`) fails here.
2. In the editor, this command places a tile:
   `/c game.player.surface.set_tiles{{name="hattorio-band-nauvis", position={0,0}}}`
3. From a position next to the tile, you **can walk onto it**.
4. When you hold an assembling machine over the tile, the **placement
   preview is red** and the game refuses the build.

If point 4 fails, the entity masks are not patched yet. Task 4 does that. Do
not continue until points 1 to 3 pass.

- [ ] **Step 5: Commit**

```bash
git add prototypes/collision.lua prototypes/tiles.lua mod/planets.lua
git commit -m "feat(mod): band collision layer and per-planet band tiles"
```

---

### Task 3: Settings prototypes and pure validation

**Files:**

- Create: `prototypes/settings.lua`, `mod/config.lua`
- Test: `spec/config_spec.lua`

**Interfaces:**

- Consumes: `mod/planets.lua`, `hat/tiling.lua`
- Produces (`mod/config.lua`):
  - `Config.MIN_SIZE = 15`, `Config.MAX_SIZE = 90`, `Config.MIN_BAND = 1`,
    `Config.MAX_BAND = 6`
  - `Config.DEFAULT_SIZE = 41`, `Config.DEFAULT_BAND = 3`
  - `Config.clamp(size, band) -> size, band`
  - `Config.geometry(size, band) -> { size=, band=, unit=, depth=, half= }`
  - `Config.richness_multiplier(size, band) -> number`

- [ ] **Step 1: Write the failing test**

`spec/config_spec.lua`:

```lua
local Config = require("mod.config")
local Ti = require("hat.tiling")

describe("config", function()
  it("clamps out-of-range settings", function()
    local s, b = Config.clamp(3, 99)
    assert.are.equal(Config.MIN_SIZE, s)
    assert.are.equal(Config.MAX_BAND, b)
    s, b = Config.clamp(1000, -5)
    assert.are.equal(Config.MAX_SIZE, s)
    assert.are.equal(Config.MIN_BAND, b)
  end)

  it("leaves valid settings alone", function()
    local s, b = Config.clamp(26, 2)
    assert.are.equal(26, s)
    assert.are.equal(2, b)
  end)

  it("derives a unit that yields the requested hat size", function()
    for _, size in ipairs({ 15, 26, 41, 90 }) do
      local g = Config.geometry(size, 2)
      assert.is_true(math.abs(Ti.hat_size_for_unit(g.unit) - size) < 1e-9)
    end
  end)

  it("derives a depth that covers the whole map", function()
    for _, size in ipairs({ 15, 26, 41, 90 }) do
      local g = Config.geometry(size, 2)
      local t = Ti.new({ unit = g.unit, depth = g.depth })
      assert.is_true(t:coverage() > 1.5e6, "size " .. size)
    end
  end)

  it("uses a deeper root for a smaller cell", function()
    assert.is_true(Config.geometry(15, 2).depth > Config.geometry(90, 2).depth)
  end)

  it("carries half the band width for distance tests", function()
    assert.are.equal(1, Config.geometry(26, 2).half)
  end)

  it("compensates richness more when less ore is drillable", function()
    -- smaller cells lose proportionally more ore to bands
    local small = Config.richness_multiplier(15, 2)
    local large = Config.richness_multiplier(90, 2)
    assert.is_true(small > large, small .. " should exceed " .. large)
    assert.is_true(large >= 1.0)
    assert.is_true(small < 5.0, "compensation should stay sane")
  end)

  it("defaults to 41 and 3", function()
    assert.are.equal(41, Config.DEFAULT_SIZE)
    assert.are.equal(3, Config.DEFAULT_BAND)
  end)
end)
```

- [ ] **Step 2: Run the test and check that it fails**

Run: `make test`
Expected: FAIL, `module 'mod.config' not found`

- [ ] **Step 3: Implement**

`mod/config.lua`:

```lua
-- Pure: settings numbers in, geometry numbers out. No Factorio API here, so
-- this runs under plain Lua in CI.

local Ti = require("hat.tiling")

local Config = {}

Config.MIN_SIZE, Config.MAX_SIZE = 15, 90
Config.MIN_BAND, Config.MAX_BAND = 1, 6
Config.DEFAULT_SIZE, Config.DEFAULT_BAND = 41, 3

-- The map is 2e6 x 2e6, so its half-diagonal is ~1.41e6. coverage() is a
-- circumradius of a hexagonal root, so a square region inscribed in it is not
-- fully tiled: ask for comfortably more than the half-diagonal.
Config.REQUIRED_COVER = 1.6e6

local function clamp1(v, lo, hi)
  if v ~= v then return lo end               -- x ~= x is the NaN test
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Config.clamp(size, band)
  return clamp1(size or Config.DEFAULT_SIZE, Config.MIN_SIZE, Config.MAX_SIZE),
         clamp1(band or Config.DEFAULT_BAND, Config.MIN_BAND, Config.MAX_BAND)
end

function Config.geometry(size, band)
  size, band = Config.clamp(size, band)
  local unit = Ti.unit_for_hat_size(size)
  local depth = assert(Ti.depth_covering(unit, Config.REQUIRED_COVER),
    "no emitted depth covers the map at cell size " .. size)
  return { size = size, band = band, unit = unit, depth = depth, half = band / 2 }
end

-- Bands cost ore twice: the band tiles themselves, and the clearance a 3x3
-- drill needs. Both scale with the band-to-cell perimeter ratio, which goes
-- as band/size. Measured drillable fractions: 40% at 26/2, 68% at 41/2.
function Config.richness_multiplier(size, band)
  size, band = Config.clamp(size, band)
  local drillable = 1 - (2.6 * band + 2.0) / size
  if drillable < 0.2 then drillable = 0.2 end
  if drillable > 1.0 then drillable = 1.0 end
  return 1 / drillable
end

return Config
```

- [ ] **Step 4: Run the test and check that it passes**

Run: `make test`
Expected: all green, 8 new successes.

- [ ] **Step 5: Generate the settings prototypes**

`prototypes/settings.lua`:

```lua
local planets = require("mod.planets")

-- Startup, not runtime: the geometry decides terrain, so changing it under an
-- existing save would leave every generated chunk stale. mod/surface.lua
-- stores the values per surface at creation so a later change affects only
-- new surfaces.
local settings_list = {}
local order = 0
for planet, _ in pairs(planets) do
  order = order + 1
  settings_list[#settings_list + 1] = {
    type = "int-setting",
    name = "hattorio-hat-size-" .. planet,
    setting_type = "startup",
    default_value = 41,
    minimum_value = 15,
    maximum_value = 90,
    order = string.format("a[size]-%02d[%s]", order, planet),
  }
  settings_list[#settings_list + 1] = {
    type = "int-setting",
    name = "hattorio-band-width-" .. planet,
    setting_type = "startup",
    default_value = 3,
    minimum_value = 1,
    maximum_value = 6,
    order = string.format("b[band]-%02d[%s]", order, planet),
  }
end
data:extend(settings_list)
```

The bounds are copied here and not loaded from `mod/config.lua`. The reason
is that the settings stage cannot `require` a module that loads the data files
of `hat/tiling.lua`. A test in task 3 makes sure that the copies stay the
same. Add it now:

```lua
  it("matches the bounds declared in prototypes/settings.lua", function()
    local f = assert(io.open("prototypes/settings.lua", "r"))
    local src = f:read("*a"); f:close()
    assert.is_not_nil(src:find("default_value = " .. Config.DEFAULT_SIZE))
    assert.is_not_nil(src:find("minimum_value = " .. Config.MIN_SIZE))
    assert.is_not_nil(src:find("maximum_value = " .. Config.MAX_SIZE))
    assert.is_not_nil(src:find("default_value = " .. Config.DEFAULT_BAND))
    assert.is_not_nil(src:find("maximum_value = " .. Config.MAX_BAND))
  end)
```

- [ ] **Step 6: Commit**

```bash
git add prototypes/settings.lua mod/config.lua spec/config_spec.lua
git commit -m "feat(mod): startup settings and pure geometry derivation"
```

---

### Task 4: Patch entity collision masks

**Files:**

- Create: `prototypes/patch.lua`

**Interfaces:**

- Consumes: the `hattorio_band` collision layer from task 2
- Produces: every buildable structure collides with `hattorio_band`

- [ ] **Step 1: Write the patch**

`prototypes/patch.lua`:

```lua
-- data-final-fixes, so this sees every entity every other mod added.
--
-- Two prototypes collide only if they share a layer. Giving buildings the
-- band layer makes the game refuse to place them on a band natively -- red
-- preview, blueprints skip the tiles, bots never attempt them. The character,
-- vehicles and rails are deliberately NOT patched, so players walk and drive
-- across bands and trains cross them.

-- Types that are player-built structures. Rails and vehicles are absent on
-- purpose; so are trees, cliffs, resources and enemies, which are placed by
-- map generation and must be free to sit on a band.
local BLOCKED_TYPES = {
  "accumulator", "agricultural-tower", "ammo-turret", "arithmetic-combinator",
  "artillery-turret", "assembling-machine", "asteroid-collector", "beacon",
  "boiler", "burner-generator", "constant-combinator", "container",
  "decider-combinator", "display-panel", "electric-energy-interface",
  "electric-pole", "electric-turret", "fluid-turret", "furnace", "gate",
  "generator", "heat-interface", "heat-pipe", "inserter", "lab", "lamp",
  "land-mine", "lightning-attractor", "linked-belt", "linked-container",
  "loader", "loader-1x1", "logistic-container", "mining-drill", "offshore-pump",
  "pipe", "pipe-to-ground", "power-switch", "programmable-speaker", "pump",
  "radar", "reactor", "roboport", "rocket-silo", "selector-combinator",
  "solar-panel", "splitter", "storage-tank", "thruster", "train-stop",
  "transport-belt", "underground-belt", "valve", "wall",
}

local layer = "hattorio_band"
local patched = 0

for _, type_name in ipairs(BLOCKED_TYPES) do
  for _, proto in pairs(data.raw[type_name] or {}) do
    local mask = proto.collision_mask
    if mask and mask.layers then
      mask.layers[layer] = true
      patched = patched + 1
    end
  end
end

log("hattorio: added " .. layer .. " to " .. patched .. " entity prototypes")
```

- [ ] **Step 2: In-game check (you cannot unit test this)**

Start Factorio and check these points:

1. The game loads, and the log contains
   `hattorio: added hattorio_band to N entity prototypes`, with N in the
   hundreds. Zero means that the `data.raw` type names are wrong or that the
   masks have no `layers` table.
2. Place a band tile as in task 2. An assembling machine over the tile shows a
   red preview, and you cannot place it. The same is true for a transport
   belt.
3. **You can place a rail across the tile.** If you cannot, a rail type got
   into `BLOCKED_TYPES` by mistake.
4. **You can still walk and drive across the tile.**
5. Put an underground belt on the cell at each side of the band, so that it
   spans the band. The pair connects.
6. Stamp a blueprint over a band. The game places entities on the cells and
   **skips** the band tiles without a message. No ghosts remain on the band.

- [ ] **Step 3: Commit**

```bash
git add prototypes/patch.lua
git commit -m "feat(mod): give buildable structures the band collision layer"
```

---

### Task 5: Geometry for each surface

**Files:**

- Create: `mod/surface.lua`

**Interfaces:**

- Consumes: `mod/config.lua`, `mod/planets.lua`
- Produces:
  - `Surface.get(surface) -> geometry|nil`: nil for surfaces that this mod
    ignores
  - `Surface.init(surface) -> geometry|nil`: derives and stores the geometry
    once
  - `Surface.is_tiled(surface) -> boolean`
  - the geometry is `{ size, band, unit, depth, half, tile, mirror_tile }`

- [ ] **Step 1: Write the implementation**

`mod/surface.lua`:

```lua
-- Per-surface geometry, stored once at creation.
--
-- Startup settings can change between sessions. Storing the numbers the
-- terrain was actually built with means a later change affects only NEW
-- surfaces; existing ones keep their geometry and never seam. This is the one
-- idea worth taking from Hextorio's continuous_geometry flag.

local Config = require("mod.config")
local planets = require("mod.planets")

local Surface = {}

local function planet_of(surface)
  -- Space platforms are never tiled; only named planets we have a palette for.
  if surface.platform then return nil end
  return planets[surface.name] and surface.name or nil
end

function Surface.is_tiled(surface)
  return planet_of(surface) ~= nil
end

function Surface.init(surface)
  local planet = planet_of(surface)
  if not planet then return nil end

  storage.surfaces = storage.surfaces or {}
  local existing = storage.surfaces[surface.index]
  if existing then return existing end

  local s = settings.startup["hattorio-hat-size-" .. planet]
  local b = settings.startup["hattorio-band-width-" .. planet]
  local g = Config.geometry(s and s.value or Config.DEFAULT_SIZE,
                            b and b.value or Config.DEFAULT_BAND)
  g.tile = "hattorio-band-" .. planet
  g.mirror_tile = "hattorio-band-" .. planet .. "-mirror"

  storage.surfaces[surface.index] = g
  return g
end

function Surface.get(surface)
  storage.surfaces = storage.surfaces or {}
  return storage.surfaces[surface.index] or Surface.init(surface)
end

return Surface
```

- [ ] **Step 2: In-game check**

1. Start a new game. `/c game.print(serpent.line(storage.surfaces))` shows an
   entry for Nauvis with `size = 41`, `band = 3` and a `depth`.
2. Quit, change the cell size setting to 26 and load the **same save** again.
   `storage.surfaces` still shows 41, because existing surfaces keep their
   geometry.
3. Create a new surface (or a new game). It shows 26.

- [ ] **Step 3: Commit**

```bash
git add mod/surface.lua
git commit -m "feat(mod): per-surface geometry stored at creation"
```

---

### Task 6: Band rasterisation

This is the hot path. It is also the one part of the mod logic that we can
test fully.

**Files:**

- Create: `mod/bands.lua`
- Test: `spec/bands_spec.lua`

**Interfaces:**

- Consumes: `hat/tiling.lua`, `hat/geometry.lua`
- Produces:
  - `Bands.for_area(tiling, geom, area) -> { {x=,y=,mirror=<boolean>}, ... }`,
    where `area = { left=, top=, right=, bottom= }` is in tile coordinates.
    The result lists every band tile in the area.

- [ ] **Step 1: Write the failing test**

`spec/bands_spec.lua`:

```lua
local Ti = require("hat.tiling")
local Config = require("mod.config")
local Bands = require("mod.bands")

local function setup(size, band)
  local g = Config.geometry(size, band)
  local t = Ti.new({ unit = g.unit, depth = g.depth })
  return t, g
end

describe("band rasterisation", function()
  it("returns band tiles inside the requested area only", function()
    local t, g = setup(26, 2)
    local area = { left = -40, top = -40, right = 40, bottom = 40 }
    local tiles = Bands.for_area(t, g, area)
    assert.is_true(#tiles > 0)
    for _, p in ipairs(tiles) do
      assert.is_true(p.x >= area.left and p.x < area.right, "x " .. p.x)
      assert.is_true(p.y >= area.top and p.y < area.bottom, "y " .. p.y)
    end
  end)

  it("covers a plausible fraction of the area", function()
    -- measured ~22% at 26/2; allow a wide band around it
    local t, g = setup(26, 2)
    local area = { left = -64, top = -64, right = 64, bottom = 64 }
    local n = #Bands.for_area(t, g, area)
    local frac = n / (128 * 128)
    assert.is_true(frac > 0.10 and frac < 0.40, "fraction " .. frac)
  end)

  it("marks some tiles as mirror and most not", function()
    local t, g = setup(26, 2)
    local tiles = Bands.for_area(t, g, { left=-96, top=-96, right=96, bottom=96 })
    local m = 0
    for _, p in ipairs(tiles) do if p.mirror then m = m + 1 end end
    assert.is_true(m > 0, "no mirror tiles")
    assert.is_true(m < #tiles / 2, "too many mirror tiles")
  end)

  it("is deterministic", function()
    local t, g = setup(26, 2)
    local a = { left = 0, top = 0, right = 32, bottom = 32 }
    local one = Bands.for_area(t, g, a)
    local two = Bands.for_area(t, g, a)
    assert.are.equal(#one, #two)
    for i = 1, #one do
      assert.are.equal(one[i].x, two[i].x)
      assert.are.equal(one[i].y, two[i].y)
      assert.are.equal(one[i].mirror, two[i].mirror)
    end
  end)

  it("agrees across a chunk boundary", function()
    -- a band must not break where two chunks meet: each chunk derives its
    -- tiles from the tiling, never from its neighbour
    local t, g = setup(26, 2)
    local left  = Bands.for_area(t, g, { left = -32, top = 0, right = 0,  bottom = 32 })
    local right = Bands.for_area(t, g, { left = 0,   top = 0, right = 32, bottom = 32 })
    local both  = Bands.for_area(t, g, { left = -32, top = 0, right = 32, bottom = 32 })
    assert.are.equal(#left + #right, #both)
  end)

  it("makes a wider band cover more tiles", function()
    local t1, g1 = setup(26, 1)
    local t3, g3 = setup(26, 3)
    local a = { left = -48, top = -48, right = 48, bottom = 48 }
    assert.is_true(#Bands.for_area(t3, g3, a) > #Bands.for_area(t1, g1, a))
  end)
end)
```

- [ ] **Step 2: Run the test and check that it fails**

Run: `make test`
Expected: FAIL, `module 'mod.bands' not found`

- [ ] **Step 3: Implement**

`mod/bands.lua`:

```lua
-- Which tiles of an area fall on a band.
--
-- Pure: no Factorio API, so this runs in CI. A tile is a band tile when its
-- centre is within half the band width of any hat edge. Working from edges
-- rather than from polygon interiors is about an order of magnitude cheaper
-- and computes exactly the quantity wanted.
--
-- Mirror marking: a reflected hat paints all of its own edges in the mirror
-- variant, and where a reflected and an unreflected hat share an edge the
-- reflected one wins. That tie-break is deterministic, which matters.

local G = require("hat.geometry")

local Bands = {}

function Bands.for_area(tiling, geom, area)
  local unit, half = geom.unit, geom.half
  local pad = geom.band + 2

  local hats = tiling:hats_in_box({
    left = area.left - pad, top = area.top - pad,
    right = area.right + pad, bottom = area.bottom + pad,
  })

  -- cache edges once per hat rather than per tile
  local edges, mirrored = {}, {}
  for i = 1, #hats do
    edges[i] = G.edges(hats[i].xf, unit)
    mirrored[i] = hats[i].reflected
  end

  local out = {}
  for ty = area.top, area.bottom - 1 do
    for tx = area.left, area.right - 1 do
      local px, py = tx + 0.5, ty + 0.5
      local hit, mirror = false, false
      for i = 1, #edges do
        local e = edges[i]
        for j = 1, #e do
          local s = e[j]
          if G.dist_to_segment(px, py, s[1], s[2], s[3], s[4]) < half then
            hit = true
            if mirrored[i] then mirror = true end
            break
          end
        end
        if hit and mirror then break end
      end
      if hit then
        out[#out + 1] = { x = tx, y = ty, mirror = mirror }
      end
    end
  end
  return out
end

return Bands
```

- [ ] **Step 4: Run the test and check that it passes**

Run: `make test`
Expected: all green, 6 new successes.

- [ ] **Step 5: Commit**

```bash
git add mod/bands.lua spec/bands_spec.lua
git commit -m "feat(mod): band rasterisation, pure and tested"
```

---

### Task 7: Paint terrain at chunk generation

**Files:**

- Create: `mod/terrain.lua`

**Interfaces:**

- Consumes: `mod/surface.lua`, `mod/bands.lua`, `hat/tiling.lua`
- Produces: an `on_chunk_generated` handler that paints bands

- [ ] **Step 1: Write the handler**

`mod/terrain.lua`:

```lua
local Ti = require("hat.tiling")
local Surface = require("mod.surface")
local Bands = require("mod.bands")

-- Tilings are derived from stored geometry, so they are rebuilt on load
-- rather than persisted. Keyed by surface index.
local tilings = {}

local function tiling_for(surface)
  local g = Surface.get(surface)
  if not g then return nil end
  local t = tilings[surface.index]
  if not t then
    t = Ti.new({ unit = g.unit, depth = g.depth })
    tilings[surface.index] = t
  end
  return t, g
end

-- Tiles we must not pave over. Water keeps its vanilla shores; painting a
-- band across a lake would fill it.
local function is_paveable(surface, x, y)
  return not surface.get_tile(x, y).collides_with("water_tile")
end

local function paint_chunk(surface, area)
  local t, g = tiling_for(surface)
  if not t then return end

  local band = Bands.for_area(t, g, area)
  if #band == 0 then return end

  local tiles = {}
  for i = 1, #band do
    local p = band[i]
    if is_paveable(surface, p.x, p.y) then
      tiles[#tiles + 1] = {
        name = p.mirror and g.mirror_tile or g.tile,
        position = { p.x, p.y },
      }
    end
  end
  if #tiles == 0 then return end

  -- remove_colliding_entities = false: ore, trees and rocks already placed on
  -- a band stay. Ore there is simply unreachable by a 3x3 drill, which the
  -- richness multiplier compensates for.
  surface.set_tiles(tiles, true, false, false, false)
end

script.on_event(defines.events.on_chunk_generated, function(event)
  paint_chunk(event.surface, {
    left = event.area.left_top.x, top = event.area.left_top.y,
    right = event.area.right_bottom.x, bottom = event.area.right_bottom.y,
  })
end)

script.on_event(defines.events.on_surface_created, function(event)
  Surface.init(game.surfaces[event.surface_index])
end)

script.on_configuration_changed(function()
  tilings = {}
end)

script.on_load(function()
  tilings = {}
end)
```

- [ ] **Step 2: In-game check (the core deliverable)**

Start a **new** game on Nauvis and check these points:

1. The terrain generates with visible hat cells and dark bands between them.
2. **Bands do not break at chunk boundaries.** Walk along a band across
   several chunks. Any break means that state from a single chunk got into
   the calculation.
3. **Lakes stay.** The mod paints no band across water, and the shores look
   normal.
4. Bands cut through ore patches, but the patches keep their ore.
5. This command returns a plausible count:
   `/c game.print(game.surfaces[1].count_tiles_filtered{name="hattorio-band-nauvis"})`
6. Open the map view. You can see the aperiodic structure, and it clearly
   does not repeat.

- [ ] **Step 3: Measure the UPS cost**

While the game runs, enter this command:

```text
/c local t=game.create_profiler() game.player.force.chart(game.surfaces[1], {{-512,-512},{512,512}}) t.stop() game.print(t)
```

Then check that chunk generation does not visibly stall. The descent alone
took 0.73 ms per chunk in measurement. Rasterisation adds to that.

If generation is visibly slow, the probable cause is that `is_paveable` calls
`get_tile` for each tile. Get all the tiles of the chunk in one call and
cache them.

- [ ] **Step 4: Commit**

```bash
git add mod/terrain.lua
git commit -m "feat(mod): paint bands at chunk generation"
```

---

### Task 8: Compensate resource richness

**Files:**

- Modify: `mod/terrain.lua`

**Interfaces:**

- Consumes: `Config.richness_multiplier`

- [ ] **Step 1: Add the handler**

Add this to the end of `mod/terrain.lua`:

```lua
local Config = require("mod.config")

-- Bands cost ore twice: the tiles they occupy, and the clearance a 3x3 drill
-- needs near an edge. Raise what remains so effective yield stays near
-- vanilla. Applied per chunk as it generates, so it never touches ore a
-- player has already mined.
local function compensate_resources(surface, area)
  local g = Surface.get(surface)
  if not g then return end
  local mult = Config.richness_multiplier(g.size, g.band)
  if mult <= 1.0 then return end

  local found = surface.find_entities_filtered({
    area = { { area.left, area.top }, { area.right, area.bottom } },
    type = "resource",
  })
  for i = 1, #found do
    local e = found[i]
    if e.valid and e.prototype.infinite_resource ~= true then
      e.amount = math.floor(e.amount * mult)
    end
  end
end
```

Then call it from the `on_chunk_generated` handler, after `paint_chunk`:

```lua
  compensate_resources(event.surface, {
    left = event.area.left_top.x, top = event.area.left_top.y,
    right = event.area.right_bottom.x, bottom = event.area.right_bottom.y,
  })
```

- [ ] **Step 2: In-game check**

1. Start a new game at the default settings (41/3). Hover over an iron patch
   and note the amount per tile.
2. Start a new game with the mod disabled and the same map seed. At this
   setting, the vanilla amount should be about `0.61` of the modded amount
   (the drillable fraction for 41/3 in `Config.CELL_STATS`).
3. The mod does **not** multiply infinite resources (crude oil). Their yield
   is a percentage, and it would be wrong to scale it.

- [ ] **Step 3: Commit**

```bash
git add mod/terrain.lua
git commit -m "feat(mod): raise resource richness to offset band losses"
```

---

### Task 9: Thumbnail and mod packaging

**Files:**

- Create: `thumbnail.png`, `tools/package.sh`
- Modify: `Makefile`

- [ ] **Step 1: Generate the thumbnail with the renderer**

```bash
lua5.2 tools/render.lua 4 9 72 /tmp/thumb.svg
rsvg-convert -w 144 -h 144 /tmp/thumb.svg -o thumbnail.png
python3 -c "
from PIL import Image
im = Image.open('thumbnail.png')
assert im.size == (144, 144), im.size
print('thumbnail ok', im.size)"
```

- [ ] **Step 2: Write the packaging script**

`tools/package.sh`:

```bash
#!/bin/sh
# Build a mod zip Factorio will accept: the archive must contain a single
# directory named <name>_<version> holding info.json at its root.
set -e
NAME=$(python3 -c "import json;print(json.load(open('info.json'))['name'])")
VER=$(python3 -c "import json;print(json.load(open('info.json'))['version'])")
DIR="${NAME}_${VER}"
rm -rf "build/$DIR" "build/$DIR.zip"
mkdir -p "build/$DIR"
for p in info.json changelog.txt thumbnail.png data.lua data-final-fixes.lua \
         settings.lua control.lua LICENSE THIRD_PARTY.md \
         prototypes mod hat data locale; do
  cp -r "$p" "build/$DIR/"
done
cd build && zip -qr "$DIR.zip" "$DIR"
echo "built build/$DIR.zip"
```

Some things are left out on purpose: `tools/`, `spec/`, `docs/`, `wiki/` and
the `.github` directory never ship.

- [ ] **Step 3: Add it to the Makefile**

```makefile
## build the distributable mod zip
package:
	sh tools/package.sh
```

Also add `package` to `.PHONY`.

- [ ] **Step 4: Verify the structure of the archive**

```bash
make package
python3 -c "
import zipfile, json
z = zipfile.ZipFile('build/hattorio_0.1.0.zip')
names = z.namelist()
assert any(n.endswith('hattorio_0.1.0/info.json') for n in names), 'info.json misplaced'
assert not any('/spec/' in n or '/docs/' in n or '/tools/' in n for n in names), 'dev files shipped'
print('archive ok,', len(names), 'entries')"
```

- [ ] **Step 5: Commit**

```bash
git add thumbnail.png tools/package.sh Makefile
git commit -m "feat(mod): thumbnail and distributable zip"
```

---

### Task 10: Multiplayer determinism check [DEFERRED]

> **We deferred this on purpose. We did not forget it.** The check needs a
> second machine, and if possible a second operating system. That is the
> whole point of the check, because the risk it tests is a difference between
> platforms. It blocks the *release*, not the code. Until the check is done,
> the mod is marked as single player only.

The determinism argument in the spec comes from first principles: correctly
rounded IEEE operations, no `sin`/`cos`/`pow`, and one VM instruction per
operation. Nobody has confirmed it by experiment yet. A desync is the one bug
that we cannot ignore.

**Files:**

- Create: `docs/design/desync-check.md`

- [ ] **Step 1: Run the check**

1. Host a multiplayer game with the mod, on a machine that generates terrain.
2. Join from a second machine. If possible, use a **different OS**, because
   the risk under test is a difference in libm and floating point between
   platforms.
3. Both players travel outwards in different directions for several minutes,
   so that each client generates new chunks.
4. Check that no desync occurs, and that both clients show the same terrain
   at the same coordinates.

If a desync occurs, save the report. Then look first for any `math.sin`,
`math.cos`, `math.random` or `^` that got into shipped Lua. The invariant test
in `spec/invariants_spec.lua` searches for exactly these.

- [ ] **Step 2: Record the result**

Write `docs/design/desync-check.md`. Give what you tested (the two platforms,
the Factorio version, how long and how far) and the result. If a claim of
determinism has no evidence, record it as a claim with no evidence.

- [ ] **Step 3: Commit**

```bash
git add docs/design/desync-check.md
git commit -m "docs: record the multiplayer determinism check"
```

---

## Deferred on purpose

This plan does not implement two items from the spec. The reasons must be on
record, not only in someone's head.

**The optional crisp outline** (design section 10). The spec allows a
`draw_line` overlay with sub-tile precision down the centre of each band, with
a runtime toggle. The band tiles already make the structure easy to read, and
at the smallest cell sizes the overlay costs up to about 19k render objects on
the screen. YAGNI: ship without it, and add it if anyone asks.

**No grace area at spawn** (design section 16 left this open). At the default
41/3, the spawn cell holds about 858 buildable tiles. That is easily enough
for a burner start. Bands are walkable, so everything is reachable before
underground belts arrive. A grace area would also weaken the premise exactly
where a new player forms an impression of the mod. Decision: no grace area.
Look at this again first after playtests. Until then, the
`hattorio-hat-size-*` setting is the escape hatch.

**For now, the band graphics for each planet change only the colour.** Task 2
copies a vanilla tile and changes `map_color`. So the bands look different on
the map view, but they have the same graphics in the world on every planet.
Real art for each planet is a later job. The design asks for a "per-planet
tinted" look, and this meets only half of it. Task 2 says so.

## Verification

After task 10:

```bash
make check          # Python + Lua tests + luacheck
make package        # builds build/hattorio_0.1.0.zip
```

Also do the in-game checklists in tasks 2, 4, 5, 7, 8 and 10. A green test
suite does not replace any of them.

## Notes for the executor

- **`hat/` is finished. Do not change it.** If the mod seems to need a change
  there, the mod is probably reaching past its interface.
- **The game blocks construction natively, not a script.** If you start to add
  `on_built_entity` to reject placements, the collision layer does not work.
  Fix the layer. Rejection in a script places the entity and then removes it.
  That looks worse, and it leaves ghosts that bots try to build again.
- **Never paint over water.** `is_paveable` exists for this reason.
- **Bands must be continuous across chunk boundaries.** Every chunk derives
  its bands from the tiling, never from the tiles of a neighbouring chunk.
