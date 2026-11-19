-- Another mod can give a surface the tiling of a planet, through the remote
-- interface. A mod that gives each team a surface of its own does this. These
-- tests make such a surface by hand.

local Surface = require("mod.surface")
local Terrain = require("mod.terrain")

local CX, CY = 40, 40
local AREA = { left_top = { x = CX * 32, y = CY * 32 },
               right_bottom = { x = CX * 32 + 32, y = CY * 32 + 32 } }

local function generate(surface)
  surface.request_to_generate_chunks({ CX * 32 + 16, CY * 32 + 16 }, 0)
  surface.force_generate_chunk_requests()
end

local function band_tiles(surface)
  local g = Surface.get(surface)
  return surface.count_tiles_filtered({ area = AREA, name = { g.tile, g.mirror_tile } })
end

-- The total of the finite ore in the test chunk.
local function ore(surface)
  local sum = 0
  for _, e in pairs(surface.find_entities_filtered({ area = AREA, type = "resource" })) do
    if not e.prototype.infinite_resource then sum = sum + e.amount end
  end
  return sum
end

-- The chunk event of the test chunk, as the game sends it.
local function chunk_event(surface)
  return { surface = surface, position = { x = CX, y = CY }, area = AREA, tick = game.tick }
end

local function team_copy()
  local copy = game.surfaces["nauvis-of-team-1"]
  if not copy then
    copy = game.create_surface("nauvis-of-team-1", game.surfaces["nauvis"].map_gen_settings)
    assert(remote.call("hattorio", "set_surface_planet", copy.index, "nauvis"),
      "the interface refused the surface")
  end
  return copy
end

test("a surface gets the geometry of the planet that a mod gives it", function()
  local copy = team_copy()
  assert(Surface.is_tiled(copy), "the copy is not tiled")
  assert(Surface.get(copy) == Surface.get(game.surfaces["nauvis"]),
    "the copy has a geometry of its own")
  assert(remote.call("hattorio", "get_surface_planet", copy.name) == "nauvis")
end)

test("the interface has version 1", function()
  assert(remote.call("hattorio", "interface_version") == 1)
end)

-- A mod can make the call for a surface that has chunks already, for
-- example when a player adds this mod to a save. New chunks get bands, as on
-- a real planet in such a save.
test("the interface accepts a surface that has chunks already", function()
  local other = game.create_surface("a-surface-with-chunks")
  other.request_to_generate_chunks({ 0, 0 }, 0)
  other.force_generate_chunk_requests()
  assert(remote.call("hattorio", "set_surface_planet", other.index, "nauvis"),
    "the interface refused a surface with chunks")
  assert(Surface.is_tiled(other), "the surface is not tiled")
  game.delete_surface(other)
end)

test("a surface that no mod gave a planet is not tiled", function()
  local other = game.create_surface("another-surface")
  assert(not Surface.is_tiled(other), "the surface is tiled")
  assert(remote.call("hattorio", "get_surface_planet", other.index) == nil)
  game.delete_surface(other)
end)

test("the interface refuses a planet that the mod does not know", function()
  local other = game.create_surface("a-third-surface")
  assert(not remote.call("hattorio", "set_surface_planet", other.index, "pluto"))
  assert(not remote.call("hattorio", "set_surface_planet", "no-such-surface", "nauvis"))
  assert(not Surface.is_tiled(other), "the surface is tiled")
  game.delete_surface(other)
end)

-- The game deletes a surface at the end of the tick, and it can give the
-- index to the next new surface. That surface must start with nothing.
test("the mod forgets a deleted surface", function()
  local first = game.create_surface("a-short-lived-surface")
  local index = first.index
  assert(remote.call("hattorio", "set_surface_planet", index, "nauvis"))
  game.delete_surface(first)
  after_ticks(2, function()
    assert(game.get_surface(index) == nil, "the surface still exists")
    assert(not (storage.surfaces and storage.surfaces[index]), "the geometry stays")
    assert(not (storage.assigned and storage.assigned[index]), "the planet stays")
    local second = game.create_surface("the-next-surface")
    assert(not Surface.is_tiled(second),
      "a new surface is tiled, with index " .. second.index .. " after " .. index)
    game.delete_surface(second)
  end)
end)

test("a surface keeps the planet that it has", function()
  local copy = team_copy()
  assert(remote.call("hattorio", "set_surface_planet", copy.index, "nauvis"))
  assert(not remote.call("hattorio", "set_surface_planet", copy.index, "vulcanus"))
  assert(not remote.call("hattorio", "set_surface_planet", "nauvis", "vulcanus"))
  assert(remote.call("hattorio", "get_surface_planet", copy.index) == "nauvis")
end)

test("a new chunk on such a surface gets bands", function()
  local copy = team_copy()
  generate(copy)
  after_ticks(1, function()
    assert(band_tiles(copy) > 0, "the chunk has no band tiles")
  end)
end)

-- A mod can copy each chunk of nauvis to the same chunk of its own surface.
-- The copy has the bands and the raised ore already. The chunk event of the
-- same tick must not raise the ore again.
test("a chunk that is a copy of a nauvis chunk keeps its ore", function()
  local nauvis, copy = game.surfaces["nauvis"], team_copy()
  generate(nauvis)
  generate(copy)
  nauvis.create_entity({ name = "iron-ore", amount = 1000,
    position = { CX * 32 + 16.5, CY * 32 + 16.5 } })
  after_ticks(1, function()
    nauvis.clone_area({
      source_area = AREA, destination_area = AREA, destination_surface = copy,
      clone_tiles = true, clone_entities = true, clone_decoratives = true,
      expand_map = false,
    })
    local before = ore(copy)
    assert(before == ore(nauvis), "the copy does not have the ore of nauvis")
    assert(band_tiles(copy) == band_tiles(nauvis), "the copy does not have the bands of nauvis")

    Terrain.on_chunk_generated(chunk_event(copy))
    assert(ore(copy) == before, "the chunk event changed the ore of a copy")

    -- The record of the copy is for one tick. A chunk that generates later
    -- at the same position gets the usual work.
    after_ticks(1, function()
      Terrain.on_chunk_generated(chunk_event(copy))
      assert(ore(copy) > before, "the chunk event of a later tick did nothing")
    end)
  end)
end)
