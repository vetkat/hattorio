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

--- The dark tile whose look a texture ocean borrows, or nil.
--
-- A copy that a texture draws, such as the shallow oil of Fulgora, gets
-- darker by a tint. The tint stops at the edge of each tile, so the band
-- shows as square steps. Such a copy borrows the look of a shader ocean
-- instead: a dark tile with the same fluid that a shader draws. Of those, it
-- takes the lowest layer, and then the first name. `tiles` maps a name to a
-- tile with `fluid`, `layer` and `effect`.
function Water.look_donor(name, tiles, dark)
  local tile = tiles[name]
  if not tile or tile.effect then return nil end
  local best, best_tile
  for other, t in pairs(tiles) do
    if dark[other] and t.effect and t.fluid == tile.fluid then
      if not best_tile or t.layer < best_tile.layer
        or (t.layer == best_tile.layer and other < best) then
        best, best_tile = other, t
      end
    end
  end
  return best
end

local function copy_table(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = copy_table(v) end
  return out
end

-- The shader variations that take their colour from images, not from the
-- effect colour of the tile.
local IMAGE_SHADERS = { oil = true }

--- A darker copy of a shader that takes its colour from images, or nil for
-- any other shader.
--
-- The oil shader of Fulgora is one. A darker effect colour does not change
-- it. The copy turns off the highlights, the
-- foam and the reflections instead. A shader that takes its colour from the
-- tile, such as the ammonia ocean of Aquilo, needs no copy.
function Water.dark_effect(fx)
  if not (fx and fx.water and IMAGE_SHADERS[fx.water.shader_variation]) then return nil end
  local out = copy_table(fx)
  out.name = "hattorio-band-dark-" .. fx.name
  out.water.specular_lightness = { 0.5, 0.5, 0.5 }
  out.water.foam_color_multiplier = 0
  out.water.dark_threshold = { 0, 0 }
  out.water.reflection_threshold = { 0, 0 }
  return out
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
