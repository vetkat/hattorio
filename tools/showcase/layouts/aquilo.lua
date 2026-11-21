-- Aquilo: a heated power plant, oil wells and cryogenic plants.
--
-- On Aquilo, most buildings freeze unless a heat pipe or another heat source
-- touches them. Each block here has a heating tower that burns rocket fuel
-- from a chest, and heat pipes along each building that needs heat. Poles,
-- chests and offshore pumps do not freeze.
--
-- Aquilo has no water to pump. The heat exchanger takes water from two tanks
-- that start full, as if a player brought it in barrels. The cryogenic
-- plants separate the ammonia ocean into ice and ammonia, and keep both in
-- chests and tanks.
--
-- A layout here gives the top left tile of each building. The comments name
-- the connections of the game that each position meets.
local Kit = require("layouts.kit")
local Place = require("place")

local abs = Kit.abs

local AMMONIA = { "ammoniacal-ocean", "ammoniacal-ocean-2" }
-- The tiles that get ice platform: the ocean and the brash ice at its edge.
local WET = { "ammoniacal-ocean", "ammoniacal-ocean-2", "brash-ice" }

local FUEL = { { name = "rocket-fuel", count = 960 } }

-- A heating tower at (x, y), with an inserter that feeds it from a chest
-- below it. The tower starts with fuel, so that it heats before the power
-- comes. Its south side takes heat to (x + 1, y + 3), where the inserter
-- stands, so a heat pipe at (x, y + 3) keeps the inserter warm.
local function heater(l, x, y)
  l[#l + 1] = { "heating-tower", x, y, nil, { fuel = "rocket-fuel", fuel_count = 40 } }
  l[#l + 1] = { "inserter", x + 1, y + 3, "north", { from = "south" } }
  l[#l + 1] = { "steel-chest", x + 1, y + 4, nil, { items = FUEL } }
end

local function pipes(l, x1, y1, x2, y2)
  for x = x1, x2 do
    for y = y1, y2 do l[#l + 1] = { "heat-pipe", x, y } end
  end
end

-- The power plant. The turbine stands on the heat exchanger, so the steam
-- goes straight up. The tower below heats the exchanger through the heat pipe
-- at (1, 5). Tank 1 feeds the exchanger at its west side, and tank 2 feeds
-- tank 1. Heat pipes run round the turbine and the tanks.
local function plant()
  local l = {
    { "steam-turbine", 0, -2 },
    { "heat-exchanger", 0, 3 },
    { "storage-tank", -3, 2, nil, { fluid = { name = "water", amount = 25000 } } },
    { "storage-tank", -5, -1, nil, { fluid = { name = "water", amount = 25000 } } },
    { "medium-electric-pole", 4, 0 },
    { "medium-electric-pole", 4, 8 },
    -- A test: an inserter that touches the tower and no heat pipe.
    { "inserter", 3, 7, "north", { from = "south" } },
  }
  heater(l, 0, 6)
  pipes(l, -3, 5, 3, 5)
  pipes(l, 3, -3, 3, 4)
  pipes(l, -1, -3, 2, -3)
  pipes(l, -1, -2, -1, 1)
  pipes(l, -2, -1, -2, 1)
  pipes(l, -1, 6, -1, 9)
  pipes(l, 0, 9, 0, 9)
  return l, { 4, 0 }
end

-- An oil well. A pumpjack has its output on one corner, and the side it
-- faces picks the corner. For each side, the tank stands at that output and
-- the heating tower stands where it fits. Its heat pipes touch the
-- pumpjack, the tank and the inserter of the tower.
local WELL_SIDES = {
  north = { tank = { 0, -3 }, tower = { 4, -1 }, pole = { 2, 3 },
    heat = { { 3, -1 }, { 3, 0 }, { 3, 1 }, { 3, 2 }, { 4, 2 } } },
  south = { tank = { 0, 3 }, tower = { 4, 1 }, pole = { 3, 1 },
    heat = { { 3, 2 }, { 3, 3 }, { 3, 4 }, { 4, 4 } } },
  west = { tank = { -3, -2 }, tower = { -4, 1 }, pole = { 0, 3 },
    heat = { { -1, 1 }, { -1, 2 }, { -1, 3 }, { -1, 4 }, { -2, 4 } } },
  east = { tank = { 3, 2 }, tower = { -4, -1 }, pole = { 0, 3 },
    heat = { { 3, 1 }, { 3, 0 }, { 3, -1 }, { 2, -1 }, { 1, -1 }, { 0, -1 }, { -1, -1 },
      { -1, 0 }, { -1, 1 }, { -1, 2 }, { -2, 2 } } },
}

local function well(side)
  local w = WELL_SIDES[side]
  local l = {
    { "pumpjack", 0, 0, side },
    { "storage-tank", w.tank[1], w.tank[2] },
    { "medium-electric-pole", w.pole[1], w.pole[2] },
  }
  heater(l, w.tower[1], w.tower[2])
  for _, h in ipairs(w.heat) do l[#l + 1] = { "heat-pipe", h[1], h[2] } end
  return l, w.pole
end

-- A cryogenic plant. The offshore pump stands at (2, 5) and fills the
-- middle input at (2, 4), which is the one that the recipe uses. The middle
-- output at (2, 0) fills the tank.
--
-- One fast
-- inserter takes the ice out to a chest, about 2.3 a second. That holds the
-- plant to about 23 ammonia a second, so the tank lasts about 1000 seconds.
-- The tower at (6, -2) heats a ring of heat pipes round the inserter and
-- its chest. It also heats a row along the top of the plant, next to the
-- tank.
local function cryo()
  local l = {
    { "offshore-pump", 2, 5, "south" },
    { "cryogenic-plant", 0, 0, nil, { recipe = "ammoniacal-solution-separation" } },
    { "storage-tank", 0, -3 },
    { "fast-inserter", 5, 2, "east", { from = "west" } },
    { "steel-chest", 6, 2 },
    { "medium-electric-pole", 5, 5 },
    { "heating-tower", 6, -2, nil, { fuel = "rocket-fuel", fuel_count = 40 } },
    { "inserter", 9, -1, "west", { from = "east" } },
    { "steel-chest", 10, -1, nil, { items = FUEL } },
    { "medium-electric-pole", 9, 1 },
  }
  pipes(l, 3, -1, 5, -1)
  pipes(l, 5, 0, 5, 1)
  pipes(l, 6, 1, 7, 1)
  pipes(l, 7, 2, 7, 3)
  pipes(l, 5, 3, 6, 3)
  pipes(l, 5, 4, 5, 4)
  return l, { 5, 5 }
end

-- Wells on the crude oil nearest to `near`. A pumpjack stands on the centre
-- of a well, so the well fixes the place of the block.
local function wells(b, near, count)
  local found = b.surface.find_entities_filtered({ name = "crude-oil", position = near,
    radius = 400 })
  -- A pumpjack pumps faster on a richer well, and on Aquilo even a poor well
  -- fills a tank in well under an hour. The poorest wells come first, so
  -- that the tanks last the whole run.
  table.sort(found, function(p, q) return p.amount < q.amount end)
  if found[1] then
    game.take_screenshot({ surface = b.surface, position = found[1].position, zoom = 0.5,
      resolution = { 1600, 1600 }, show_gui = false, daytime = 0,
      path = "showcase/debug/aquilo-oil.png" })
  end
  local placed, first = 0, nil
  for _, oil in ipairs(found) do
    if placed >= count then break end
    -- A pumpjack stands on the centre of the well.
    local origin = { math.floor(oil.position.x) - 1, math.floor(oil.position.y) - 1 }
    for side in pairs(WELL_SIDES) do
      local layout, pole = well(side)
      if Place.fit(layout, origin, b:pave_checker(WET)) then
        b:pave(layout, origin, WET, "ice-platform")
        if b:place(layout, origin) then
          b:link(abs(origin, pole))
          placed = placed + 1
          first = first or origin
          break
        end
      end
    end
  end
  log(string.format("showcase: %d of %d oil wells from %d wells", placed, count, #found))
  return first
end

-- A cryogenic plant on the shore nearest to `near`. The pump stands on land
-- with the ocean to its south. Where the ocean meets the rest of the block,
-- the builder lays ice platform first.
local function shore(b, near)
  local layout = cryo()
  local pump
  for _, e in ipairs(layout) do
    if e[1] == "offshore-pump" then pump = { e[2], e[3] } end
  end
  local tried = 0
  for _, radius in ipairs({ 30, 60, 120, 240 }) do
    local spots = {}
    for _, t in ipairs(b.surface.find_tiles_filtered({ position = near, radius = radius,
      name = AMMONIA })) do
      local d = (t.position.x - near[1]) ^ 2 + (t.position.y - near[2]) ^ 2
      local land = { t.position.x, t.position.y - 1 }
      if d >= (radius / 2) ^ 2
        and not b.surface.get_tile(land[1], land[2]).collides_with("water_tile") then
        spots[#spots + 1] = { land = land, d = d }
      end
    end
    table.sort(spots, function(p, q) return p.d < q.d end)
    for _, spot in ipairs(spots) do
      if tried >= 3000 then break end
      tried = tried + 1
      local origin = { spot.land[1] - pump[1], spot.land[2] - pump[2] }
      if Place.fit(layout, origin, b:pave_checker(WET)) then
        b:pave(layout, origin, WET, "ice-platform")
        if b:place(layout, origin) then
          b:link(abs(origin, { 5, 5 }))
          return origin
        end
      end
    end
  end
  log(string.format("showcase: no shore for a cryogenic plant after %d tries", tried))
  return nil
end

-- A heat pipe holds 1 MJ for each degree. The first fuel of a tower does
-- not warm a cold network to 500 degrees, and the heat exchanger needs
-- that. Without power, the inserter brings no more fuel. So the new heat
-- buildings of each stage start warm, as a player warms them up by hand.
-- The towers keep them warm from then on.
local HEAT = { ["heat-pipe"] = true, ["heating-tower"] = true, ["heat-exchanger"] = true }

local function warm(b)
  for _, e in ipairs(b.built) do
    if e.valid and HEAT[e.name] and e.temperature < 500 then e.temperature = 600 end
  end
end

local stages = {}

stages[1] = function(b)
  for _, name in ipairs({ "planet-discovery-aquilo", "cryogenic-plant" }) do
    Kit.unlock(b.force, name)
  end
  local layout = plant()
  local origin = b:place_near(layout, { 0, 0 }, 2000)
  b.anchor.first = origin
  b.focus = abs(origin, { 1, 3 })
end

stages[2] = function(b)
  b.focus = abs(wells(b, b.anchor.first or { 0, 0 }, 2), { 3, 0 })
end

stages[3] = function(b)
  local origin = shore(b, b.anchor.first or { 0, 0 })
  b.anchor.cryo = origin
  b.focus = abs(origin, { 4, 0 })
end

stages[4] = function(b)
  wells(b, b.anchor.first or { 0, 0 }, 2)
  shore(b, b.anchor.cryo or b.anchor.first or { 0, 0 })
  b.focus = b:middle()
end

stages[5] = function(b)
  wells(b, b.anchor.first or { 0, 0 }, 2)
  local box, mid = b:bounds(), b:middle()
  b:rails(math.floor(box.left) - 20, math.floor(box.right) + 20, math.floor(mid[2]) + 24)
  b.focus = { mid[1], mid[2] + 12 }
end

for i, stage in ipairs(stages) do
  stages[i] = function(b)
    stage(b)
    warm(b)
  end
end

return { stages = stages }
