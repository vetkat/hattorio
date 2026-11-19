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
    copies[#copies + 1] = copy
    -- Land tiles draw their shore transitions to the tiles in this list.
    table.insert(water_tile_type_names, copy.name)
  end
end

data:extend(copies)

log(string.format("hattorio: %d water tiles get a band copy", #copies))
