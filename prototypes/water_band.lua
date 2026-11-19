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
-- they refuse a band tile. The copy looks the same as the water: the owner
-- chose a lake that shows no band.
--
-- mod/water_band.lua says which tiles are water, and names the copies.

local Water = require("mod.water_band")

local LAYER = "hattorio_band"

-- The lists that land tiles use to draw their transitions. Vulcanus draws a
-- lava edge from its own list, so a copy joins each list that has its
-- original.
local TRANSITION_LISTS = { "water_tile_type_names", "lava_tile_type_names" }

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
