-- Terrain generation: paint bands into each chunk as it is generated.
--
-- Painting once at generation means zero per-tick cost. Nothing about the
-- bands is persisted beyond the tiles themselves and the per-surface geometry:
-- the tiling is derived from that geometry and rebuilt on load.

local Ti = require("hat.tiling")
local Config = require("mod.config")
local Surface = require("mod.surface")
local Bands = require("mod.bands")
local Outline = require("mod.outline")

-- Derived state, keyed by surface index. Deliberately NOT in storage: it is
-- reconstructible from the stored geometry, and a tiling holds closures.
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
    -- Never pave water: a band across a lake would fill it, and vanilla
    -- shore transitions would be lost.
    --
    -- Factorio's LuaObject methods take dot notation and no self, so this is
    -- surface.get_tile(x, y) -- caching the function and passing `surface`
    -- would silently put the surface where x belongs.
    if not surface.get_tile(p.x, p.y).collides_with("water_tile") then
      tiles[#tiles + 1] = {
        name = p.mirror and g.mirror_tile or g.tile,
        position = { p.x, p.y },
      }
    end
  end
  if #tiles == 0 then return end

  -- remove_colliding_entities = false: ore, trees and rocks already placed on
  -- a band stay put. Ore there is simply out of reach of a 3x3 drill, which
  -- the richness multiplier compensates for.
  surface.set_tiles(tiles, true, false, false, false)
end

--- Raise ore richness to offset what the bands put out of reach.
--
-- Applied per chunk as it generates, so it never touches ore a player has
-- already mined. Infinite resources are skipped: their yield is a percentage,
-- and scaling that would be wrong.
local function compensate_resources(surface, area)
  local g = Surface.get(surface)
  if not g then return end
  -- A map setting of 0 means "compensate automatically"; anything else
  -- replaces the derived value outright.
  local override = settings.global["hattorio-richness-override"]
  local mult = override and override.value or 0
  if mult <= 0 then
    mult = Config.richness_multiplier(g.size, g.band)
  end
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

-- Derived state only; rebuilt lazily on next use.
script.on_load(function()
  tilings = {}
  Outline.reset()
end)

script.on_configuration_changed(function()
  tilings = {}
  Outline.reset()
end)
