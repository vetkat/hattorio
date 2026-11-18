-- Lazy descent over the substitution tree.
--
-- The descent returns only the hats that can touch the query box. So the cost
-- grows with the output, not with the size of the tiling.
--
-- The transforms are plain doubles (see hat/transform.lua). Composition and
-- pruning use only + - * / and sqrt, and IEEE-754 makes all of these
-- deterministic.
--
-- Each level has ITS OWN RULES. hatviz derives the metatile outlines for each
-- level from the geometry, so the outlines really are different at each
-- level. One rule table for every depth would be wrong.

local T = require("hat.transform")
local G = require("hat.geometry")
local I = require("hat.index")
local RULES = require("data.hat_rules")

local Ti = {}
Ti.__index = Ti

--- Tiles per kite unit that give hats of the given circumradius.
-- The level-0 placements have a factor of 0.5 (H_init and the others). So a
-- descent at `unit` gives hats with a circumradius of
-- hat_scale * unit * G.RADIUS. Callers must give the hat size they want and
-- let this function do the conversion.
function Ti.unit_for_hat_size(size)
  return size / (RULES.hat_scale * G.RADIUS)
end

--- Circumradius, in world units, of the hats a descent at `unit` produces.
function Ti.hat_size_for_unit(unit)
  return RULES.hat_scale * unit * G.RADIUS
end

--- The shallowest depth whose root covers `cover` world units at this unit.
-- Coverage grows linearly with the hat size, so a smaller hat needs a deeper
-- root. At the minimum size setting that is depth 13, and at the maximum it
-- is depth 11. Returns nil if the emitted data cannot reach that far.
function Ti.depth_covering(unit, cover)
  for d = 0, RULES.max_level do
    if RULES.radius[d].H * unit >= cover then return d end
  end
  return nil
end

--- opts = { unit = , depth = } or { unit = , cover = }
-- `cover` is the world radius that the tiling must fill. It uses the same
-- units as the box that goes to hats_in_box. Derive the depth once, when the
-- game creates the surface, and store it. Never calculate it again for each
-- chunk.
function Ti.new(opts)
  local self = setmetatable({}, Ti)
  self.unit = opts.unit or 1
  if not opts.depth and opts.cover then
    self.depth = assert(Ti.depth_covering(self.unit, opts.cover),
      "no emitted depth covers " .. opts.cover .. " at unit " .. self.unit)
  else
    self.depth = opts.depth or 3
  end
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

--- The smallest depth whose root covers a disc of the given radius, or nil.
function Ti:depth_for_radius(r)
  for d = 0, RULES.max_level do
    if RULES.radius[d][self.root_shape] * self.unit >= r then return d end
  end
  return nil
end

--- The circumradius of the root of this tiling, in world units.
--
-- CAUTION: this is a circumradius, and the root is a hexagonal metatile, not a
-- disc. A square region inside this circle is NOT fully tiled, because its
-- corners are outside the root. For `cover`, give a value well above the
-- half-diagonal of the region you need. Do not give its half-width.
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
  local cx, cy = T.origin(xf)
  cx, cy = cx * self.unit, cy * self.unit
  local k = T.scale(xf) * self.unit
  if circle_misses_box(cx, cy, RULES.radius[level][shape] * k, box) then
    return
  end

  local rules = RULES.levels[level][shape]
  local n = #path
  for i = 1, #rules do
    local r = rules[i]
    local child = T.mul(xf, r.xf)
    path[n + 1] = i - 1
    if level == 0 then
      -- the children at level 0 are the hats
      local px, py = T.origin(child)
      px, py = px * self.unit, py * self.unit
      local hr = G.RADIUS * T.scale(child) * self.unit
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

--- The hats that overlap an axis-aligned box in world space.
-- @param box { left=, top=, right=, bottom= }
function Ti:hats_in_box(box)
  local out = {}
  self:_descend(self.root_shape, self.root_xf, self.depth, box, {}, out)
  return out
end

return Ti
