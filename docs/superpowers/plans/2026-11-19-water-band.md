# Band Positions Over Water Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps
> use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every band position over water the band layer, so that
landfill and set-tile stamps cannot open a gap in a band (issue #21).

**Architecture:** At data stage, each water tile gets a copy that looks the
same and also has the band layer. The painter places that copy at band
positions over water. The existing floor-tile patch (1.0.2) and set-tile
mask (1.1.0) then refuse the copy with no new code.

**Tech Stack:** Factorio 2.1 Lua (data stage and control stage),
factorio-test for the in-game tests, `make check`.

**Spec:** `docs/superpowers/specs/2026-11-19-water-band-design.md`

## Global Constraints

- A water tile is a tile prototype whose collision mask has `water_tile`
  and does not have `out_of_map`.
- The copy of tile `<name>` has the name `hattorio-band-water-<name>`.
- The copy looks the same as the original. It changes no graphics, effect,
  colour or map colour.
- The copy keeps every collision layer of the original, keeps `fluid`, sets
  `transition_merges_with_tile = <name>`, has no `autoplace`, and has
  `can_be_part_of_blueprint = false`.
- The offshore pump stays blocked on the copy.
- Chunks that generated earlier stay as they are. No migration.
- Prose in British English, in the tone of `CLAUDE.md`. Each commit follows
  the workflow in `CLAUDE.md`: `/ste80-humanizer`, `/simplify`, `git add`,
  `make stamp`, `git commit`.

## Review Focus

- **A modded water tile that already merges with another tile** (base
  `deepwater` merges with `water`). The copy must merge with its own
  original, and the shore must still look right. Task 1 tests the merge
  target of every copy.
- **The tile prototype limit.** Factorio 1.1 allowed at most 255 tile
  prototypes. If 2.1 still has a limit, a large mod pack could pass it with
  the copies added. Task 1 checks the limit in the 2.1 docs first. If one
  exists, it stops adding copies below it, with a log line. The painter
  then skips a water tile without a copy, as today.
- **Lava and the oil oceans.** They have `water_tile` but are not water to
  a player. Foundation can go on them, so they need the copy too. Task 2
  checks lava on Vulcanus.
- **A band position over water in a chunk that already exists.** It keeps
  plain water. The in-game tests generate only new chunks, and the
  description says so.
- **Plain water left at a band position in a new chunk.** The tests must
  refuse it, not accept it as before. Task 2 changes `wrong_tiles`.

---

### Task 1: Band copies of the water tiles

**Files:**

- Create: `prototypes/water_band.lua`
- Change: `data-final-fixes.lua` (require the new file after
  `prototypes.patch`, before `prototypes.set_tile`)
- Change: `docs/design/hattorio-design.md` (§7 module table: one row)
- Test: `tests/ingame/collision_test.lua`

**Interfaces:**

- Produces: the tile prototypes `hattorio-band-water-<name>`, one per water
  tile. Task 2 finds a copy with
  `prototypes.tile["hattorio-band-water-" .. name]`.

- [ ] **Step 1: Write the failing tests** in `collision_test.lua`:

```lua
-- A water tile, as prototypes/water_band.lua selects it.
local function is_water(tile)
  local layers = tile.collision_mask.layers
  return layers.water_tile and not layers.out_of_map
end

test("every water tile has a band copy", function()
  local missing = {}
  for name, tile in pairs(prototypes.tile) do
    if is_water(tile) and not name:find("^hattorio%-") then
      local copy = prototypes.tile["hattorio-band-water-" .. name]
      if not copy then missing[#missing + 1] = name end
    end
  end
  table.sort(missing)
  assert(#missing == 0, "no band copy for: " .. table.concat(missing, ", "))
end)

test("a band copy keeps its water and adds the band layer", function()
  for name, copy in pairs(prototypes.tile) do
    local original = name:match("^hattorio%-band%-water%-(.+)$")
    if original then
      local src = prototypes.tile[original]
      assert(copy.collision_mask.layers[LAYER], name .. " has no band layer")
      for layer in pairs(src.collision_mask.layers) do
        assert(copy.collision_mask.layers[layer], name .. " lost " .. layer)
      end
      assert((copy.fluid and copy.fluid.name) == (src.fluid and src.fluid.name),
        name .. " has another fluid")
      assert(copy.map_color.r == src.map_color.r and copy.map_color.g == src.map_color.g
        and copy.map_color.b == src.map_color.b, name .. " has another map colour")
      assert(not copy.autoplace_specification, name .. " autoplaces")
    end
  end
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `tools/ingame.sh base`
Expected: FAIL in "every water tile has a band copy". The message names
`deepwater` and `water`, and others.

- [ ] **Step 3: Write `prototypes/water_band.lua`**

At data stage, loop over `data.raw.tile` and copy each water tile (the rule
in Global Constraints) with `table.deepcopy`. Apply the fields in Global
Constraints. Add each copy's name to the global `water_tile_type_names`, so
land tiles draw shores to it.

Check the 2.1 docs for a tile limit. If one exists, count the tiles in
`data.raw.tile` first. Add copies only while the total stays within the
limit. Log one line:
`hattorio: <n> water tiles get a band copy, <m> skipped at the tile limit`.
The file comment says why the copies exist (issue #21) and why they look
the same as the water (the owner's choice, design spec).

- [ ] **Step 4: Run the tests and see them pass**

Run: `tools/ingame.sh`
Expected: PASS in both modes. The existing test "no item can place a tile
on a band" also passes.

- [ ] **Step 5: Add the module table row** in §7:
`| \`prototypes/water_band.lua\` | band copies of the water tiles | data stage |`

- [ ] **Step 6: Commit** with the workflow in `CLAUDE.md`. Message:
`feat: add band copies of the water tiles`.

### Task 2: Paint the copies at band positions over water

**Files:**

- Change: `mod/terrain.lua` (`paint_chunk`)
- Change: `tests/ingame/bands_test.lua` (`wrong_tiles`, two new tests)
- Change: `docs/design/hattorio-design.md` (§8 "Do not fill water", §16)
- Change: `CHANGELOG.md` (Unreleased, Fixed)

**Interfaces:**

- Consumes: `prototypes.tile["hattorio-band-water-" .. name]` from Task 1.

- [ ] **Step 1: Change `wrong_tiles` and add the tests**

In `wrong_tiles`, a band position counts as right only if it holds
`p.want` or the copy of a water tile (`hattorio-band-water-*`). Plain
water is now wrong. Rename nothing else.

New tests:

```lua
test("a band position over water holds the band copy of the water", function()
  local nauvis = game.surfaces["nauvis"]
  local settings = nauvis.map_gen_settings
  settings.autoplace_controls["water"] = { frequency = 6, size = 6, richness = 1 }
  nauvis.map_gen_settings = settings
  -- generate chunks until one has a band position over water; at most 20
  -- assert that position holds "hattorio-band-water-<water name>"
  -- assert #wrong_tiles(...) == 0 for that chunk
end)

tags("space-age")
test("a stamp does not replace the band copy of the ammonia ocean", function()
  -- on aquilo, find a "hattorio-band-water-ammoniacal-ocean" tile in the
  -- 9x9 area of the existing Aquilo test
  -- create "aquilo-tiles-outer-explosion" on it
  -- after one tick: the tile is still the copy, and at least one tile within
  -- radius 6 that is not a band position is now snow-patchy or ice-rough
end)
```

Reset the Nauvis water control at the end of the first test to the value
it had before.

- [ ] **Step 2: Run the tests and see them fail**

Run: `tools/ingame.sh`
Expected: FAIL in the new Nauvis test (the position holds `water`), and in
the Aquilo 9x9 test (plain ammonia ocean at band positions).

- [ ] **Step 3: Change `paint_chunk`**

For a band position whose tile collides with `water_tile`, look up
`prototypes.tile["hattorio-band-water-" .. tile.name]`. If it exists,
place it. If not, skip the position, as before. Land positions keep the
band tile.

- [ ] **Step 4: Run the full checks**

Run: `make check`
Expected: exit 0. Both new tests pass in their modes. The Vulcanus test
passes with lava copies at band positions over lava.

- [ ] **Step 5: Docs**

- §8: replace "Do not fill water" with a new bullet. The mod keeps lakes as
  they are. It places the band copy of the water at band positions, so
  that landfill and stamps cannot open a gap.
- §16: one bullet: you cannot place an offshore pump on a band position
  over water, and chunks from before this version keep plain water there.
- `CHANGELOG.md`, Unreleased, Fixed: you could landfill a lake where a band
  crosses it and then build across the band. The band now continues under
  the water, and looks the same as the lake.

- [ ] **Step 6: Commit** with the workflow in `CLAUDE.md`. Message:
`fix: keep the band layer under water`.

- [ ] **Step 7: Clean up the spike**

Run: `git worktree remove --force <scratchpad>/spike/hattorio && git branch -D spike/water-band`
Expected: `git worktree list` shows only the main checkout.

- [ ] **Step 8: Push and open the PR**

Title: `fix: keep the band layer under water`. Body: the PR template,
`Closes #21`, the review angles with verdicts.
