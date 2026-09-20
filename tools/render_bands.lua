-- Preview the mod as it will appear in game: hat cells rasterised onto
-- Factorio's square tile grid, with unbuildable bands between them.
--
--   lua5.2 tools/render_bands.lua [hat-size] [band] [tiles] [out.svg]
--
-- hat-size is centre-to-vertex in tiles (the planned startup setting).
-- Everything here is what terrain/bands.lua will do at chunk generation.

package.path = "./?.lua;" .. package.path

local Ti = require("hat.tiling")
local G = require("hat.geometry")

local size   = tonumber(arg[1]) or 20
local band   = tonumber(arg[2]) or 2
local tiles  = tonumber(arg[3]) or 200
local out    = arg[4] or "bands.svg"

local unit = size / G.RADIUS
local half = band / 2

-- depth just large enough to cover the window
local t
for d = 0, Ti.max_depth() do
  t = Ti.new({ unit = unit, depth = d })
  if t:coverage() > tiles then break end
end

local lo = -math.floor(tiles / 2)
local hi = lo + tiles - 1
local pad = band + 2
local hats = t:hats_in_box({ left = lo - pad, top = lo - pad,
                             right = hi + pad, bottom = hi + pad })

-- cache each hat's edges once
local edges = {}
for i, h in ipairs(hats) do edges[i] = G.edges(h.xf, unit) end

local f = assert(io.open(out, "w"))
f:write(string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" '
  .. 'height="%d" viewBox="%d %d %d %d" shape-rendering="crispEdges">\n',
  tiles * 4, tiles * 4, lo, lo, tiles, tiles))
f:write(string.format('<rect x="%d" y="%d" width="%d" height="%d" fill="#7a8b5a"/>\n',
  lo, lo, tiles, tiles))

local band_tiles = 0
for ty = lo, hi do
  for tx = lo, hi do
    local px, py = tx + 0.5, ty + 0.5
    local on_band = false
    for i = 1, #edges do
      local e = edges[i]
      for j = 1, #e do
        local s = e[j]
        if G.dist_to_segment(px, py, s[1], s[2], s[3], s[4]) < half then
          on_band = true
          break
        end
      end
      if on_band then break end
    end
    if on_band then
      band_tiles = band_tiles + 1
      f:write(string.format('<rect x="%d" y="%d" width="1" height="1" fill="#2b2f36"/>\n',
        tx, ty))
    end
  end
end
f:write("</svg>\n")
f:close()

print(string.format("%s: %dx%d tiles, hat size %g, band %g -> %.1f%% unbuildable",
  out, tiles, tiles, size, band, 100 * band_tiles / (tiles * tiles)))
