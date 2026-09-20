-- A layer the band tiles carry and buildings are given in data-final-fixes.
--
-- Two prototypes collide only if they SHARE a layer, so the character,
-- vehicles and rails -- which never receive this one -- cross bands freely,
-- while anything that does receive it cannot be placed on one. The game then
-- refuses the placement natively: red preview, blueprints skip the tiles,
-- construction bots never attempt them.
data:extend({
  { type = "collision-layer", name = "hattorio_band" },
})
