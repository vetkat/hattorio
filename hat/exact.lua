-- Exact arithmetic in Z[phi][sqrt3].
--
-- An element is { a, b, c, d } meaning (a + b*phi) + (c + d*phi)*sqrt(3),
-- with all four components integers and phi^2 = phi + 1, sqrt(3)^2 = 3.
--
-- Integers only: Lua 5.2 has no integer subtype, so every value here must stay
-- inside 2^53 to be exact. There is deliberately NO division, which makes every
-- operation total -- there is no divide-by-zero case to define.
--
-- Values are immutable. Every function returns a new table and none mutates an
-- argument, so a transform may be shared freely across the descent.
--
-- No math.sin, math.cos or the ^ operator appears here: those are not
-- deterministic across platforms, and a divergence between two Factorio
-- clients is a desync.

local E = {}

local PHI = (1 + math.sqrt(5)) / 2
local SQRT3 = math.sqrt(3)

function E.new(a, b, c, d)
  return { a or 0, b or 0, c or 0, d or 0 }
end

E.ZERO  = E.new(0, 0, 0, 0)
E.ONE   = E.new(1, 0, 0, 0)
E.PHI   = E.new(0, 1, 0, 0)
E.SQRT3 = E.new(0, 0, 1, 0)

function E.add(x, y)
  return { x[1] + y[1], x[2] + y[2], x[3] + y[3], x[4] + y[4] }
end

function E.sub(x, y)
  return { x[1] - y[1], x[2] - y[2], x[3] - y[3], x[4] - y[4] }
end

function E.neg(x)
  return { -x[1], -x[2], -x[3], -x[4] }
end

-- Q(phi): (p + q phi)(r + s phi) = (pr + qs) + (ps + qr + qs) phi
local function q5mul(p, q, r, s)
  return p * r + q * s, p * s + q * r + q * s
end

function E.mul(x, y)
  -- (X + Y sqrt3)(U + V sqrt3) = (XU + 3YV) + (XV + YU) sqrt3
  local xu1, xu2 = q5mul(x[1], x[2], y[1], y[2])
  local yv1, yv2 = q5mul(x[3], x[4], y[3], y[4])
  local xv1, xv2 = q5mul(x[1], x[2], y[3], y[4])
  local yu1, yu2 = q5mul(x[3], x[4], y[1], y[2])
  return {
    xu1 + 3 * yv1, xu2 + 3 * yv2,
    xv1 + yu1,     xv2 + yu2,
  }
end

function E.eq(x, y)
  return x[1] == y[1] and x[2] == y[2] and x[3] == y[3] and x[4] == y[4]
end

function E.is_zero(x)
  return x[1] == 0 and x[2] == 0 and x[3] == 0 and x[4] == 0
end

function E.to_float(x)
  return (x[1] + x[2] * PHI) + (x[3] + x[4] * PHI) * SQRT3
end

function E.max_abs(x)
  local m = 0
  for i = 1, 4 do
    local v = x[i]
    if v < 0 then v = -v end
    if v > m then m = v end
  end
  return m
end

function E.tostring(x)
  return string.format("(%d+%dphi)+(%d+%dphi)r3", x[1], x[2], x[3], x[4])
end

return E
