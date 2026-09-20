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

-- The size and band dropdowns hold strings, as Factorio requires for
-- allowed_values. Convert here, at the single point where settings are read.
local function read_number_setting(name, default)
  local s = settings.startup[name]
  if s == nil then return default end
  return tonumber(s.value) or default
end

--- Derive and store this surface's geometry. Idempotent.
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

  -- Some combinations the dropdowns allow leave almost nothing buildable.
  -- At cell size 15 with a band of 4 a cell holds 46 tiles and its largest
  -- universal square is 4x4 -- a mining drill and an assembling machine are
  -- both 3x3, so there is no room to connect anything. Say so once rather
  -- than let it be discovered an hour in.
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

--- The ore richness multiplier in force for a surface, and where it came from.
--
-- Shared by terrain generation and the /hattorio-info command so the number a
-- player is shown is the number actually applied, not a second derivation of
-- it that could drift.
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
