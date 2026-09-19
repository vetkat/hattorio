-- Hat outline and world-space geometry.
--
-- Floats appear here, and only here, as LEAF QUERIES: bounding tests, point
-- containment, distance to an edge. They use nothing but + - * / and sqrt, all
-- of which are IEEE-deterministic across platforms, so two clients agree. What
-- they are NOT used for is composing transforms, where error would accumulate
-- across a deep descent -- that stays exact, in hat/exact.lua.

local E = require("hat.exact")
local T = require("hat.transform")
local DATA = require("data.hat_geometry")

local G = {}

local N = DATA.vertices

-- Decode the emitted outline: alternating x, y ring elements over a shared
-- denominator. The hat is a 13-gon in hatviz's hexPt basis.
G.OUTLINE = {}
for i = 1, N do
  local xv = DATA.outline[(i - 1) * 2 + 1]
  local yv = DATA.outline[(i - 1) * 2 + 2]
  G.OUTLINE[i] = {
    E.to_float(E.new(xv[1], xv[2], xv[3], xv[4])) / DATA.den,
    E.to_float(E.new(yv[1], yv[2], yv[3], yv[4])) / DATA.den,
  }
end

G.RADIUS = 0
for i = 1, N do
  local p = G.OUTLINE[i]
  local r = math.sqrt(p[1] * p[1] + p[2] * p[2])
  if r > G.RADIUS then G.RADIUS = r end
end

function G.polygon(xf, unit)
  local out = {}
  for i = 1, N do
    local p = G.OUTLINE[i]
    local x, y = T.apply_float(xf, p[1], p[2])
    out[i] = { x = x * unit, y = y * unit }
  end
  return out
end

function G.edges(xf, unit)
  local poly = G.polygon(xf, unit)
  local out = {}
  for i = 1, N do
    local a = poly[i]
    local b = poly[i % N + 1]
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
