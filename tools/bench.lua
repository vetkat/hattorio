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
print(string.format("%d chunks: %.3f ms/chunk, %.2f hats/chunk", CHUNKS, ms, total/CHUNKS))
assert(ms < 50, "descent too slow for chunk generation: " .. ms .. " ms")
print("OK")
