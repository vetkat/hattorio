-- Lazy descent over the substitution tree.
--
-- Emits only hats that could touch the query box, so cost is proportional to
-- output rather than to the size of the tiling.
--
-- Exact ring arithmetic composes the transforms, because error there would
-- accumulate across the descent and eventually split a shared edge. Pruning is
-- float-only, which is safe: it uses + - * / and sqrt, all IEEE-deterministic.
--
-- Rules are indexed BY LEVEL. hatviz derives each level's metatile outlines
-- geometrically, so they genuinely differ level to level; a single rule table
-- reused at every depth would be wrong.

local T = require("hat.transform")
local G = require("hat.geometry")
local I = require("hat.index")
local RULES = require("data.hat_rules")

local Ti = {}
Ti.__index = Ti

function Ti.new(opts)
  local self = setmetatable({}, Ti)
  self.unit = opts.unit or 1
  self.depth = opts.depth or 3
  self.root_shape = opts.root_shape or "H"
  self.root_xf = opts.root_xf or T.IDENTITY
  assert(self.depth >= 0 and self.depth <= RULES.max_level,
         "depth " .. tostring(self.depth) .. " outside generated data (0.." ..
         RULES.max_level .. ")")
  return self
end

function Ti.max_depth()
  return RULES.max_level
end

-- Deepest descent whose arithmetic is exact in Lua 5.2 doubles.
--
-- The per-level rules carry numerators up to 1.4e14 at level 6, so composing
-- two of them produces a RAW product near 1e28 -- long past 2^53 -- even
-- though the reduced result is only ~1e9. Reducing afterwards is too late, and
-- cross-reducing first does not help: the operands share no common factor
-- (measured gcd 1), because the cancellation is additive, inside the sums,
-- rather than multiplicative.
--
-- Measured raw-product peaks along random descents:
--     depth 4   3.9e13   OK
--     depth 5   5.7e16   overflow
--     depth 6   2.3e20   overflow
--
-- Going deeper needs either wider integers (a 106-bit pair covers depth 6) or
-- the self-similar rule set above a junction level. See the spec.
function Ti.safe_depth()
  return 4
end

--- Smallest depth whose root covers a disc of the given radius, or nil.
function Ti:depth_for_radius(r)
  for d = 0, RULES.max_level do
    if RULES.radius[d][self.root_shape] * self.unit >= r then return d end
  end
  return nil
end

--- Radius in world units covered by this tiling's root.
function Ti:coverage()
  return RULES.radius[self.depth][self.root_shape] * self.unit
end

local function circle_misses_box(cx, cy, rad, box)
  local dx = box.left - cx
  local dx2 = cx - box.right
  if dx2 > dx then dx = dx2 end
  if dx < 0 then dx = 0 end
  local dy = box.top - cy
  local dy2 = cy - box.bottom
  if dy2 > dy then dy = dy2 end
  if dy < 0 then dy = 0 end
  return dx * dx + dy * dy > rad * rad
end

function Ti:_descend(shape, xf, level, box, path, out)
  local cx, cy = T.origin_float(xf)
  cx, cy = cx * self.unit, cy * self.unit
  local k = T.scale_float(xf) * self.unit
  if circle_misses_box(cx, cy, RULES.radius[level][shape] * k, box) then
    return
  end

  local rules = RULES.levels[level][shape]
  local n = #path
  for i = 1, #rules do
    local r = rules[i]
    local child = T.mul(xf, T.from_ints(r.xf, r.den))
    path[n + 1] = i - 1
    if level == 0 then
      -- level-0 children are the hats themselves
      local px, py = T.origin_float(child)
      px, py = px * self.unit, py * self.unit
      local hr = G.RADIUS * T.scale_float(child) * self.unit
      if not circle_misses_box(px, py, hr, box) then
        out[#out + 1] = {
          xf = child,
          reflected = T.is_reflected(child),
          path = I.encode(path),
        }
      end
    else
      self:_descend(r.shape, child, level - 1, box, path, out)
    end
    path[n + 1] = nil
  end
end

--- Hats overlapping an axis-aligned world-space box.
-- @param box { left=, top=, right=, bottom= }
function Ti:hats_in_box(box)
  local out = {}
  self:_descend(self.root_shape, self.root_xf, self.depth, box, {}, out)
  return out
end

return Ti
