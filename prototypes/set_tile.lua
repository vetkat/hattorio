-- This runs in data-final-fixes, so it sees the trigger effects that the
-- other mods add.
--
-- A "set-tile" trigger effect places tiles around a point. On Aquilo, a
-- crude oil, lithium brine or fluorine vent stamps snow and ice up to about
-- 8 tiles around itself when the map generator places it. A nuke places a
-- crater, ocean or lava.
--
-- The stamp of a resource in a new chunk can reach into an older chunk next
-- to it. The mod painted the bands of that chunk earlier, and the stamp
-- replaced some of them. Issue #19 has the details.
--
-- The game does not replace a tile that collides with the
-- tile_collision_mask of the effect. So each set-tile effect gets the band
-- layer, and no stamp replaces a band tile. The tiles around a band still
-- get the stamp.

local LAYER = "hattorio_band"

local patched = 0

local function patch(effect)
  local mask = effect.tile_collision_mask or {}
  mask.layers = mask.layers or {}
  mask.layers[LAYER] = true
  effect.tile_collision_mask = mask
  patched = patched + 1
end

-- A trigger effect can sit at any depth in a prototype: in created_effect,
-- in an action of a projectile, in a list of effects. So the walk visits
-- every table once. The seen set also stops it at a table that two
-- prototypes share. A sprite or a sound has a filename, and it holds no
-- trigger effect, so the walk stops there. Most of the tables in data.raw
-- are graphics.
local seen = {}

local function walk(t)
  if seen[t] or t.filename or t.filenames then return end
  seen[t] = true
  if t.type == "set-tile" then patch(t) end
  for _, v in pairs(t) do
    if type(v) == "table" then walk(v) end
  end
end

for _, protos in pairs(data.raw) do
  for _, proto in pairs(protos) do
    walk(proto)
  end
end

log(string.format("hattorio: %d set-tile effects skip band tiles", patched))
