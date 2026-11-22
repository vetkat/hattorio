-- The showcase base on Nauvis, in five stages. Each stage is a function that
-- builds on the stage before, with the builder of build.lua. A stage sets
-- b.focus to the block that its screenshot shows.

local M = require("modules")

local abs = require("layouts.kit").abs

-- A mine on the nearest patch of `ore`, furnaces in a cell next to it, and a
-- sink for the plates. The line has its own solar field next to the mine, as
-- an outpost of a player often does, so that its poles stay short. Returns
-- the origins of the mine and the furnaces.
local function ore_line(b, ore, near, key)
  local patch = b:ore(ore, near, 400)
  if not patch then return nil end
  local layout, at = M.mining(3)
  local mine = b:place_near(layout, patch, 600)
  if not mine then return nil end
  local solar, sat = M.solar(5)
  local power = b:place_near(solar, abs(mine, { 12, 0 }))
  if power then b:poles(abs(power, sat.pole), abs(mine, at.pole)) end
  layout, at = M.smelting(8)
  local smelt = b:place_along(layout, abs(mine, { 3, 9 }), "south", nil, nil, "south")
  if not smelt then return mine end
  b:poles(abs(mine, { -1, 1 }), abs(smelt, at.pole))
  b:sink(key, abs(smelt, at.out), "south")
  return mine, smelt
end

local stages = {}

-- 1. Iron miners and a solar field.
stages[1] = function(b)
  local layout, at = M.solar(6)
  local power = b:place_near(layout, { 0, 0 })
  b.anchor.power = abs(power, at.pole)
  local iron = b:ore("iron-ore", { 0, 0 })
  layout, at = M.mining(3)
  local mine = b:place_near(layout, iron, 600)
  b:poles(b.anchor.power, abs(mine, at.pole))
  b:sink("ore", abs(mine, at.out), "south")
  b.focus = abs(mine, { 3, 6 })
end

-- 2. Furnaces in the next cell. The ore belt goes under the band.
stages[2] = function(b)
  local start, dir, came = b:unsink("ore")
  local layout, at = M.smelting(8)
  local smelt = b:place_along(layout, start, dir, nil, nil, came)
  b:poles(b.anchor.power, abs(smelt, at.pole))
  b:sink("plates", abs(smelt, at.out), "south")
  b.anchor.smelt = smelt
  if start and smelt then
    b.focus = { (start[1] + smelt[1]) / 2, (start[2] + smelt[2]) / 2 + 4 }
  end
end

-- 3. Gear assemblers, and more power.
stages[3] = function(b)
  local start, dir, came = b:unsink("plates")
  local layout, at = M.assemblers(2, "iron-gear-wheel")
  local asm = b:place_along(layout, start, dir, nil, nil, came)
  b:poles(abs(b.anchor.smelt, { 1, 1 }), abs(asm, at.pole))
  b:sink("rest", abs(asm, { 0, 8 }), "south")
  layout, at = M.solar(6)
  local power = b:place_near(layout, abs(asm, { 20, 0 }))
  b:poles(abs(power, at.pole), abs(asm, at.pole))
  b.anchor.asm = asm
  b.focus = abs(asm, { 8, 2 })
end

-- 4. Labs, and a second iron line.
stages[4] = function(b)
  local layout, at = M.labs(4, { { name = "automation-science-pack", count = 200 } })
  local labs = b:place_near(layout, abs(b.anchor.asm, { -20, 0 }))
  b:poles(abs(b.anchor.asm, { 1, 3 }), abs(labs, at.pole))
  b.research = "logistics"
  ore_line(b, "iron-ore", abs(b.anchor.asm, { 40, 0 }) or { 40, 0 }, "iron2")
  b.focus = abs(labs, { 2, 8 })
end

-- 5. Copper and stone lines, more power, a train line across the base, and
-- roboports.
stages[5] = function(b)
  local _, copper = ore_line(b, "copper-ore", { 0, 0 }, "copper")
  ore_line(b, "stone", { 0, 0 }, "stone")
  local layout, at = M.solar(8)
  local power = b:place_near(layout, b:middle())
  b:poles(abs(power, at.pole), b.anchor.power)
  local box, mid = b:bounds(), b:middle()
  b:rails(math.floor(box.left) - 20, math.floor(box.right) + 20, math.floor(mid[2]) + 24)
  local robots = {
    { name = "construction-robot", count = 10 }, { name = "logistic-robot", count = 10 },
  }
  for _, near in ipairs({ b.anchor.asm or mid, copper or mid }) do
    local rp = b:place_near({ { "roboport", 0, 0, nil, { items = robots } } }, near)
    if rp then b:poles(b.anchor.power, { rp[1] + 2, rp[2] + 4 }) end
  end
  b.focus = { mid[1], mid[2] + 12 }
end

return { stages = stages }
