-- Render a patch of the hat tiling to SVG, straight from the Lua descent.
-- This exercises the shipped code path, not the offline pipeline.
--
--   lua5.2 tools/render.lua [depth] [unit] [half-extent] [out.svg]
--
-- Colours follow the usual presentation of this tiling: reflected hats (about
-- 1 in 8, unavoidable) in dark blue, the rest shaded by orientation.

package.path = "./?.lua;" .. package.path

local Ti = require("hat.tiling")
local G = require("hat.geometry")
local T = require("hat.transform")

local depth  = tonumber(arg[1]) or 4
local unit   = tonumber(arg[2]) or 12
local extent = tonumber(arg[3]) or 320
local out    = arg[4] or "tiling.svg"

local SHADES = { "#ffffff", "#8ecdf0", "#c9cdd2" }
local REFLECTED = "#1479c9"

local t = Ti.new({ unit = unit, depth = depth })
local box = { left = -extent, top = -extent, right = extent, bottom = extent }
local hats = t:hats_in_box(box)

-- orientation class from the linear part; atan2 is fine here, this is a dev
-- tool and never ships.
local function shade(h)
  if h.reflected then return REFLECTED end
  local ang = math.atan2(h.xf[4], h.xf[1])
  local sixth = math.floor((ang + math.pi * 2) / (math.pi / 3) + 0.5) % 6
  return SHADES[(sixth % #SHADES) + 1]
end

local f = assert(io.open(out, "w"))
f:write(string.format(
  '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
  .. 'viewBox="%d %d %d %d">\n',
  extent * 2, extent * 2, -extent, -extent, extent * 2, extent * 2))
f:write('<rect x="', -extent, '" y="', -extent, '" width="', extent * 2,
        '" height="', extent * 2, '" fill="#eef1f4"/>\n')

local drawn = 0
for _, h in ipairs(hats) do
  local poly = G.polygon(h.xf, unit)
  local pts = {}
  for i = 1, #poly do
    pts[i] = string.format("%.3f,%.3f", poly[i].x, poly[i].y)
  end
  f:write(string.format('<polygon points="%s" fill="%s" stroke="#111" '
    .. 'stroke-width="0.9" stroke-linejoin="round"/>\n',
    table.concat(pts, " "), shade(h)))
  drawn = drawn + 1
end
f:write("</svg>\n")
f:close()

local refl = 0
for _, h in ipairs(hats) do if h.reflected then refl = refl + 1 end end
print(string.format("%s: %d hats (%.1f%% reflected), depth %d, unit %g, extent %d",
  out, drawn, 100 * refl / drawn, depth, unit, extent))
