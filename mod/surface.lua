-- The geometry for each surface. The mod derives it once, when it creates the
-- surface, and stores it.
--
-- Startup settings can change between sessions. The mod stores the numbers
-- that the terrain was actually built with, so a later change affects only
-- NEW surfaces. Existing surfaces keep their geometry and never get a seam.
-- This is the one idea worth taking from the continuous_geometry flag in
-- Hextorio.

local Config = require("mod.config")
local planets = require("mod.planets")

local Surface = {}

--- The name of the planet palette for this surface, or nil if the surface
-- has no tiling.
local function planet_of(surface)
  -- Space platforms never get a tiling. Nor does any surface that has no
  -- palette. That includes planets from other mods, which fail open to
  -- vanilla terrain.
  if surface.platform then return nil end
  if planets[surface.name] then return surface.name end
  return nil
end

function Surface.is_tiled(surface)
  return planet_of(surface) ~= nil
end

-- The size and band dropdowns hold strings, because Factorio requires
-- strings for allowed_values. Convert them here, at the one place that reads
-- the settings.
local function read_number_setting(name, default)
  local s = settings.startup[name]
  if s == nil then return default end
  return tonumber(s.value) or default
end

--- Derive and store the geometry of this surface. Idempotent.
function Surface.init(surface)
  local planet = planet_of(surface)
  if not planet then return nil end

  storage.surfaces = storage.surfaces or {}
  local existing = storage.surfaces[surface.index]
  if existing then return existing end

  local g = Config.geometry(
    read_number_setting("hattorio-hat-size-" .. planet, Config.DEFAULT_SIZE),
    read_number_setting("hattorio-band-width-" .. planet, Config.DEFAULT_BAND))
  g.planet = planet
  g.tile = "hattorio-band-" .. planet
  g.mirror_tile = "hattorio-band-" .. planet .. "-mirror"

  storage.surfaces[surface.index] = g

  local mult, source = Surface.richness(g)
  log(string.format(
    "hattorio: %s initialised -- cell size %d, band %d, depth %d, " ..
    "ore richness x%.2f (%s)",
    planet, g.size, g.band, g.depth, mult, source))

  -- Some combinations that the dropdowns allow leave almost nothing
  -- buildable. At cell size 15 with band 4, a cell holds 46 tiles, and the
  -- largest square that fits every cell is 4x4. A mining drill and an
  -- assembling machine are both 3x3, so there is no room to connect anything.
  -- Say this once, so that the player knows it now and not an hour later.
  if Config.is_severe(g.size, g.band) then
    local stats = Config.cell_stats(g.size, g.band)
    log(string.format(
      "hattorio: WARNING %s uses cell size %d with band %d -- only %d " ..
      "buildable tiles per cell and a largest square of %dx%d. This is " ..
      "close to unplayable.", planet, g.size, g.band, stats.area,
      stats.square, stats.square))
    if game then
      game.print(string.format(
        "[Hattorio] Cell size %d with band %d leaves about %d buildable " ..
        "tiles per cell, and the largest blueprint that fits every cell is " ..
        "%dx%d. A mining drill is 3x3. Consider a larger cell size.",
        g.size, g.band, stats.area, stats.square, stats.square))
    end
  end

  return g
end

--- The ore richness multiplier that a surface uses, and where it came from.
--
-- Terrain generation and the /hattorio-info command both use this function.
-- So the number that the player sees is the number that the mod applies, and
-- not a second calculation that could drift.
--
-- @return multiplier, source  where source is "override" or "automatic"
function Surface.richness(g)
  local setting = settings.global["hattorio-richness-override"]
  local override = setting and setting.value or 0
  if override > 0 then
    return override, "override"
  end
  return Config.richness_multiplier(g.size, g.band), "automatic"
end

function Surface.get(surface)
  storage.surfaces = storage.surfaces or {}
  return storage.surfaces[surface.index] or Surface.init(surface)
end

return Surface
