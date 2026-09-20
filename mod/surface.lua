-- Per-surface geometry, derived once at creation and stored.
--
-- Startup settings can change between sessions. Storing the numbers the
-- terrain was actually built with means a later change affects only NEW
-- surfaces; existing ones keep their geometry and never seam. This is the one
-- idea worth taking from Hextorio's continuous_geometry flag.

local Config = require("mod.config")
local planets = require("mod.planets")

local Surface = {}

--- Name of the planet palette for this surface, or nil if it is not tiled.
local function planet_of(surface)
  -- Space platforms are never tiled, and neither is any surface we have no
  -- palette for -- including modded planets, which fail open to vanilla.
  if surface.platform then return nil end
  if planets[surface.name] then return surface.name end
  return nil
end

function Surface.is_tiled(surface)
  return planet_of(surface) ~= nil
end

local function read_setting(name, default)
  local s = settings.startup[name]
  if s == nil then return default end
  return s.value
end

--- Derive and store this surface's geometry. Idempotent.
function Surface.init(surface)
  local planet = planet_of(surface)
  if not planet then return nil end

  storage.surfaces = storage.surfaces or {}
  local existing = storage.surfaces[surface.index]
  if existing then return existing end

  local g = Config.geometry(
    read_setting("hattorio-hat-size-" .. planet, Config.DEFAULT_SIZE),
    read_setting("hattorio-band-width-" .. planet, Config.DEFAULT_BAND))
  g.planet = planet
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
