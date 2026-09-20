-- Affine transforms as six plain doubles.
--
--   xf = { a, b, c, d, e, f }
--   (x, y) -> (a*x + b*y + c, d*x + e*y + f)
--
-- DETERMINISM. Only + - * / and sqrt appear here. IEEE-754 requires those to
-- be correctly rounded, so they are bit-identical across platforms, and Lua's
-- interpreter runs each as its own VM instruction, so no compiler FMA
-- contraction can fuse them. Factorio 2.0 is x86-64 only, so there is no x87
-- 80-bit excess precision either. What must NEVER appear is math.sin,
-- math.cos, math.random or the ^ operator -- those differ between platforms
-- and a divergence between two clients is a desync.
--
-- ACCURACY. Measured against exact Z[phi][sqrt3] ground truth from the offline
-- pipeline, composition holds relative error at machine epsilon (5e-16) with
-- no growth in depth: at depth 12, covering 1.19e6 tiles, the absolute error
-- is 4e-10 tiles.
--
-- Immutable: every operation returns a new table.

local T = {}

T.IDENTITY = { 1, 0, 0, 0, 1, 0 }

function T.mul(x, y)
  local a, b, c, d, e, f = x[1], x[2], x[3], x[4], x[5], x[6]
  local A, B, C, D, E, F = y[1], y[2], y[3], y[4], y[5], y[6]
  return {
    a * A + b * D, a * B + b * E, a * C + b * F + c,
    d * A + e * D, d * B + e * E, d * C + e * F + f,
  }
end

function T.apply(xf, px, py)
  return xf[1] * px + xf[2] * py + xf[3],
         xf[4] * px + xf[5] * py + xf[6]
end

function T.origin(xf)
  return xf[3], xf[6]
end

local function det(xf)
  return xf[1] * xf[5] - xf[2] * xf[4]
end

function T.is_reflected(xf)
  return det(xf) < 0
end

function T.scale(xf)
  local d = det(xf)
  if d < 0 then d = -d end
  return math.sqrt(d)
end

return T
