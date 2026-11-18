-- This runs in data-final-fixes, so it sees every entity that the other mods
-- add.
--
-- Two prototypes collide only if they SHARE a collision layer. When buildable
-- structures get the band layer, the game itself refuses to place them on a
-- band. The preview is red, blueprints skip the tiles, construction bots never
-- try, and no ghosts remain. Rejection in a script would place the entity and
-- then remove it. That looks worse, and it needs four event handlers and ghost
-- cleanup to get close to this result.
--
-- CAREFUL: a prototype that does not declare collision_mask gets a default
-- for its type. A new mask would REPLACE that default and remove the normal
-- collisions of the entity. collision_mask_util.get_mask returns the explicit
-- mask or the default for the type. It is the only safe way to read the mask
-- in the data stage.

local cmu = require("__core__/lualib/collision-mask-util")

local LAYER = "hattorio_band"

-- Structures that players build. These are deliberately ABSENT, each for a
-- reason:
--   * rails, signals, ramps: the spec exempts rails, so trains still work
--   * vehicles: you must be able to drive across a band
--   * character: you must be able to walk across a band
--   * tree, cliff, resource and enemy types: map generation places them, and
--     they must be able to sit on a band. To block them would work against
--     terrain generation.
local BLOCKED_TYPES = {
  "accumulator", "agricultural-tower", "ammo-turret", "arithmetic-combinator",
  "artillery-turret", "assembling-machine", "asteroid-collector", "beacon",
  "boiler", "burner-generator", "cargo-bay", "cargo-landing-pad",
  "constant-combinator",
  "container", "decider-combinator", "display-panel",
  "electric-energy-interface", "electric-pole", "electric-turret",
  "fluid-turret", "furnace", "fusion-generator", "fusion-reactor", "gate",
  "generator", "heat-interface", "heat-pipe", "heating-tower",
  "infinity-container", "infinity-pipe", "inserter", "lab", "lamp",
  "land-mine", "lightning-attractor", "linked-belt", "linked-container",
  "loader", "loader-1x1", "logistic-container", "mining-drill",
  "offshore-pump", "pipe", "pipe-to-ground", "power-switch",
  "programmable-speaker", "pump", "radar", "reactor", "roboport",
  "rocket-silo", "selector-combinator", "simple-entity-with-owner",
  "solar-panel", "splitter", "storage-tank", "thruster", "train-stop",
  "transport-belt", "underground-belt", "valve", "wall",
}

local patched, skipped = 0, 0

for _, type_name in ipairs(BLOCKED_TYPES) do
  for name, proto in pairs(data.raw[type_name] or {}) do
    -- get_mask raises an error for a type that has no default, and a mod can
    -- add such a type. To fail open (buildable on bands) is better than to
    -- fail to load.
    local ok, mask = pcall(cmu.get_mask, proto)
    if ok and mask then
      mask.layers = mask.layers or {}
      mask.layers[LAYER] = true
      proto.collision_mask = mask
      patched = patched + 1
    else
      skipped = skipped + 1
      log("hattorio: could not read collision mask of " .. type_name .. "/" .. name)
    end
  end
end

log("hattorio: added " .. LAYER .. " to " .. patched .. " entity prototypes, skipped " .. skipped)

-- Floor tiles. Stone brick, concrete, landfill and, in Space Age, foundation
-- and the soils check the tile under them against a condition. The band tile
-- has only the band layer, so no condition matched it, and a player could
-- pave a band and then build on the new tile. The band layer in each
-- condition stops that.
local paving = 0
for _, prototypes_of_type in pairs(data.raw) do
  for _, proto in pairs(prototypes_of_type) do
    local tile = proto.place_as_tile
    if type(tile) == "table" then
      tile.condition.layers = tile.condition.layers or {}
      tile.condition.layers[LAYER] = true
      paving = paving + 1
    end
  end
end

log("hattorio: added " .. LAYER .. " to the tile condition of " .. paving .. " items")
