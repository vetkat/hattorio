-- Hat outline and world-space geometry.
--
-- The hat is a 13-gon (hatviz's hat_outline in the hexPt basis), not the
-- 14-gon the original scaffold carried. H_init indexes hat_outline[5], [7],
-- [9] and [11], so a wrong vertex list silently produces wrong placements.

local T = require("hat.transform")
local DATA = require("data.hat_geometry")

local G = {}

G.N = DATA.vertices
G.OUTLINE = DATA.outline
G.RADIUS = DATA.circumradius

function G.polygon(xf, unit)
  local out = {}
  for i = 1, G.N do
    local p = G.OUTLINE[i]
    local x, y = T.apply(xf, p[1], p[2])
    out[i] = { x = x * unit, y = y * unit }
  end
  return out
end

function G.edges(xf, unit)
  local poly = G.polygon(xf, unit)
  local out = {}
  for i = 1, G.N do
    local a, b = poly[i], poly[i % G.N + 1]
    out[i] = { a.x, a.y, b.x, b.y }
  end
  return out
end

function G.point_in_polygon(px, py, poly)
  local inside = false
  local n = #poly
  local j = n
  for i = 1, n do
    local a, b = poly[i], poly[j]
    if (a.y > py) ~= (b.y > py) then
      local t = (py - a.y) / (b.y - a.y)
      if px < a.x + t * (b.x - a.x) then inside = not inside end
    end
    j = i
  end
  return inside
end

function G.dist_to_segment(px, py, x1, y1, x2, y2)
  local vx, vy = x2 - x1, y2 - y1
  local l2 = vx * vx + vy * vy
  local t = 0
  if l2 > 0 then
    t = ((px - x1) * vx + (py - y1) * vy) / l2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
  end
  local dx, dy = px - (x1 + t * vx), py - (y1 + t * vy)
  return math.sqrt(dx * dx + dy * dy)
end

return G
