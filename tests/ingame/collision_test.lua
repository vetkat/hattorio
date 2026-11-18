-- The band layer must stop every way to build on a band. These tests read
-- the final prototypes, so they also catch a type that a new Factorio
-- release adds. watch.yml runs them on each new release.

local LAYER = "hattorio_band"

-- The types that may stand on a band, each for a reason:
--   rails, signals, ramps and supports: rails cross bands, so trains work
--   vehicles: you drive across a band
--   robots: they fly
--   the space platform hub: it exists only on a space platform
local EXEMPT = {}
for _, t in ipairs({
  "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail",
  "legacy-straight-rail", "legacy-curved-rail", "elevated-straight-rail",
  "elevated-curved-rail-a", "elevated-curved-rail-b",
  "elevated-half-diagonal-rail", "rail-ramp", "rail-support", "rail-signal",
  "rail-chain-signal",
  "car", "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon",
  "infinity-cargo-wagon", "spider-vehicle",
  "construction-robot", "logistic-robot",
  "space-platform-hub",
}) do EXEMPT[t] = true end

test("no item can place a tile on a band", function()
  local open = {}
  for name, item in pairs(prototypes.item) do
    local tile = item.place_as_tile_result
    if tile and not tile.condition.layers[LAYER] then open[#open + 1] = name end
  end
  table.sort(open)
  assert(#open == 0, "these items can pave a band: " .. table.concat(open, ", "))
end)

test("every structure that a player builds collides with the band", function()
  local open = {}
  for name, entity in pairs(prototypes.entity) do
    if entity.items_to_place_this and entity.has_flag("player-creation")
      and not entity.hidden and not EXEMPT[entity.type]
      and not entity.collision_mask.layers[LAYER] then
      open[#open + 1] = entity.type .. "/" .. name
    end
  end
  table.sort(open)
  assert(#open == 0, "these can stand on a band: " .. table.concat(open, ", "))
end)
