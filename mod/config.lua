-- Settings numbers in, geometry numbers out.
--
-- Pure: no Factorio API, so this runs under plain Lua in CI alongside hat/.
-- Everything that reads `settings` or `storage` lives in mod/surface.lua.

local Ti = require("hat.tiling")

local Config = {}

Config.MIN_SIZE, Config.MAX_SIZE = 15, 90
Config.MIN_BAND, Config.MAX_BAND = 1, 6
Config.DEFAULT_SIZE, Config.DEFAULT_BAND = 26, 2

-- A Factorio map is 2e6 x 2e6, so its half-diagonal is ~1.41e6. Ti:coverage()
-- is the CIRCUMRADIUS of a hexagonal root, and a square region inscribed in
-- that circle is not fully tiled -- its corners fall outside. So ask for
-- comfortably more than the half-diagonal, never the half-width.
Config.REQUIRED_COVER = 1.6e6

local function clamp1(v, lo, hi, default)
  if type(v) ~= "number" then return default end
  if v ~= v then return lo end                 -- x ~= x is the only NaN test
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Config.clamp(size, band)
  return clamp1(size, Config.MIN_SIZE, Config.MAX_SIZE, Config.DEFAULT_SIZE),
         clamp1(band, Config.MIN_BAND, Config.MAX_BAND, Config.DEFAULT_BAND)
end

--- Everything the mod needs to place cells, derived from two settings.
-- @return { size, band, unit, depth, half }
function Config.geometry(size, band)
  size, band = Config.clamp(size, band)
  local unit = Ti.unit_for_hat_size(size)
  local depth = Ti.depth_covering(unit, Config.REQUIRED_COVER)
  if not depth then
    error("hattorio: no emitted depth covers the map at cell size " .. size)
  end
  return { size = size, band = band, unit = unit, depth = depth, half = band / 2 }
end

--- Fraction of a cell's ore a 3x3 mining drill can actually reach.
--
-- Bands cost ore twice: the tiles they occupy, and the clearance a drill needs
-- near an edge. The loss turns out to be (1 - drillable) * size ~ constant for
-- a given band width, so the shortfall scales as band/size.
--
-- Fitted to rasterised measurements, worst error 3.8 percentage points:
--     size/band   measured   this formula
--        20/1       0.511       0.515
--        20/2       0.398       0.360
--        26/2       0.522       0.508
--        41/2       0.682       0.688
--        41/3       0.610       0.612
--        52/2       0.749       0.754
function Config.drillable_fraction(size, band)
  size, band = Config.clamp(size, band)
  local d = 1 - (3.1 * band + 6.6) / size
  if d < 0.2 then d = 0.2 end
  if d > 1.0 then d = 1.0 end
  return d
end

--- How much to raise ore richness to offset what bands make unreachable.
function Config.richness_multiplier(size, band)
  return 1 / Config.drillable_fraction(size, band)
end

return Config
