-- The band copies of the water tiles (issue #21).
--
-- prototypes/water_band.lua makes the copies in the data stage. The painter
-- places them at band positions over water. The tests check both. They all
-- use this module, so the rule and the names cannot drift apart.
--
-- Pure: this module does not use the Factorio API.

local Water = {}

local PREFIX = "hattorio-band-water-"

--- The planets whose band copies are darker. Most building there is on the
-- ocean, so the band must show over it.
Water.DARK_PLANETS = { "aquilo", "fulgora" }

--- The set of tiles that the dark planets place. gen_of(planet) returns the
-- map_gen_settings of a planet, or nil. The data stage reads them from
-- data.raw, and the tests from the prototypes.
function Water.dark_tiles(gen_of)
  local dark = {}
  for _, planet in ipairs(Water.DARK_PLANETS) do
    local gen = gen_of(planet)
    local tiles = gen and gen.autoplace_settings and gen.autoplace_settings.tile
    for name in pairs(tiles and tiles.settings or {}) do dark[name] = true end
  end
  return dark
end

--- True for the collision layers of a water tile. Out-of-map and the empty
-- space under a space platform also collide with water_tile, but they are
-- not water.
function Water.is_water(layers)
  return layers.water_tile == true and not layers.out_of_map and not layers.empty_space
end

--- The name of the band copy of a water tile.
function Water.copy_name(name)
  return PREFIX .. name
end

--- The name of the water tile that a band copy copies, or nil.
function Water.original(name)
  if name:sub(1, #PREFIX) == PREFIX then return name:sub(#PREFIX + 1) end
  return nil
end

return Water
