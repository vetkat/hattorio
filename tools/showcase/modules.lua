-- Small working modules that the planet layouts combine. Each returns a
-- layout (see build.lua) and the tiles where its belts end, relative to its
-- origin.

local M = {}

--- Solar panels in two rows of `cols`, with poles between the rows and two
-- accumulators at the end.
function M.solar(cols)
  local l = {}
  for j = 0, cols - 1 do
    l[#l + 1] = { "solar-panel", 3 * j, 0 }
    l[#l + 1] = { "solar-panel", 3 * j, 4 }
    if j % 2 == 0 then l[#l + 1] = { "medium-electric-pole", 3 * j + 1, 3 } end
  end
  l[#l + 1] = { "accumulator", 3 * cols, 0 }
  l[#l + 1] = { "accumulator", 3 * cols, 2 }
  l[#l + 1] = { "medium-electric-pole", 3 * cols, 4 }
  return l, { pole = { 1, 3 } }
end

--- Electric drills on both sides of a belt that runs south. The belt leaves
-- at `out`.
function M.mining(rows)
  local l = {}
  for i = 0, rows - 1 do
    l[#l + 1] = { "electric-mining-drill", 0, 3 * i, "east" }
    l[#l + 1] = { "electric-mining-drill", 4, 3 * i, "west" }
    for k = 0, 2 do l[#l + 1] = { "transport-belt", 3, 3 * i + k, "south" } end
    if i % 2 == 0 then
      l[#l + 1] = { "medium-electric-pole", -1, 3 * i + 1 }
      l[#l + 1] = { "medium-electric-pole", 7, 3 * i + 1 }
    end
  end
  return l, { out = { 3, 3 * rows }, pole = { -1, 1 } }
end

--- A column of stone furnaces. Ore comes in on a belt at the origin that
-- runs south. Plates leave on a belt at `out`.
function M.smelting(rows)
  local l = {}
  for i = 0, rows - 1 do
    local y = 2 * i
    l[#l + 1] = { "transport-belt", 0, y, "south" }
    l[#l + 1] = { "transport-belt", 0, y + 1, "south" }
    l[#l + 1] = { "inserter", 1, y, "east", { from = "west" } }
    l[#l + 1] = { "stone-furnace", 2, y, nil, { fuel = "coal" } }
    l[#l + 1] = { "inserter", 4, y, "east", { from = "west" } }
    l[#l + 1] = { "transport-belt", 5, y, "south" }
    l[#l + 1] = { "transport-belt", 5, y + 1, "south" }
    if i % 3 == 0 then
      l[#l + 1] = { "medium-electric-pole", 1, y + 1 }
      l[#l + 1] = { "medium-electric-pole", 4, y + 1 }
    end
  end
  return l, { out = { 5, 2 * rows }, pole = { 1, 1 } }
end

--- Assemblers that take plates from a belt at the origin, which runs south,
-- and put their product into chests.
function M.assemblers(rows, recipe)
  local l = {}
  for i = 0, rows - 1 do
    local y = 4 * i
    for k = 0, 3 do l[#l + 1] = { "transport-belt", 0, y + k, "south" } end
    l[#l + 1] = { "inserter", 1, y + 1, "east", { from = "west" } }
    l[#l + 1] = { "assembling-machine-1", 2, y, nil, { recipe = recipe } }
    l[#l + 1] = { "inserter", 5, y + 1, "east", { from = "west" } }
    l[#l + 1] = { "wooden-chest", 6, y + 1 }
    l[#l + 1] = { "medium-electric-pole", 1, y + 3 }
    l[#l + 1] = { "medium-electric-pole", 5, y + 3 }
  end
  return l, { pole = { 1, 3 } }
end

--- Labs, each fed from a chest of science packs.
function M.labs(rows, packs)
  local l = {}
  for i = 0, rows - 1 do
    local y = 4 * i
    l[#l + 1] = { "lab", 0, y }
    l[#l + 1] = { "inserter", 3, y + 1, "west", { from = "east" } }
    l[#l + 1] = { "wooden-chest", 4, y + 1, nil, { items = packs } }
    l[#l + 1] = { "medium-electric-pole", 3, y + 3 }
  end
  return l, { pole = { 3, 3 } }
end

--- Big mining drills on both sides of a belt that runs south. They mine
-- what an electric drill cannot, such as tungsten.
function M.big_mining(rows)
  local l = {}
  for i = 0, rows - 1 do
    l[#l + 1] = { "big-mining-drill", 0, 5 * i, "east" }
    l[#l + 1] = { "big-mining-drill", 6, 5 * i, "west" }
    for k = 0, 4 do l[#l + 1] = { "transport-belt", 5, 5 * i + k, "south" } end
    l[#l + 1] = { "medium-electric-pole", -1, 5 * i + 2 }
    l[#l + 1] = { "medium-electric-pole", 11, 5 * i + 2 }
  end
  return l, { out = { 5, 5 * rows }, pole = { -1, 2 } }
end

--- A column of machines of any size. Items come in on a belt at the origin
-- that runs south. An inserter feeds each machine, and another puts its
-- products into a chest. The sizes come from the game.
function M.machines(rows, name, extra)
  local proto = prototypes.entity[name]
  local w, h = proto.tile_width, proto.tile_height
  local step = math.max(h, 2) + 1
  local l = {}
  for i = 0, rows - 1 do
    local y = step * i
    for k = 0, step - 1 do l[#l + 1] = { "transport-belt", 0, y + k, "south" } end
    l[#l + 1] = { "inserter", 1, y, "east", { from = "west" } }
    l[#l + 1] = { name, 2, y, nil, extra }
    l[#l + 1] = { "inserter", 2 + w, y, "east", { from = "west" } }
    l[#l + 1] = { "iron-chest", 3 + w, y }
    -- Two tiles from the inserters, inside the supply area of the pole.
    l[#l + 1] = { "medium-electric-pole", 1, y + 2 }
    l[#l + 1] = { "medium-electric-pole", 2 + w, y + 2 }
  end
  return l, { out = { 0, step * rows }, pole = { 1, 2 } }
end

return M
