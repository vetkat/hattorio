-- Vulcanus: coal and calcite with electric drills, tungsten with big mining
-- drills, and foundries in stage 4.
--
-- The foundries make iron from lava, as on a real Vulcanus base. An offshore
-- pump on the lava shore feeds foundry A, which makes molten iron from lava
-- and calcite. A short pipe takes the molten iron up to foundry B, which
-- casts iron plates. A foundry facing north has its inputs on the bottom
-- edge and its outputs on the top edge.
local Kit = require("layouts.kit")

local abs = Kit.abs

-- The block of foundries. Foundry B stands above foundry A, so that a pipe of three tiles joins the
-- output of A to the input of B.
local function complex()
  return {
    { "foundry", 0, 0, nil, { recipe = "molten-iron-from-lava" } },
    -- A foundry has two outputs and two inputs, and a recipe uses one box on
    -- each side. One pipe network joins all four, so the molten iron reaches
    -- the input that the casting recipe uses. Only molten iron flows here.
    { "pipe", 1, -1 }, { "pipe", 1, -2 }, { "pipe", 1, -3 },
    { "pipe", 2, -2 },
    { "pipe", 3, -1 }, { "pipe", 3, -2 }, { "pipe", 3, -3 },
    { "foundry", 0, -8, nil, { recipe = "casting-iron" } },
    { "inserter", 5, 2, "west", { from = "east" } },
    -- Lava gives stone as well as molten iron. Without this inserter, the
    -- stone fills foundry A and it stops.
    { "fast-inserter", -1, 1, "west", { from = "east" } },
    { "iron-chest", -2, 1 },
    { "iron-chest", 6, 2, nil, { items = { { name = "calcite", count = 400 } } } },
    { "fast-inserter", 5, -6, "east", { from = "west" } },
    { "iron-chest", 6, -6 },
    { "medium-electric-pole", 5, -1 },
    { "medium-electric-pole", 5, -4 },
    { "medium-electric-pole", -1, -2 },
  }
end

local LAVA = { "lava", "lava-hot" }
local FACING = { north = { 0, 1 }, south = { 0, -1 }, east = { -1, 0 }, west = { 1, 0 } }

-- An offshore pump on the lava shore, and the foundries around it: the pump
-- feeds the lava input of foundry A directly, with no pipe between. For each
-- spot on the shore, the builder places a pump, reads where it connects, and
-- tries the block there. If the block does not fit, the pump goes again.
local function foundries(b)
  local mid = b:middle()
  local tiles = b.surface.find_tiles_filtered({ position = mid, radius = 300, name = LAVA,
    limit = 3000 })
  table.sort(tiles, function(p, q)
    local dp = (p.position.x - mid[1]) ^ 2 + (p.position.y - mid[2]) ^ 2
    local dq = (q.position.x - mid[1]) ^ 2 + (q.position.y - mid[2]) ^ 2
    return dp < dq
  end)
  local layout, tried = complex(), 0
  for _, tile in ipairs(tiles) do
    for dir, step in pairs(FACING) do
      local x, y = tile.position.x + step[1], tile.position.y + step[2]
      if tried < 400 and b:can_place("offshore-pump", x, y, dir) then
        tried = tried + 1
        local pump = b:put("offshore-pump", x, y, dir)
        if pump then
          -- The pump faces the lava and pushes lava out at its back: into
          -- the next tile away from the lava. That tile is the lava input of
          -- foundry A, which is (1, 4) from the origin of the block.
          local t = { x + step[1], y + step[2] }
          local origin = { t[1] - 1, t[2] - 4 }
          if b:place(layout, origin) then
            Kit.power(b, abs(origin, { 10, -4 }), 5500, abs(origin, { 5, -1 }))
            return abs(origin, { 2, -3 })
          end
          pump.destroy()
        end
      end
    end
  end
  log(string.format("showcase: no place for the foundries: %d lava tiles, %d pump spots tried",
    #tiles, tried))
  return nil
end

return { stages = Kit.stages({
  lines = {
    { ore = "coal", chain = "sink" },
    { ore = "calcite", chain = "sink" },
    { ore = "tungsten-ore", drill = "big", chain = "sink" },
    { ore = "tungsten-ore", drill = "big", chain = "sink" },
  },
  load = 1300,
  special = foundries,
  unlock = { "foundry" },
}) }
