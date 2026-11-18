-- A collision layer. The band tiles have it, and data-final-fixes gives it to
-- buildings.
--
-- Two prototypes collide only if they SHARE a layer. The character, vehicles
-- and rails never get this layer, so they cross bands freely. The game itself
-- refuses to place anything with this layer on a band. The preview is red,
-- blueprints skip the tiles, and construction bots never try to build there.
data:extend({
  { type = "collision-layer", name = "hattorio_band" },
})
