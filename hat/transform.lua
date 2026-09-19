-- Affine transforms over the exact ring, carrying an integer denominator.
--
--   xf = { m = { a, b, c, d, e, f }, den = n }
--   (x, y) -> ( (a*x + b*y + c)/n , (d*x + e*y + f)/n )
--
-- REDUCTION IS LOAD-BEARING. Composition multiplies denominators, so without
-- reducing by gcd the denominator of an 11-level descent is den^11 and
-- overflows 2^53 almost immediately. With reduction the composed values stay
-- small, because hats land back on the clean kite lattice and the ugly
-- rationals cancel -- measured max 3.6e14 at depth 11, 24x inside 2^53.
--
-- Immutable: every operation returns a new table.

local E = require("hat.exact")

local T = {}

local function gcd(a, b)
  if a < 0 then a = -a end
  if b < 0 then b = -b end
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

function T.new(m, den)
  return { m = m, den = den or 1 }
end

T.IDENTITY = T.new({ E.ONE, E.ZERO, E.ZERO, E.ZERO, E.ONE, E.ZERO }, 1)

function T.from_ints(ints, den)
  local m = {}
  for i = 1, 6 do
    local o = (i - 1) * 4
    m[i] = E.new(ints[o + 1], ints[o + 2], ints[o + 3], ints[o + 4])
  end
  return T.new(m, den or 1)
end

--- Divide numerators and denominator by their common factor.
local function reduce(m, den)
  if den == 1 then return T.new(m, 1) end
  local g = den
  for i = 1, 6 do
    local e = m[i]
    for k = 1, 4 do
      if e[k] ~= 0 then
        g = gcd(g, e[k])
        if g == 1 then return T.new(m, den) end
      end
    end
  end
  if g <= 1 then return T.new(m, den) end
  local out = {}
  for i = 1, 6 do
    local e = m[i]
    out[i] = E.new(e[1] / g, e[2] / g, e[3] / g, e[4] / g)
  end
  return T.new(out, den / g)
end

function T.mul(x, y)
  local a, b, c, d, e, f = x.m[1], x.m[2], x.m[3], x.m[4], x.m[5], x.m[6]
  local A, B, C, D, EE, F = y.m[1], y.m[2], y.m[3], y.m[4], y.m[5], y.m[6]
  local cy = E.new(y.den, 0, 0, 0)
  local m = {
    E.add(E.mul(a, A), E.mul(b, D)),
    E.add(E.mul(a, B), E.mul(b, EE)),
    E.add(E.add(E.mul(a, C), E.mul(b, F)), E.mul(c, cy)),
    E.add(E.mul(d, A), E.mul(e, D)),
    E.add(E.mul(d, B), E.mul(e, EE)),
    E.add(E.add(E.mul(d, C), E.mul(e, F)), E.mul(f, cy)),
  }
  return reduce(m, x.den * y.den)
end

function T.apply_float(xf, px, py)
  local m, n = xf.m, xf.den
  local a, b, c = E.to_float(m[1]), E.to_float(m[2]), E.to_float(m[3])
  local d, e, f = E.to_float(m[4]), E.to_float(m[5]), E.to_float(m[6])
  return (a * px + b * py + c) / n, (d * px + e * py + f) / n
end

function T.origin_float(xf)
  return E.to_float(xf.m[3]) / xf.den, E.to_float(xf.m[6]) / xf.den
end

local function det_float(xf)
  local m = xf.m
  local a, b = E.to_float(m[1]), E.to_float(m[2])
  local d, e = E.to_float(m[4]), E.to_float(m[5])
  return (a * e - b * d) / (xf.den * xf.den)
end

function T.is_reflected(xf)
  return det_float(xf) < 0
end

function T.scale_float(xf)
  local dt = det_float(xf)
  if dt < 0 then dt = -dt end
  return math.sqrt(dt)
end

function T.max_coefficient(xf)
  local worst = xf.den
  for i = 1, 6 do
    local v = E.max_abs(xf.m[i])
    if v > worst then worst = v end
  end
  return worst
end

return T
