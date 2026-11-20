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

--- A straight belt of `length` tiles from `start` towards `dir`.
--
-- Where the game refuses a tile, an underground pair spans the gap. The
-- entrance goes on the last free tile, and the exit on the first free tile
-- after the gap. `tiers` is a list of {name, reach}, cheapest first. Reach
-- is the widest gap in tiles. Returns a list of {name, x, y, dir, kind}, or
-- nil if no tier spans a gap.
function Place.route(start, dir, length, can_place, tiers)
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
      local tier
      for _, t in ipairs(tiers) do
        if gap <= t[2] then tier = t[1] break end
      end
      local last = out[#out]
      if not last then return nil end
      out[#out] = { tier, last[2], last[3], dir, "input" }
      out[#out + 1] = { tier, x + d[1] * gap, y + d[2] * gap, dir, "output" }
      i = i + gap + 1
    end
  end
  return out
end

return Place
