local planets = require("mod.planets")

-- A TilePrototype requires name, type, collision_mask, layer, variants and
-- map_color. Cloning a vanilla tile inherits variants, transitions and layer,
-- which is the expensive part to author.
--
-- walking_speed_modifier is cleared so it falls back to its default of 1: a
-- band must not grant the free walking bonus its base tile carries.
local function band_tile(name, base, color)
  local src = data.raw.tile[base]
  if not src then
    error("hattorio: base tile '" .. base .. "' does not exist")
  end
  local t = table.deepcopy(src)
  t.name = name
  t.map_color = color
  t.walking_speed_modifier = nil
  t.minable = nil
  t.mined_sound = nil
  t.can_be_part_of_blueprint = false
  t.autoplace = nil
  t.order = "z[hattorio]"
  t.localised_name = { "tile-name.hattorio-band" }
  -- Only the band layer: the tile itself blocks nothing else, so the
  -- character and vehicles pass over it.
  t.collision_mask = { layers = { hattorio_band = true } }
  return t
end

local tiles = {}
for planet, cfg in pairs(planets) do
  tiles[#tiles + 1] = band_tile("hattorio-band-" .. planet, cfg.base_tile, cfg.map_color)
  tiles[#tiles + 1] = band_tile("hattorio-band-" .. planet .. "-mirror",
                                cfg.base_tile, cfg.mirror_color)
end

data:extend(tiles)
