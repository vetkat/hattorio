-- Terrain generation: paint the bands into each chunk when it generates.
--
-- The mod paints once, at generation, so there is no cost per tick. The save
-- keeps only the tiles and the geometry for each surface. The mod derives
-- the tiling from that geometry and builds it again on load.

local Ti = require("hat.tiling")
local Surface = require("mod.surface")
local Bands = require("mod.bands")
local Outline = require("mod.outline")
local Water = require("mod.water_band")

-- Derived state, keyed by the geometry table. It is deliberately NOT in
-- storage. The mod can build it again from the stored geometry, and a tiling
-- holds closures. All surfaces of one planet share one geometry, so they
-- share one tiling. The keys are weak, so the tiling of a deleted surface
-- goes away with its geometry.
local tilings = setmetatable({}, { __mode = "k" })

local function tiling_for(surface)
  local g = Surface.get(surface)
  if not g then return nil, nil end
  local t = tilings[g]
  if not t then
    t = Ti.new({ unit = g.unit, depth = g.depth })
    tilings[g] = t
  end
  return t, g
end

local function area_of(event_area)
  return {
    left = event_area.left_top.x, top = event_area.left_top.y,
    right = event_area.right_bottom.x, bottom = event_area.right_bottom.y,
  }
end

-- What a band position gets, for each tile name. Land gets the band tile
-- (true). Water gets its band copy (the copy's name, issue #21). A tile such
-- as out-of-map stays as it is (false). Prototypes do not change while the
-- game runs, so the answer is the same for the whole session.
local band_target = {}

local function target_for(name)
  local target = band_target[name]
  if target == nil then
    local layers = prototypes.tile[name].collision_mask.layers
    local copy = Water.copy_name(name)
    if not layers.water_tile then
      target = true
    elseif Water.is_water(layers) and prototypes.tile[copy] then
      target = copy
    else
      target = false
    end
    band_target[name] = target
  end
  return target
end

--- Paint the band tiles of one chunk.
local function paint_chunk(surface, area)
  local t, g = tiling_for(surface)
  if not t then return end

  local band = Bands.for_area(t, g, area)
  if #band == 0 then return end

  local tiles = {}
  for i = 1, #band do
    local p = band[i]
    -- Never pave water. A band across a lake would fill it, and the vanilla
    -- shore transitions would be lost. Water gets its band copy instead,
    -- which looks the same and has the band layer (issue #21). A tile with
    -- no copy, such as out-of-map, stays as it is.
    --
    -- Factorio's LuaObject methods use dot notation and take no self. So this
    -- is surface.get_tile(x, y). If you cache the function and pass
    -- `surface`, the surface goes where x belongs, and no error appears.
    local target = target_for(surface.get_tile(p.x, p.y).name)
    if target == true then
      target = p.mirror and g.mirror_tile or g.tile
    end
    if target then
      tiles[#tiles + 1] = { name = target, position = { p.x, p.y } }
    end
  end
  if #tiles == 0 then return end

  -- remove_colliding_entities = false: ore, trees and rocks that are already
  -- on a band stay where they are. Ore on a band is out of the reach of a 3x3
  -- drill, and the richness multiplier compensates for it.
  surface.set_tiles(tiles, true, false, false, false)
end

--- Raise ore richness to offset the ore that the bands put out of reach.
--
-- The mod applies this to each chunk when it generates, so it never changes
-- ore that a player has already mined. It skips infinite resources: their
-- yield is a percentage, and it would be wrong to scale it.
local function compensate_resources(surface, area)
  local g = Surface.get(surface)
  if not g then return end
  local mult = Surface.richness(g)
  if mult == 1.0 then return end

  local found = surface.find_entities_filtered({
    area = { { area.left, area.top }, { area.right, area.bottom } },
    type = "resource",
  })
  for i = 1, #found do
    local e = found[i]
    if e.valid and not e.prototype.infinite_resource then
      e.amount = math.floor(e.amount * mult)
    end
  end
end

-- The chunks that received a copy of a tiled chunk in this tick.
--
-- A mod can fill a new chunk of one surface with a copy of the same chunk of
-- another surface (`LuaSurface.clone_area`). A mod that gives each team a
-- copy of a planet does this. The copy already has the bands and the raised
-- ore. If this mod handled the chunk again, it would raise the ore a second
-- time.
--
-- The copy and the chunk event are in the same tick, and the order of the
-- two depends on the order in which the game loads the mods. If the chunk
-- event is first, the copy replaces what this mod did. If the copy is first,
-- this record tells the chunk event to leave the chunk alone. The record is
-- in `storage`, so that every client has the same one.
local function chunk_key(surface, position)
  return surface.index .. ":" .. position.x .. ":" .. position.y
end

local function same_area(a, b)
  return a.left_top.x == b.left_top.x and a.left_top.y == b.left_top.y
    and a.right_bottom.x == b.right_bottom.x
    and a.right_bottom.y == b.right_bottom.y
end

local function on_area_cloned(event)
  if not (event.clone_tiles and event.clone_entities) then return end
  -- The cells depend on the position. So the copy has the correct bands only
  -- if it is at the same position, on a surface with the same geometry.
  if not same_area(event.source_area, event.destination_area) then return end
  local destination = event.destination_surface
  local g, source = Surface.get(destination), Surface.get(event.source_surface)
  if not (g and source) then return end
  if g.planet ~= source.planet or g.size ~= source.size or g.band ~= source.band then
    return
  end

  local copied = storage.copied
  if not copied or copied.tick ~= event.tick then
    copied = { tick = event.tick, chunks = {} }
    storage.copied = copied
  end
  -- Every chunk that the area covers completely.
  local lt, rb = event.destination_area.left_top, event.destination_area.right_bottom
  for cy = math.ceil(lt.y / 32), math.floor(rb.y / 32) - 1 do
    for cx = math.ceil(lt.x / 32), math.floor(rb.x / 32) - 1 do
      copied.chunks[chunk_key(destination, { x = cx, y = cy })] = true
    end
  end
end

local function is_copy(event)
  local copied = storage.copied
  if not copied then return false end
  if copied.tick ~= event.tick then
    -- The record is for one tick only. Drop it, so the save does not keep it.
    storage.copied = nil
    return false
  end
  return copied.chunks[chunk_key(event.surface, event.position)] == true
end

local function on_chunk_generated(event)
  if not Surface.is_tiled(event.surface) then return end
  if is_copy(event) then return end
  local area = area_of(event.area)
  paint_chunk(event.surface, area)
  compensate_resources(event.surface, area)
end

script.on_event(defines.events.on_area_cloned, on_area_cloned)
script.on_event(defines.events.on_chunk_generated, on_chunk_generated)

script.on_event(defines.events.on_surface_created, function(event)
  local surface = game.surfaces[event.surface_index]
  if surface then Surface.init(surface) end
end)

-- The game can give the index of a deleted surface to a new one, so nothing
-- that the mod keeps for the index may stay. The tiling caches use the
-- geometry as the key, so they need no cleanup here.
script.on_event(defines.events.on_surface_deleted, function(event)
  Surface.forget(event.surface_index)
end)

script.on_nth_tick(30, function()
  for _, player in pairs(game.connected_players) do
    Outline.refresh(player)
  end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "hattorio-show-outline" and event.player_index then
    Outline.clear(event.player_index)
  end
end)

script.on_event(defines.events.on_player_changed_surface, function(event)
  Outline.clear(event.player_index)
end)

-- Derived state only. The mod builds it again when it next needs it.
script.on_load(function()
  tilings = setmetatable({}, { __mode = "k" })
  Outline.reset()
end)

--- Warn when a player adds the mod to a world that already has terrain.
--
-- The mod paints bands when chunks generate, so chunks that already existed
-- keep their vanilla terrain for ever. The result is a hard, permanent line
-- between the old area and everything explored after it. Only a new map can
-- fix that. So the mod at least says so, and the player knows it from the
-- start.
local function warn_if_added_mid_save(data)
  local change = data and data.mod_changes and data.mod_changes["hattorio"]
  if not (change and change.old_version == nil) then return end

  for _, surface in pairs(game.surfaces) do
    if Surface.is_tiled(surface) then
      -- is_chunk_generated on the origin is a cheap test for "somebody has
      -- played this world". A new surface has no generated chunks yet.
      if surface.is_chunk_generated({ 0, 0 }) then
        game.print("[Hattorio] Added to a world that already has terrain. " ..
          "Existing chunks keep their vanilla ground and will never grow " ..
          "cells, so there will be a permanent boundary where you have " ..
          "already explored. For the intended experience, start a new world.")
        return
      end
    end
  end
end

script.on_configuration_changed(function(data)
  tilings = setmetatable({}, { __mode = "k" })
  Outline.reset()
  warn_if_added_mid_save(data)
end)

-- For the in-game tests, which call the chunk handler directly.
return { on_chunk_generated = on_chunk_generated }
