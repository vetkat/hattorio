-- The bands that the game paints must be the bands that the pure code in
-- mod/bands.lua calculates. The busted suite tests that code under plain
-- Lua. These tests check the part that only the game can run: the chunk
-- event, the tile prototypes and set_tiles.

local Ti = require("hat.tiling")
local Bands = require("mod.bands")
local Surface = require("mod.surface")
local Water = require("mod.water_band")

-- The chunk at chunk position (cx, cy), as an area in tile coordinates.
local function chunk_area(cx, cy)
  return { left = cx * 32, top = cy * 32, right = cx * 32 + 32, bottom = cy * 32 + 32 }
end

-- Generate one new chunk, with lab tiles or without. The mod paints only
-- when a chunk generates, so a chunk that already exists proves nothing.
local function generate(surface, cx, cy, lab)
  assert(not surface.is_chunk_generated({ cx, cy }), "the chunk already exists")
  surface.generate_with_lab_tiles = lab or false
  surface.request_to_generate_chunks({ cx * 32 + 16, cy * 32 + 16 }, 0)
  surface.force_generate_chunk_requests()
  surface.generate_with_lab_tiles = false
end

-- The band positions of a chunk, each with the name of the band tile that
-- it must hold.
local function band_positions(surface, cx, cy)
  local g = Surface.get(surface)
  local tiling = Ti.new({ unit = g.unit, depth = g.depth })
  local band = Bands.for_area(tiling, g, chunk_area(cx, cy))
  for _, p in ipairs(band) do
    p.want = p.mirror and g.mirror_tile or g.tile
  end
  return band
end

-- The band positions of a chunk that hold the wrong tile. A band position
-- holds the band tile of the right variant, or the band copy of a water tile
-- (issue #21), or out-of-map. Also returns the number of band tiles.
local function wrong_tiles(surface, cx, cy)
  local wrong, painted = {}, 0
  for _, p in ipairs(band_positions(surface, cx, cy)) do
    local tile = surface.get_tile(p.x, p.y)
    if tile.name == p.want then
      painted = painted + 1
    elseif not Water.original(tile.name) and not tile.collides_with("out_of_map") then
      wrong[#wrong + 1] = string.format("(%d, %d) is %s, not %s", p.x, p.y, tile.name, p.want)
    end
  end
  return wrong, painted
end

-- Every band position holds its band tile, or the band copy of water.
-- Returns the number of band tiles.
local function check_chunk(surface, cx, cy)
  local wrong, painted = wrong_tiles(surface, cx, cy)
  assert(#wrong == 0, surface.name .. ": " .. table.concat(wrong, "; "))
  return painted
end

test("nauvis is tiled, and its band tiles exist", function()
  local nauvis = game.surfaces["nauvis"]
  assert(Surface.is_tiled(nauvis), "nauvis is not tiled")
  local g = Surface.get(nauvis)
  assert(prototypes.tile[g.tile], "no tile prototype " .. g.tile)
  assert(prototypes.tile[g.mirror_tile], "no tile prototype " .. g.mirror_tile)
end)

test("a new chunk on nauvis gets the calculated bands", function()
  local nauvis = game.surfaces["nauvis"]
  local settings = nauvis.map_gen_settings
  settings.autoplace_controls["water"] = { frequency = 1, size = 0, richness = 1 }
  nauvis.map_gen_settings = settings
  generate(nauvis, 70, -50)
  after_ticks(1, function()
    assert(check_chunk(nauvis, 70, -50) > 0, "the chunk has no band tiles")
  end)
end)

tags("space-age")
test("a new chunk on Vulcanus gets the calculated bands", function()
  local vulcanus = game.planets["vulcanus"].create_surface()
  assert(Surface.is_tiled(vulcanus), "vulcanus is not tiled")
  generate(vulcanus, 0, 0)
  after_ticks(1, function()
    assert(check_chunk(vulcanus, 0, 0) > 0, "the chunk has no band tiles")
  end)
end)

-- A surface in the map editor can generate lab tiles. Its new chunks get
-- bands like any other.
test("a new chunk with lab tiles gets the bands", function()
  local nauvis = game.surfaces["nauvis"]
  generate(nauvis, 90, -70, true)
  after_ticks(1, function()
    local area = chunk_area(90, -70)
    local lab = nauvis.count_tiles_filtered({
      area = { { area.left, area.top }, { area.right, area.bottom } },
      name = { "lab-dark-1", "lab-dark-2" },
    })
    assert(lab > 0, "the chunk has no lab tiles")
    assert(check_chunk(nauvis, 90, -70) > 0, "the chunk has no band tiles")
  end)
end)

-- Issue #19. On Aquilo, a few band positions at the edge of the ammonia
-- ocean stayed land. Each band position must hold a band tile, or the band
-- copy of the ocean (issue #21).
tags("space-age")
test("every band position on Aquilo holds a band tile or a band copy", function()
  -- The stamps reach across chunk borders, so the test needs many chunks
  -- side by side. Seed 1 had 15 wrong tiles in this area. The chunks generate
  -- one by one, as when a player explores.
  local aquilo = game.planets["aquilo"].create_surface()
  for cy = -4, 4 do
    for cx = -4, 4 do
      generate(aquilo, cx, cy)
    end
  end
  after_ticks(1, function()
    local wrong = {}
    for cy = -4, 4 do
      for cx = -4, 4 do
        for _, w in ipairs((wrong_tiles(aquilo, cx, cy))) do wrong[#wrong + 1] = w end
      end
    end
    assert(#wrong == 0,
      #wrong .. " band positions hold the wrong tile: " .. table.concat(wrong, "; "))
  end)
end)

-- A set-tile trigger effect must not replace a band tile. The crater of a
-- nuke is one in the base game. The land next to the band must still get the
-- crater, or the test would pass for the wrong reason.
test("a set-tile effect does not replace a band tile", function()
  local nauvis = game.surfaces["nauvis"]
  generate(nauvis, 110, -90)
  after_ticks(1, function()
    local band = band_positions(nauvis, 110, -90)
    local p = band[math.ceil(#band / 2)]
    nauvis.create_entity({ name = "nuke-effects-nauvis", position = { p.x + 0.5, p.y + 0.5 } })
    after_ticks(1, function()
      local wrong = wrong_tiles(nauvis, 110, -90)
      assert(#wrong == 0, #wrong .. " band tiles were replaced: " .. table.concat(wrong, "; "))
      local crater = nauvis.count_tiles_filtered({ position = { p.x, p.y }, radius = 12,
        name = "nuclear-ground" })
      assert(crater > 0, "the effect placed no crater, so the test proves nothing")
    end)
  end)
end)

-- Issue #21. A band position over water holds the band copy of the water, so
-- that landfill cannot open a gap. The test makes lakes common, and looks
-- for a chunk where a band crosses water.
test("a band position over water holds the band copy of the water", function()
  local nauvis = game.surfaces["nauvis"]
  local settings = nauvis.map_gen_settings
  local before = settings.autoplace_controls["water"]
  settings.autoplace_controls["water"] = { frequency = 6, size = 6, richness = 1 }
  nauvis.map_gen_settings = settings
  local found
  -- Restore the water setting even after an error, so that later tests do
  -- not run with frequent lakes.
  local ok, err = pcall(function()
    for i = 0, 19 do
      local cx, cy = 130 + i, -110
      generate(nauvis, cx, cy)
      for _, p in ipairs(band_positions(nauvis, cx, cy)) do
        local tile = nauvis.get_tile(p.x, p.y)
        if Water.is_water(tile.prototype.collision_mask.layers) then
          found = { cx = cx, cy = cy }
          break
        end
      end
      if found then break end
    end
  end)
  settings.autoplace_controls["water"] = before
  nauvis.map_gen_settings = settings
  assert(ok, err)
  assert(found, "no band crosses water in 20 chunks, so the test proves nothing")
  local wrong = wrong_tiles(nauvis, found.cx, found.cy)
  assert(#wrong == 0, table.concat(wrong, "; "))
end)

-- A set-tile stamp must not replace the band copy of the ammonia ocean. The
-- same stamp on plain ocean shows that the stamp works. Runs after the
-- Aquilo test above, which generates the surface.
tags("space-age")
test("a stamp does not replace the band copy of the ammonia ocean", function()
  local aquilo = game.surfaces["aquilo"]
  assert(aquilo, "no Aquilo surface: run this after the Aquilo test above")
  local area = { { -128, -128 }, { 160, 160 } }
  local copy = aquilo.find_tiles_filtered({
    area = area, name = Water.copy_name("ammoniacal-ocean"), limit = 1 })[1]
  local plain = aquilo.find_tiles_filtered({ area = area, name = "ammoniacal-ocean", limit = 1 })[1]
  assert(plain, "no plain ammonia ocean in the area, so the test proves nothing")
  assert(copy, "no band copy of the ammonia ocean in the area")
  for _, t in ipairs({ copy, plain }) do
    aquilo.create_entity({ name = "aquilo-tiles-inner-explosion",
      position = { t.position.x + 0.5, t.position.y + 0.5 } })
  end
  after_ticks(1, function()
    local kept = aquilo.get_tile(copy.position.x, copy.position.y).name
    local stamped = aquilo.get_tile(plain.position.x, plain.position.y).name
    assert(stamped ~= "ammoniacal-ocean", "the stamp did not change plain ocean either")
    assert(kept == Water.copy_name("ammoniacal-ocean"), "the stamp made the band copy " .. kept)
  end)
end)
