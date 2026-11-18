-- Affine transforms as six plain doubles.
--
--   xf = { a, b, c, d, e, f }
--   (x, y) -> (a*x + b*y + c, d*x + e*y + f)
--
-- DETERMINISM. This file uses only + - * / and sqrt. IEEE-754 requires correct
-- rounding for these operations, so they give the same bits on every
-- platform. The Lua interpreter runs each one as a separate VM instruction, so
-- no compiler can contract two of them into an FMA. Factorio runs on 64-bit
-- x86 and ARM processors, which do double arithmetic without the 80-bit
-- excess precision of x87.
--
-- This file must NEVER use `math.sin`, `math.cos`, `math.random` or the `^`
-- operator. Their results differ between platforms, and a difference between
-- two clients is a desync.
--
-- ACCURACY. We measured composition against exact Z[phi][sqrt3] values from
-- the offline pipeline. The relative error stays at machine epsilon (5e-16)
-- and does not grow with depth. At depth 12, which covers 1.19e6 tiles, the
-- absolute error is 4e-10 tiles.
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
