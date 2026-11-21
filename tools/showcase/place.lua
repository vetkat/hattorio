-- Placement for the showcase bases: where a layout of buildings fits, and
-- how a belt crosses a band.
--
-- Pure: this module does not use the Factorio API. The caller passes
-- can_place(name, x, y, direction), which asks the game. A band refuses
-- every building, so a layout that fits stands inside a cell.

local Place = {}

local DIRECTIONS = {
  east = { 1, 0 }, west = { -1, 0 }, south = { 0, 1 }, north = { 0, -1 },
}

--- count positions: the centre first, then square rings outward, `step`
-- apart.
function Place.spiral(cx, cy, step, count)
  local out = { { cx, cy } }
  local ring = 1
  while #out < count do
    for dy = -ring, ring do
      for dx = -ring, ring do
        if (math.abs(dx) == ring or math.abs(dy) == ring) and #out < count then
          out[#out + 1] = { cx + dx * step, cy + dy * step }
        end
      end
    end
    ring = ring + 1
  end
  return out
end

--- True if every building of the layout can stand at its offset from the
-- origin.
function Place.fit(layout, origin, can_place)
  for _, e in ipairs(layout) do
    if not can_place(e[1], origin[1] + e[2], origin[2] + e[3], e[4]) then
      return false
    end
  end
  return true
end

--- The first spiral position where the layout fits, or nil after `tries`.
function Place.find(layout, centre, step, tries, can_place)
  for _, origin in ipairs(Place.spiral(centre[1], centre[2], step, tries)) do
    if Place.fit(layout, origin, can_place) then return origin end
  end
  return nil
end

--- The first origin on the line from `start` towards `dir`, between
-- `from` and `to` tiles away, where the layout fits. Also returns the
-- distance. A belt can then run straight from `start` to that origin.
--
-- With `tiers`, an origin counts only if the belt to it has a route.
-- `covers` works as for find_bent: the belt must not cross the block, and
-- `turned` as for route.
function Place.find_along(layout, start, dir, from, to, can_place, tiers, covers, turned)
  local d = DIRECTIONS[dir]
  for k = from, to do
    local origin = { start[1] + d[1] * k, start[2] + d[2] * k }
    if Place.fit(layout, origin, can_place) then
      local under = covers and covers(origin)
      local check = can_place
      if under then
        check = function(name, x, y, dd) return can_place(name, x, y, dd) and not under(x, y) end
      end
      if not tiers or Place.route(start, dir, k, check, tiers, turned) then return origin, k end
    end
  end
  return nil
end

local SIDES = {
  north = { "east", "west" }, south = { "east", "west" },
  east = { "south", "north" }, west = { "south", "north" },
}

--- Like find_along, but the belt may bend once: `k` tiles from `start`
-- towards `dir`, then `j` tiles to one side, to the origin. Returns the
-- origin, k, the side and j, or nil.
--
-- The builder places the block before its belt, so the belt must not cross
-- it.
--
-- `covers(origin)` returns a function(x, y) that is true for the tiles that
-- the block covers at that origin.
function Place.find_bent(layout, start, dir, max_k, max_j, can_place, tiers, covers, turned)
  local d = DIRECTIONS[dir]
  for k = 2, max_k do
    local px, py = start[1] + d[1] * k, start[2] + d[2] * k
    for _, side in ipairs(SIDES[dir]) do
      local s = DIRECTIONS[side]
      for j = 2, max_j do
        local origin = { px + s[1] * j, py + s[2] * j }
        if Place.fit(layout, origin, can_place) then
          local under = covers and covers(origin)
          local check = can_place
          if under then
            check = function(name, x, y, dd)
              return can_place(name, x, y, dd) and not under(x, y)
            end
          end
          if not tiers or (Place.route(start, dir, k, check, tiers, turned)
            and Place.route({ px, py }, side, j, check, tiers, true)) then
            return origin, k, side, j
          end
        end
      end
    end
  end
  return nil
end

--- A straight belt of `length` tiles from `start` towards `dir`.
--
-- Where the game refuses a tile, an underground pair spans the gap. The
-- entrance goes on the last free tile, and the exit on the first free tile
-- after the gap. `tiers` is a list of {name, reach}, cheapest first. Reach
-- is the widest gap in tiles. Returns a list of {name, x, y, dir, kind}, or
-- nil if no tier spans a gap.
--
-- `turned` is true when the belt arrives at `start` from another direction.
-- An underground entrance takes items from the side on one lane only, so
-- then the first tile cannot be an entrance.
function Place.route(start, dir, length, can_place, tiers, turned)
  local d = DIRECTIONS[dir]
  local out = {}
  local i = 0
  while i < length do
    local x, y = start[1] + d[1] * i, start[2] + d[2] * i
    if can_place("transport-belt", x, y, dir) then
      out[#out + 1] = { "transport-belt", x, y, dir }
      i = i + 1
    else
      local gap = 0
      while not can_place("transport-belt", x + d[1] * gap, y + d[2] * gap, dir) do
        gap = gap + 1
        if gap > tiers[#tiers][2] then return nil end
      end
      -- The exit must stay inside the route, before the place it leads to.
      if i + gap > length - 1 then return nil end
      local tier
      for _, t in ipairs(tiers) do
        if gap <= t[2] then tier = t[1] break end
      end
      local last = out[#out]
      if not last or (turned and #out == 1) then return nil end
      out[#out] = { tier, last[2], last[3], dir, "input" }
      out[#out + 1] = { tier, x + d[1] * gap, y + d[2] * gap, dir, "output" }
      i = i + gap + 1
    end
  end
  return out
end

return Place
