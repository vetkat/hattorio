-- The builder that the layouts use. It places buildings only where the game
-- allows them, so a building never stands on a band.
--
-- A layout is a list of {name, x, y, direction, extra}:
--   * x and y: the top left tile of the building, relative to an origin
--   * direction: "north", "east", "south" or "west"
--   * extra: settings such as recipe, fuel and items, and for an inserter
--     `from`, the side it takes items from

local Place = require("place")

local Build = {}
Build.__index = Build

local DIR = {
  north = defines.direction.north, east = defines.direction.east,
  south = defines.direction.south, west = defines.direction.west,
}
local STEP = { north = { 0, -1 }, east = { 1, 0 }, south = { 0, 1 }, west = { -1, 0 } }

local TIERS = {
  { "underground-belt", 4 }, { "fast-underground-belt", 6 }, { "express-underground-belt", 8 },
}

local WORKING_TYPES = { ["mining-drill"] = true, furnace = true, ["assembling-machine"] = true }

function Build.new(surface)
  return setmetatable({ surface = surface, force = game.forces.player, built = {},
    placed = 0, refused = 0, anchor = {} }, Build)
end

-- The centre of a building whose top left tile is (x, y). A building that
-- that turns by a quarter swaps its width and height.
local function centre(name, x, y, direction)
  local proto = prototypes.entity[name]
  local w, h = proto.tile_width, proto.tile_height
  if direction == "east" or direction == "west" then w, h = h, w end
  return { x = x + w / 2, y = y + h / 2 }
end

function Build:can_place(name, x, y, direction)
  if prototypes.entity[name].type == "mining-drill" then
    -- A drill only goes where there is something to mine.
    local c = centre(name, x, y, direction)
    local n = self.surface.count_entities_filtered({ type = "resource",
      area = { { c.x - 1.4, c.y - 1.4 }, { c.x + 1.4, c.y + 1.4 } } })
    if n == 0 then return false end
  end
  return self.surface.can_place_entity({
    name = name, position = centre(name, x, y, direction),
    direction = DIR[direction or "north"], force = self.force,
    build_check_type = defines.build_check_type.manual,
  })
end

function Build:checker()
  return function(name, x, y, direction) return self:can_place(name, x, y, direction) end
end

-- An inserter takes from one side and drops on the other. Which side the
-- direction names is a detail of the game, so the builder checks the pickup
-- position and turns the inserter round if it is wrong.
local function face(entity, from)
  local p = entity.pickup_position
  local dx, dy = p.x - entity.position.x, p.y - entity.position.y
  local s = STEP[from]
  if dx * s[1] + dy * s[2] < 0 then
    entity.rotate()
    entity.rotate()
  end
end

local function setup(entity, extra)
  if not extra then return end
  if extra.recipe then entity.set_recipe(extra.recipe) end
  if extra.from then face(entity, extra.from) end
  if extra.fuel then entity.insert({ name = extra.fuel, count = extra.fuel_count or 50 }) end
  for _, stack in ipairs(extra.items or {}) do entity.insert(stack) end
end

--- Place one building. Returns the entity, or nil if the game refuses.
function Build:put(name, x, y, direction, extra)
  if not self:can_place(name, x, y, direction) then
    self.refused = self.refused + 1
    return nil
  end
  local e = self.surface.create_entity({
    name = name, position = centre(name, x, y, direction),
    direction = DIR[direction or "north"], force = self.force,
    type = extra and extra.type,
  })
  if not e then
    self.refused = self.refused + 1
    return nil
  end
  self.placed = self.placed + 1
  self.built[#self.built + 1] = e
  setup(e, extra)
  return e
end

--- Place a whole layout at an origin, or nothing if the game refuses any
-- part of it.
function Build:place(layout, origin)
  if not Place.fit(layout, origin, self:checker()) then return nil end
  local out = {}
  for _, e in ipairs(layout) do
    out[#out + 1] = self:put(e[1], origin[1] + e[2], origin[2] + e[3], e[4], e[5])
  end
  return out
end

--- Place a layout at the first spiral position near a centre.
function Build:place_near(layout, centre_tile, tries)
  if not centre_tile then return nil end
  local origin = Place.find(layout, centre_tile, 3, tries or 400, self:checker())
  if not origin then return nil end
  self:place(layout, origin)
  return origin
end

--- Place a layout on the line from `start` towards `dir`, and lay a belt
-- from `start` to it. Returns the origin.
--- If nothing fits on the line, the belt bends once to the side. Returns
-- the origin, or nil.
function Build:place_along(layout, start, dir, from, to)
  if not start then return nil end
  local check = self:checker()
  local origin, k = Place.find_along(layout, start, dir, from or 4, to or 60, check, TIERS)
  if origin then
    self:place(layout, origin)
    self:belt(start, dir, k)
    return origin
  end
  local side, j
  origin, k, side, j = Place.find_bent(layout, start, dir, to or 60, 40, check, TIERS)
  if not origin then return nil end
  self:place(layout, origin)
  local d = STEP[dir]
  self:belt(start, dir, k)
  self:belt({ start[1] + d[1] * k, start[2] + d[2] * k }, side, j)
  return origin
end


--- A straight belt of `length` tiles, under any band on the way.
function Build:belt(start, dir, length)
  local route = Place.route(start, dir, length, self:checker(), TIERS)
  if not route then
    log(string.format("showcase: no belt route from %d,%d %s %d", start[1], start[2], dir, length))
    return false
  end
  local back = { north = "south", south = "north", east = "west", west = "east" }
  for _, e in ipairs(route) do
    local ent = self:put(e[1], e[2], e[3], e[4], e[5] and { type = e[5] })
    if not ent and e[5] == "output" then
      ent = self:put(e[1], e[2], e[3], back[e[4]], { type = "output" })
      log(string.format("showcase: exit at %d,%d took direction %s: %s", e[2], e[3],
        back[e[4]], ent and "placed" or "refused"))
    end
    if not ent then
      local here = {}
      for _, f in ipairs(self.surface.find_entities_filtered({
        area = { { e[2] - 0.5, e[3] - 0.5 }, { e[2] + 1.5, e[3] + 1.5 } } })) do
        here[#here + 1] = f.name .. "@" .. f.position.x .. "," .. f.position.y
      end
      log(string.format("showcase: refused %s at %d,%d %s %s; tile %s; near %s", e[1], e[2], e[3],
        e[4], e[5] or "", self.surface.get_tile(e[2], e[3]).name, table.concat(here, " ")))
    end
  end
  return true
end

-- The pole nearest to a tile, within `radius`.
function Build:pole_near(tile, radius)
  local found = self.surface.find_entities_filtered({ type = "electric-pole",
    position = { tile[1] + 0.5, tile[2] + 0.5 }, radius = radius or 3 })
  local best, best_d
  for _, e in ipairs(found) do
    local d = (e.position.x - tile[1]) ^ 2 + (e.position.y - tile[2]) ^ 2
    if not best_d or d < best_d then best, best_d = e, d end
  end
  return best
end

local function wire(a, b)
  if not (a and b) or a == b then return true end
  local ca = a.get_wire_connector(defines.wire_connector_id.pole_copper, true)
  local cb = b.get_wire_connector(defines.wire_connector_id.pole_copper, true)
  return ca.connect_to(cb, false)
end

--- Medium poles from one point to another, about every 7 tiles, each wired
-- to the one before. A pole that the game refuses moves sideways by up to 3
-- tiles. The line also connects to the poles that stand at both ends.
function Build:poles(a, b)
  if not (a and b) then return end
  local dx, dy = b[1] - a[1], b[2] - a[2]
  local n = math.max(1, math.ceil(math.max(math.abs(dx), math.abs(dy)) / 7))
  local prev = self:pole_near(a)
  for i = 0, n do
    local x = math.floor(a[1] + dx * i / n + 0.5)
    local y = math.floor(a[2] + dy * i / n + 0.5)
    local pole
    for _, off in ipairs({ { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 2, 0 },
      { -2, 0 }, { 0, 2 }, { 0, -2 }, { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } }) do
      pole = self:put("medium-electric-pole", x + off[1], y + off[2])
      if pole then break end
    end
    pole = pole or self:pole_near({ x, y }, 2)
    if pole and prev then
      wire(prev, pole)
      if prev.electric_network_id ~= pole.electric_network_id then
        log(string.format("showcase: no wire from %d,%d to %d,%d", prev.position.x,
          prev.position.y, pole.position.x, pole.position.y))
      end
    end
    prev = pole or prev
  end
  wire(prev, self:pole_near(b))
end

--- A sink at the end of a belt that runs towards `dir`. Two more belt tiles
-- from `at`, each with a fast inserter into a chest at its side, and a pole.
-- That takes about 4.6 items a second. The next stage removes the sink with
-- unsink and carries the belt on from `at`.
function Build:sink(key, at, dir)
  if not at then return end
  local s = STEP[dir]
  local side = ({ north = "east", south = "east", east = "south", west = "south" })[dir]
  local o = STEP[side]
  local back = ({ east = "west", south = "north" })[side]
  local parts = {}
  for k = 0, 1 do
    local x, y = at[1] + s[1] * k, at[2] + s[2] * k
    parts[#parts + 1] = self:put("transport-belt", x, y, dir)
    parts[#parts + 1] = self:put("fast-inserter", x + o[1], y + o[2], side, { from = back })
    parts[#parts + 1] = self:put("iron-chest", x + 2 * o[1], y + 2 * o[2])
  end
  parts[#parts + 1] = self:put("medium-electric-pole", at[1] - o[1], at[2] - o[2])
  self.anchor[key] = { at = at, dir = dir, parts = parts }
end

--- Remove a sink, and return the tile where the belt can go on.
function Build:unsink(key)
  local sink = self.anchor[key]
  if not sink then return nil, nil end
  for _, e in pairs(sink.parts) do
    if e and e.valid then e.destroy() end
  end
  return sink.at, sink.dir
end

--- A straight east-west track from x1 to x2 on row y, with a locomotive on
-- it. Rails cross bands, so only trees, rocks, cliffs and water stop it. The
-- builder clears trees and rocks on the row first, as a player does.
function Build:rails(x1, x2, y)
  y = y - y % 2
  for _, e in ipairs(self.surface.find_entities_filtered({
    area = { { x1, y - 1 }, { x2, y + 3 } }, type = { "tree", "simple-entity" } })) do
    e.destroy()
  end
  local laid = 0
  for x = x1 - x1 % 2, x2, 2 do
    if self:put("straight-rail", x, y, "east") then laid = laid + 1 end
  end
  local mid = math.floor((x1 + x2) / 2)
  mid = mid - mid % 2
  self:put("locomotive", mid, y, "east", { fuel = "coal", fuel_count = 50 })
  self:put("cargo-wagon", mid - 7, y, "east")
  self:put("cargo-wagon", mid - 14, y, "east")
  return laid
end

--- The centre of the nearest patch of a resource, as a tile.
function Build:ore(name, near, radius)
  local found = self.surface.find_entities_filtered({
    name = name, position = near, radius = radius or 200, limit = 400 })
  if #found == 0 then return nil end
  local best, best_d
  for _, e in ipairs(found) do
    local d = (e.position.x - near[1]) ^ 2 + (e.position.y - near[2]) ^ 2
    if not best_d or d < best_d then best, best_d = e, d end
  end
  return { math.floor(best.position.x), math.floor(best.position.y) }
end

local STATUS_NAME = {}
for name, value in pairs(defines.entity_status) do STATUS_NAME[value] = name end

--- How many miners, furnaces and crafting machines work, out of all of them,
-- and a count of each status, such as no_power or full_output.
function Build:working()
  local n, total, by_status = 0, 0, {}
  for _, e in ipairs(self.built) do
    if e.valid and WORKING_TYPES[e.type] then
      total = total + 1
      if e.status == defines.entity_status.working then n = n + 1 end
      local name = STATUS_NAME[e.status] or tostring(e.status)
      by_status[name] = (by_status[name] or 0) + 1
    end
  end
  return n, total, by_status
end

--- Log where a line stands, and if a building and a pole share an
-- electric network. For finding faults in a layout.
function Build:report(key, a, c, building_tile, pole_tile)
  local function net(tile)
    if not tile then return "none" end
    local found = self.surface.find_entities_filtered({
      position = { tile[1] + 0.5, tile[2] + 0.5 }, radius = 1.5 })
    for _, e in ipairs(found) do
      if e.electric_network_id then return e.name .. "#" .. e.electric_network_id end
    end
    return "no-network"
  end
  log(string.format("showcase: line %s mine=%s power=%s building=%s pole=%s", key,
    a and (a[1] .. "," .. a[2]) or "nil", c and (c[1] .. "," .. c[2]) or "nil",
    net(building_tile), net(pole_tile)))
end

--- The middle of everything built so far: the median of the positions, so
-- that a long pole line does not pull it away from the buildings.
function Build:middle()
  local xs, ys = {}, {}
  for _, e in ipairs(self.built) do
    if e.valid and e.type ~= "electric-pole" then
      xs[#xs + 1] = e.position.x
      ys[#ys + 1] = e.position.y
    end
  end
  table.sort(xs)
  table.sort(ys)
  local i = math.max(1, math.floor(#xs / 2))
  return { xs[i] or 0, ys[i] or 0 }
end

--- The bounding box of everything built so far.
function Build:bounds()
  local l, t, r, b = math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(self.built) do
    if e.valid then
      local p = e.position
      l, t, r, b = math.min(l, p.x), math.min(t, p.y), math.max(r, p.x), math.max(b, p.y)
    end
  end
  return { left = l, top = t, right = r, bottom = b }
end

return Build
