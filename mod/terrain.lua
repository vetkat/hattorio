-- Terrain generation: paint the bands into each chunk when it generates.
--
-- The mod paints once, at generation, so there is no cost per tick. The save
-- keeps only the tiles and the geometry for each surface. The mod derives
-- the tiling from that geometry and builds it again on load.

local Ti = require("hat.tiling")
local Surface = require("mod.surface")
local Bands = require("mod.bands")
local Outline = require("mod.outline")

-- Derived state, keyed by surface index. It is deliberately NOT in storage.
-- The mod can build it again from the stored geometry, and a tiling holds
-- closures.
local tilings = {}

local function tiling_for(surface)
  local g = Surface.get(surface)
  if not g then return nil, nil end
  local t = tilings[surface.index]
  if not t then
    t = Ti.new({ unit = g.unit, depth = g.depth })
    tilings[surface.index] = t
  end
  return t, g
end

local function area_of(event_area)
  return {
    left = event_area.left_top.x, top = event_area.left_top.y,
    right = event_area.right_bottom.x, bottom = event_area.right_bottom.y,
  }
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
    -- shore transitions would be lost.
    --
    -- Factorio's LuaObject methods use dot notation and take no self. So this
    -- is surface.get_tile(x, y). If you cache the function and pass
    -- `surface`, the surface goes where x belongs, and no error appears.
    if not surface.get_tile(p.x, p.y).collides_with("water_tile") then
      tiles[#tiles + 1] = {
        name = p.mirror and g.mirror_tile or g.tile,
        position = { p.x, p.y },
      }
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

script.on_event(defines.events.on_chunk_generated, function(event)
  if not Surface.is_tiled(event.surface) then return end
  local area = area_of(event.area)
  paint_chunk(event.surface, area)
  compensate_resources(event.surface, area)
end)

script.on_event(defines.events.on_surface_created, function(event)
  local surface = game.surfaces[event.surface_index]
  if surface then Surface.init(surface) end
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
  tilings = {}
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
  tilings = {}
  Outline.reset()
  warn_if_added_mid_save(data)
end)
