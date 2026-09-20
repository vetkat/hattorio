-- data-final-fixes, so this sees every entity every other mod has added.
--
-- Two prototypes collide only if they SHARE a collision layer. Giving
-- buildable structures the band layer makes the game refuse to place them on
-- a band natively: red preview, blueprints skip the tiles, construction bots
-- never attempt them, and no ghosts are left behind. Script-side rejection
-- would place the entity and then remove it, which is visibly worse and needs
-- four event handlers plus ghost cleanup to approximate this.
--
-- CAREFUL: a prototype that does not declare collision_mask inherits a
-- per-type default. Assigning a fresh mask would WIPE that default and strip
-- the entity of its normal collisions. collision_mask_util.get_mask returns
-- the explicit mask or the type default, which is the only safe way to read
-- it in the data stage.

local cmu = require("__core__/lualib/collision-mask-util")

local LAYER = "hattorio_band"

-- Player-built structures. Deliberately ABSENT, each for a reason:
--   * rails, signals, ramps  -- the spec exempts rails so trains still work
--   * vehicles               -- you must be able to drive across a band
--   * character              -- you must be able to walk across a band
--   * tree, cliff, resource, enemy types -- placed by map generation, and
--     must be free to sit on a band; blocking them would fight terrain gen
local BLOCKED_TYPES = {
  "accumulator", "agricultural-tower", "ammo-turret", "arithmetic-combinator",
  "artillery-turret", "assembling-machine", "asteroid-collector", "beacon",
  "boiler", "burner-generator", "cargo-landing-pad", "constant-combinator",
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
    -- get_mask errors on a type it has no default for, which a mod can
    -- introduce. Failing open (buildable on bands) beats failing to load.
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
