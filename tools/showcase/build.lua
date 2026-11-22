-- The builder that the layouts use. It places buildings only where the game
-- allows them, so a building never stands on a band.
--
-- A layout is a list of {name, x, y, direction, extra}:
--   * x and y: the top left tile of the building, relative to an origin
--   * direction: "north", "east", "south" or "west"
--   * extra: settings such as recipe, fuel, items and fluid, and for an
--     inserter `from`, the side it takes items from

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
local function size(name, direction)
  local proto = prototypes.entity[name]
  local w, h = proto.tile_width, proto.tile_height
  if direction == "east" or direction == "west" then return h, w end
  return w, h
end

local function centre(name, x, y, direction)
  local w, h = size(name, direction)
  return { x = x + w / 2, y = y + h / 2 }
end

-- Trees, rocks and plants that a player would clear to build. Bands, water,
-- cliffs and buildings are never cleared.
local OBSTACLES = { tree = true, ["simple-entity"] = true, plant = true }

-- The area of a building whose top left tile is (x, y).
local function footprint(name, x, y, direction)
  local w, h = size(name, direction)
  return { { x + 0.05, y + 0.05 }, { x + w - 0.05, y + h - 0.05 } }, w, h
end

-- True if only obstacles stand in the way, so that clearing them would let
-- the building stand. With `paved`, a set of tile names, those tiles count
-- as land, and the building can stand with nothing to clear.
function Build:only_obstacles(name, x, y, direction, paved)
  local area, w, h = footprint(name, x, y, direction)
  for tx = x, x + w - 1 do
    for ty = y, y + h - 1 do
      local tile = self.surface.get_tile(tx, ty)
      if tile.collides_with("hattorio_band")
        or (tile.collides_with("water_tile") and not (paved and paved[tile.name])) then
        return false
      end
    end
  end
  local blocking = false
  for _, e in ipairs(self.surface.find_entities_filtered({ area = area })) do
    if OBSTACLES[e.type] then
      blocking = true
    elseif e.type ~= "resource" and e.type ~= "corpse" then
      return false
    end
  end
  return blocking or paved ~= nil
end

function Build:clear(name, x, y, direction)
  local area = footprint(name, x, y, direction)
  for _, e in ipairs(self.surface.find_entities_filtered({ area = area })) do
    if OBSTACLES[e.type] then e.destroy() end
  end
end

local SCRIPT_CHECK = { ["storage-tank"] = true, ["heat-pipe"] = true }

function Build:can_place(name, x, y, direction)
  if prototypes.entity[name].type == "mining-drill" then
    -- A drill only goes where there is something to mine.
    local c = centre(name, x, y, direction)
    local n = self.surface.count_entities_filtered({ type = "resource",
      area = { { c.x - 1.4, c.y - 1.4 }, { c.x + 1.4, c.y + 1.4 } } })
    if n == 0 then return false end
  end
  -- The manual check refuses a tank at the output of a pumpjack, and a heat
  -- pipe at the pipe connection of a tank. The script check allows both, and
  -- it still keeps buildings off bands and each other.
  local check = SCRIPT_CHECK[prototypes.entity[name].type] and "script" or "manual"
  local ok = self.surface.can_place_entity({
    name = name, position = centre(name, x, y, direction),
    direction = DIR[direction or "north"], force = self.force,
    build_check_type = defines.build_check_type[check],
  })
  return ok or self:only_obstacles(name, x, y, direction)
end

function Build:checker()
  return function(name, x, y, direction) return self:can_place(name, x, y, direction) end
end

--- Like checker, but a tile of `from` counts as land, because pave will lay
-- a platform there first. A band still blocks.
function Build:pave_checker(from)
  local names = {}
  for _, n in ipairs(from) do names[n] = true end
  return function(name, x, y, direction)
    local _, w, h = footprint(name, x, y, direction)
    for tx = x, x + w - 1 do
      for ty = y, y + h - 1 do
        if names[self.surface.get_tile(tx, ty).name] then
          return self:only_obstacles(name, x, y, direction, names)
        end
      end
    end
    return self:can_place(name, x, y, direction)
  end
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
  if extra.fluid then entity.insert_fluid(extra.fluid) end
  if extra.temperature then entity.temperature = extra.temperature end
end

--- Place one building. Returns the entity, or nil if the game refuses.
function Build:put(name, x, y, direction, extra)
  if not self:can_place(name, x, y, direction) then
    self.refused = self.refused + 1
    return nil
  end
  self:clear(name, x, y, direction)
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

--- A function(x, y) that is true for the tiles that a layout covers at an
-- origin, with the sizes of the buildings from the game.
function Build.covers(layout, origin)
  local tiles = {}
  for _, e in ipairs(layout) do
    local w, h = size(e[1], e[4])
    for dx = 0, w - 1 do
      for dy = 0, h - 1 do
        tiles[(origin[1] + e[2] + dx) .. "," .. (origin[2] + e[3] + dy)] = true
      end
    end
  end
  return function(x, y) return tiles[x .. "," .. y] == true end
end

--- Lay the tile `to` under a layout at an origin, where the tile is one of
-- `from`. On Aquilo, players build on ice platform over the ocean. The
-- tiles go in with raise_event, so Hattorio sees them as it sees any new
-- tiles, and a band on the way stays a band.
function Build:pave(layout, origin, from, to)
  local names = {}
  for _, n in ipairs(from) do names[n] = true end
  local tiles = {}
  for _, e in ipairs(layout) do
    local w, h = size(e[1], e[4])
    for dx = 0, w - 1 do
      for dy = 0, h - 1 do
        local x, y = origin[1] + e[2] + dx, origin[2] + e[3] + dy
        if names[self.surface.get_tile(x, y).name] then
          tiles[#tiles + 1] = { name = to, position = { x, y } }
        end
      end
    end
  end
  if #tiles > 0 then self.surface.set_tiles(tiles, true, true, true, true) end
  return #tiles
end

--- Place a whole layout at an origin, or nothing if the game refuses any
-- part of it.
function Build:place(layout, origin)
  if not Place.fit(layout, origin, self:checker()) then return nil end
  local out = {}
  for _, e in ipairs(layout) do
    local ent = self:put(e[1], origin[1] + e[2], origin[2] + e[3], e[4], e[5])
    if not ent then
      -- A part that fits alone can still meet an earlier part. Take the
      -- block away again, so that the next try finds the tiles free.
      for _, done in ipairs(out) do done.destroy() end
      self.placed = self.placed - #out
      return nil
    end
    out[#out + 1] = ent
  end
  return out
end

--- Place a layout at the first spiral position near a centre.
function Build:place_near(layout, centre_tile, tries)
  if not centre_tile then return nil end
  local origin = Place.find(layout, centre_tile, 3, tries or 400, self:checker())
  if not origin or not self:place(layout, origin) then return nil end
  return origin
end

--- Place a layout on the line from `start` towards `dir`, and lay a belt
-- from `start` to it. Returns the origin.
--- If nothing fits on the line, the belt bends once to the side. Returns
-- the origin, or nil.
function Build:place_along(layout, start, dir, from, to, came)
  if not start then return nil end
  local check = self:checker()
  local covers = function(o) return Build.covers(layout, o) end
  local turned = came ~= nil and came ~= dir
  local origin, k = Place.find_along(layout, start, dir, from or 4, to or 60, check, TIERS, covers,
    turned)
  if origin then
    if not self:place(layout, origin) then return nil end
    self:belt(start, dir, k, turned)
    return origin
  end
  local side, j
  origin, k, side, j = Place.find_bent(layout, start, dir, to or 60, 40, check, TIERS, covers,
    turned)
  if not origin or not self:place(layout, origin) then return nil end
  local d = STEP[dir]
  self:belt(start, dir, k, turned)
  self:belt({ start[1] + d[1] * k, start[2] + d[2] * k }, side, j, true)
  return origin
end


--- A straight belt of `length` tiles, under any band on the way. `turned`
-- works as for Place.route.
function Build:belt(start, dir, length, turned)
  local route = Place.route(start, dir, length, self:checker(), TIERS, turned)
  if not route then
    log(string.format("showcase: no belt route from %d,%d %s %d", start[1], start[2], dir, length))
    return false
  end
  local back = { north = "south", south = "north", east = "west", west = "east" }
  local placed = {}
  for _, e in ipairs(route) do
    local ent = self:put(e[1], e[2], e[3], e[4], e[5] and { type = e[5] })
    if not ent and e[5] == "output" then
      -- Some exits go in only when they face back.
      ent = self:put(e[1], e[2], e[3], back[e[4]], { type = "output" })
    end
    placed[#placed + 1] = ent
  end
  return placed
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

--- Pipes from tile `a` to tile `b`, along one leg in x and one in y. The
-- builder tries both orders. Pipes go only where the game allows, so they
-- never cross a band. `name` is "pipe" by default, or "heat-pipe". Returns
-- true if a whole path was laid.
function Build:pipe_path(a, b, name)
  name = name or "pipe"
  local function path(x_first)
    local tiles, x, y = {}, a[1], a[2]
    local function go(tx, ty)
      while x ~= tx or y ~= ty do
        tiles[#tiles + 1] = { x, y }
        if x ~= tx then x = x + (tx > x and 1 or -1) else y = y + (ty > y and 1 or -1) end
      end
    end
    if x_first then go(b[1], a[2]) go(b[1], b[2]) else go(a[1], b[2]) go(b[1], b[2]) end
    tiles[#tiles + 1] = { b[1], b[2] }
    return tiles
  end
  for _, x_first in ipairs({ true, false }) do
    local tiles, ok = path(x_first), true
    for _, p in ipairs(tiles) do
      if not self:can_place(name, p[1], p[2]) then ok = false break end
    end
    if ok then
      for _, p in ipairs(tiles) do self:put(name, p[1], p[2]) end
      return true
    end
  end
  return false
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
      -- A probe with can_place, so that a spot that does not fit does not
      -- count as a refused building.
      if self:can_place("medium-electric-pole", x + off[1], y + off[2]) then
        pole = self:put("medium-electric-pole", x + off[1], y + off[2])
        if pole then break end
      end
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

--- Connect the pole at or near a tile to the nearest pole of another
-- electric network, with a line of poles. A new block or sink starts on a
-- network of its own, and this joins it to the base.
function Build:link(tile)
  local own = self:pole_near(tile)
  if not own then return end
  local best, best_d
  for _, e in ipairs(self.surface.find_entities_filtered({ type = "electric-pole",
    position = own.position, radius = 120, force = self.force })) do
    if e.electric_network_id ~= own.electric_network_id then
      local d = (e.position.x - own.position.x) ^ 2 + (e.position.y - own.position.y) ^ 2
      if not best_d or d < best_d then best, best_d = e, d end
    end
  end
  if best then
    self:poles({ math.floor(own.position.x), math.floor(own.position.y) },
      { math.floor(best.position.x), math.floor(best.position.y) })
  end
end

-- The parts of a sink at `at`, as a layout relative to `at`.
local function sink_layout(dir)
  local s = STEP[dir]
  local side = ({ north = "east", south = "east", east = "south", west = "south" })[dir]
  local o = STEP[side]
  local back = ({ east = "west", south = "north" })[side]
  local l = {}
  -- Four steel chests hold the output of a line for all five stages.
  for k = 0, 3 do
    local x, y = s[1] * k, s[2] * k
    l[#l + 1] = { "transport-belt", x, y, dir }
    l[#l + 1] = { "fast-inserter", x + o[1], y + o[2], side, { from = back } }
    l[#l + 1] = { "steel-chest", x + 2 * o[1], y + 2 * o[2] }
  end
  l[#l + 1] = { "medium-electric-pole", -o[1], -o[2] }
  return l, { -o[1], -o[2] }
end

--- A sink at the end of a belt that runs towards `dir`. It has four more
-- belt tiles, each with a fast inserter into a chest at its side, and a pole.
-- That takes about 9 items a second. The sink goes in whole or not at
-- all. If it does not fit at `at`, it moves along the belt by up to 20
-- tiles, and a belt joins it. The next stage removes it with unsink and
-- carries the belt on from `at`.
function Build:sink(key, at, dir)
  if not at then return end
  local check = self:checker()
  -- The belt's own direction first. At a coast or a band, it can turn.
  local turns = ({ south = { "south", "east", "west" }, north = { "north", "east", "west" },
    east = { "east", "south", "north" }, west = { "west", "south", "north" } })[dir]
  for _, d in ipairs(turns) do
    local layout, pole_rel = sink_layout(d)
    local s = STEP[d]
    for off = 0, 20 do
      local spot = { at[1] + s[1] * off, at[2] + s[2] * off }
      if Place.fit(layout, spot, check)
        and (off == 0 or Place.route(at, d, off, check, TIERS, d ~= dir)) then
        -- The belt that joins the sink is part of it, so that unsink
        -- removes it too and the next stage finds the tiles free.
        local joint = off > 0 and self:belt(at, d, off, d ~= dir) or {}
        local parts = self:place(layout, spot) or {}
        for _, e in pairs(joint) do parts[#parts + 1] = e end
        self.anchor[key] = { at = at, dir = d, came = dir, parts = parts }
        self:link({ spot[1] + pole_rel[1], spot[2] + pole_rel[2] })
        return
      end
    end
  end
  log(string.format("showcase: no sink fits after %d,%d", at[1], at[2]))
  -- The next stage still carries the belt on from here.
  self.anchor[key] = { at = at, dir = dir, came = dir, parts = {} }
end

--- Remove a sink. Returns the tile where the belt can go on, the direction
-- that the sink took from there, and the direction the belt arrives from.
function Build:unsink(key)
  local sink = self.anchor[key]
  if not sink then return nil, nil, nil end
  for _, e in pairs(sink.parts) do
    if e and e.valid then e.destroy() end
  end
  return sink.at, sink.dir, sink.came
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

--- The densest spot of a resource near a tile. Of up to 100 samples, it takes
-- the one with the most of the resource within 5 tiles. Of those, it takes
-- the nearest. A lone tile of ore is no place for a mine.
function Build:ore(name, near, radius)
  local found = self.surface.find_entities_filtered({
    name = name, position = near, radius = radius or 200 })
  if #found == 0 then return nil end
  local best, best_n, best_d
  local step = math.max(1, math.floor(#found / 100))
  for i = 1, #found, step do
    local e = found[i]
    -- Skip a spot where a mine works already.
    local taken = self.surface.count_entities_filtered({
      type = "mining-drill", position = e.position, radius = 6 }) > 0
    local n = taken and -1 or self.surface.count_entities_filtered({
      name = name, position = e.position, radius = 5 })
    local d = (e.position.x - near[1]) ^ 2 + (e.position.y - near[2]) ^ 2
    if not best_n or n > best_n or (n == best_n and d < best_d) then
      best, best_n, best_d = e, n, d
    end
  end
  if best_n < 1 then return nil end
  return { math.floor(best.position.x), math.floor(best.position.y) }
end

local STATUS_NAME = {}
for name, value in pairs(defines.entity_status) do STATUS_NAME[value] = name end

--- Note each miner, furnace and crafting machine that works now. A machine
-- that waits part of the time, for space or for input, still works if it
-- finished something lately. So the showcase samples each machine during
-- the last 30 seconds of a warm-up, and working() counts each machine that
-- worked in any sample.
function Build:sample()
  self.recent = self.recent or {}
  for _, e in ipairs(self.built) do
    if e.valid and WORKING_TYPES[e.type] and e.status == defines.entity_status.working then
      self.recent[e.unit_number] = true
    end
  end
end

--- How many miners, furnaces and crafting machines worked in the samples
-- since the last call, out of all of them. Also a count of each status now,
-- such as no_power or full_output.
function Build:working()
  local n, total, by_status = 0, 0, {}
  local recent = self.recent or {}
  self.recent = {}
  for _, e in ipairs(self.built) do
    if e.valid and WORKING_TYPES[e.type] then
      total = total + 1
      if recent[e.unit_number] or e.status == defines.entity_status.working then
        n = n + 1
      end
      local name = STATUS_NAME[e.status] or tostring(e.status)
      by_status[name] = (by_status[name] or 0) + 1
    end
  end
  return n, total, by_status
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
