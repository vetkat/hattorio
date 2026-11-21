-- Gleba: stone into bricks, and agricultural towers in stage 4.
local Kit = require("layouts.kit")

local function farms(b)
  local first
  for i = 0, 1 do
    local origin = b:place_near({ { "agricultural-tower", 0, 0, nil,
      { items = { { name = "yumako-seed", count = 20 } } } } },
      Kit.abs(b.anchor.first, { 20 + 10 * i, 20 }) or { 20, 20 })
    first = first or origin
  end
  return first
end

return { stages = Kit.stages({
  lines = {
    { ore = "stone", chain = "smelt" },
    { ore = "stone", chain = "smelt" },
    { ore = "stone", chain = "smelt" },
  },
  special = farms,
  load = 1000,
}) }
