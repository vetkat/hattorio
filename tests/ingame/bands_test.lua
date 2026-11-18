-- The bands that the game paints must be the bands that the pure code in
-- mod/bands.lua calculates. The busted suite tests that code under plain
-- Lua. These tests check the part that only the game can run: the chunk
-- event, the tile prototypes and set_tiles.

local Ti = require("hat.tiling")
local Bands = require("mod.bands")
local Surface = require("mod.surface")

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

-- Every band position holds the band tile of the right variant, or water,
-- which the mod never paves. Returns the number of band tiles.
local function check_chunk(surface, cx, cy)
  local g = Surface.get(surface)
  local tiling = Ti.new({ unit = g.unit, depth = g.depth })
  local painted = 0
  for _, p in ipairs(Bands.for_area(tiling, g, chunk_area(cx, cy))) do
    local tile = surface.get_tile(p.x, p.y)
    local want = p.mirror and g.mirror_tile or g.tile
    assert(tile.name == want, string.format(
      "%s (%d, %d) is %s, not %s", surface.name, p.x, p.y, tile.name, want))
    painted = painted + 1
  end
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
