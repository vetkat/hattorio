-- Descent cost per 32x32 chunk at realistic settings.
--   lua5.2 tools/bench.lua
package.path = "./?.lua;" .. package.path

local Ti = require("hat.tiling")

local UNIT = 4.365          -- hat size 20 tiles
local depth = Ti.max_depth()
local t = Ti.new({ unit = UNIT, depth = depth })

print(string.format("depth %d, unit %.3f, coverage %.0f tiles",
      depth, UNIT, t:coverage()))

local CHUNKS = 400
local start = os.clock()
local total = 0
for i = 1, CHUNKS do
  local cx = (i % 20) * 32
  local cy = math.floor(i / 20) * 32
  total = total + #t:hats_in_box({ left=cx, top=cy, right=cx+32, bottom=cy+32 })
end
local ms = 1000 * (os.clock() - start) / CHUNKS
print(string.format("descent:   %d chunks, %.3f ms/chunk, %.2f hats/chunk",
      CHUNKS, ms, total/CHUNKS))
assert(ms < 50, "descent too slow for chunk generation: " .. ms .. " ms")

-- Full per-chunk cost, which is what terrain generation actually pays.
-- Rasterising each edge into its own bounding box rather than testing every
-- tile against every edge took this from 39.7 ms/chunk to about 1.3.
local Config = require("mod.config")
local Bands = require("mod.bands")
local g = Config.geometry(26, 2)
local bt = Ti.new({ unit = g.unit, depth = g.depth })

local bstart = os.clock()
local tiles = 0
for i = 1, CHUNKS do
  local cx = (i % 20) * 32
  local cy = math.floor(i / 20) * 32
  tiles = tiles + #Bands.for_area(bt, g, { left=cx, top=cy, right=cx+32, bottom=cy+32 })
end
local bms = 1000 * (os.clock() - bstart) / CHUNKS
print(string.format("bands:     %.3f ms/chunk, %.0f band tiles/chunk", bms, tiles/CHUNKS))
assert(bms < 10, "band rasterisation too slow for chunk generation: " .. bms .. " ms")
print("OK")
