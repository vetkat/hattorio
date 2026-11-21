-- This runs in data-final-fixes, so it sees the water tiles that the other
-- mods add.
--
-- The painter does not fill water, so lakes keep their shores. But a band
-- position over water then had no band layer. Landfill could fill it, and a
-- set-tile stamp could turn it into land. Either way the band got a gap that
-- you could build across. Issue #21 has the details.
--
-- So each water tile gets a copy with the band layer. The painter places the
-- copy at band positions over water. The floor-tile condition and the
-- set-tile mask already contain the band layer, so they refuse the copy as
-- they refuse a band tile. On most planets the copy looks the same as the
-- water: the owner chose a lake that shows no band.
--
-- mod/water_band.lua says which tiles are water, and names the copies.

local Water = require("mod.water_band")

local LAYER = "hattorio_band"

-- The lists that land tiles use to draw their transitions. Vulcanus draws a
-- lava edge from its own list, so a copy joins each list that has its
-- original.
local TRANSITION_LISTS = { "water_tile_type_names", "lava_tile_type_names" }

-- Most building on Aquilo and Fulgora happens on the ocean. There, a band
-- that does not show would refuse ice platform and foundation with no hint.
-- So the copies of the tiles that these planets place are darker, and the
-- band shows as a dark line. On the other planets the copy looks the same as
-- the water. The owner chose both looks after a spike.
local DARKNESS = 0.35

local dark = Water.dark_tiles(function(planet)
  return data.raw.planet[planet] and data.raw.planet[planet].map_gen_settings
end)

-- A colour can be a table with r, g, b and a, or an array. Its values are
-- 0 to 1, or 0 to 255. The result keeps that form, and alpha stays as it
-- is.
local function darker(colour)
  if not colour then return nil end
  local out = {}
  for k, v in pairs(colour) do
    out[k] = (k == "a" or k == 4) and v or v * DARKNESS
  end
  return out
end

-- The band over the ocean of Aquilo and Fulgora shows as a dark line that
-- blends into the ocean. A shader ocean merges with its copy and gets darker
-- colours, and a darker shader where Water.dark_effect gives one. A texture
-- ocean borrows the look of a shader ocean (Water.look_donor). With neither,
-- a tint is the only way to darken a copy.
local function darken(copy, name)
  copy.map_color = darker(copy.map_color)
  local donor = Water.look_donor(name, data.raw.tile, dark)
  if not donor and not copy.effect then
    copy.tint = { r = DARKNESS, g = DARKNESS, b = DARKNESS, a = 1 }
    return
  end
  if donor then
    local src = data.raw.tile[donor]
    -- Only the fields that draw the tile. The others, such as the collision
    -- mask, the fluid and the name, stay those of the copy.
    for _, key in ipairs({ "variants", "transitions", "transitions_between_transitions",
      "layer", "layer_group", "effect", "effect_color", "effect_color_secondary" }) do
      copy[key] = table.deepcopy(src[key])
    end
    -- In the lower layer of the donor, the original draws its shore onto
    -- the copy. A merge would hide that shore.
    copy.transition_merges_with_tile = nil
  end
  copy.effect_color = darker(copy.effect_color)
  copy.effect_color_secondary = darker(copy.effect_color_secondary)
  local fx = Water.dark_effect(data.raw["tile-effect"][copy.effect])
  if fx then
    if not data.raw["tile-effect"][fx.name] then data:extend({ fx }) end
    copy.effect = fx.name
  end
end

local function lists_with(name)
  local found = {}
  for _, list_name in ipairs(TRANSITION_LISTS) do
    local list = _G[list_name]
    if list then
      for _, entry in ipairs(list) do
        if entry == name then found[#found + 1] = list break end
      end
    end
  end
  return found
end

local copies = {}
for name, tile in pairs(data.raw.tile) do
  local layers = tile.collision_mask and tile.collision_mask.layers or {}
  if Water.is_water(layers) and not name:find("^hattorio%-") then
    local copy = table.deepcopy(tile)
    copy.name = Water.copy_name(name)
    copy.collision_mask.layers[LAYER] = true
    -- Merge with the original, so that no seam shows inside a lake.
    copy.transition_merges_with_tile = name
    copy.autoplace = nil
    copy.can_be_part_of_blueprint = false
    -- The name of the original, and no entry of its own in Factoriopedia.
    copy.localised_name = tile.localised_name or { "tile-name." .. name }
    copy.localised_description = tile.localised_description or { "tile-description." .. name }
    copy.factoriopedia_alternative = name
    if dark[name] then
      darken(copy, name)
    end
    -- Not mineable. Mining would bring back the plain water under it.
    copy.minable = nil
    copy.mined_sound = nil
    copy.placeable_by = nil
    copies[#copies + 1] = copy
    for _, list in ipairs(lists_with(name)) do
      table.insert(list, copy.name)
    end
  end
end

data:extend(copies)

log(string.format("hattorio: %d water tiles get a band copy", #copies))
