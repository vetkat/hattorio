-- The band layer must stop every way to build on a band. These tests read
-- the final prototypes, so they also catch a type that a new Factorio
-- release adds. watch.yml runs them on each new release.

local Water = require("mod.water_band")

local LAYER = "hattorio_band"

-- The types that may stand on a band, each for a reason:
--   rails, signals, ramps and supports: rails cross bands, so trains work
--   vehicles: you drive across a band
--   robots: they fly
--   the space platform hub: it exists only on a space platform
local EXEMPT = {}
for _, t in ipairs({
  "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail",
  "legacy-straight-rail", "legacy-curved-rail", "elevated-straight-rail",
  "elevated-curved-rail-a", "elevated-curved-rail-b",
  "elevated-half-diagonal-rail", "rail-ramp", "rail-support", "rail-signal",
  "rail-chain-signal",
  "car", "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon",
  "infinity-cargo-wagon", "spider-vehicle",
  "construction-robot", "logistic-robot",
  "space-platform-hub",
}) do EXEMPT[t] = true end

test("no item can place a tile on a band", function()
  local open = {}
  for name, item in pairs(prototypes.item) do
    local tile = item.place_as_tile_result
    if tile and not tile.condition.layers[LAYER] then open[#open + 1] = name end
  end
  table.sort(open)
  assert(#open == 0, "these items can pave a band: " .. table.concat(open, ", "))
end)

test("every structure that a player builds collides with the band", function()
  local open = {}
  for name, entity in pairs(prototypes.entity) do
    if entity.items_to_place_this and entity.has_flag("player-creation")
      and not entity.hidden and not EXEMPT[entity.type]
      and not entity.collision_mask.layers[LAYER] then
      open[#open + 1] = entity.type .. "/" .. name
    end
  end
  table.sort(open)
  assert(#open == 0, "these can stand on a band: " .. table.concat(open, ", "))
end)

-- Issue #21: a band position over water needs the band layer too, or
-- landfill opens a gap.
test("every water tile has a band copy", function()
  local missing = {}
  for name, tile in pairs(prototypes.tile) do
    if Water.is_water(tile.collision_mask.layers) and not name:find("^hattorio%-")
      and not prototypes.tile[Water.copy_name(name)] then
      missing[#missing + 1] = name
    end
  end
  table.sort(missing)
  assert(#missing == 0, "no band copy for: " .. table.concat(missing, ", "))
end)

-- The tiles that Aquilo and Fulgora place. Most building there is on the
-- ocean, so the band copies of their water are darker and show the band.
local DARK = Water.dark_tiles(function(planet)
  local location = prototypes.space_location[planet]
  return location and location.map_gen_settings
end)

test("a band copy keeps its water and adds the band layer", function()
  local copies = 0
  for name, copy in pairs(prototypes.tile) do
    local original = Water.original(name)
    if original then
      copies = copies + 1
      local src = prototypes.tile[original]
      assert(copy.collision_mask.layers[LAYER], name .. " has no band layer")
      for layer in pairs(src.collision_mask.layers) do
        assert(copy.collision_mask.layers[layer], name .. " lost " .. layer)
      end
      assert((copy.fluid and copy.fluid.name) == (src.fluid and src.fluid.name),
        name .. " has another fluid")
      if not DARK[original] then
        assert(copy.map_color.r == src.map_color.r and copy.map_color.g == src.map_color.g
          and copy.map_color.b == src.map_color.b, name .. " has another map colour")
      end
      assert(not copy.autoplace_specification, name .. " autoplaces")
      assert(copy.localised_name[1] == src.localised_name[1], name .. " has no name of its own")
      assert(not copy.mineable_properties.minable, name .. " is mineable")
      assert(copy.factoriopedia_alternative and copy.factoriopedia_alternative.name == original,
        name .. " has its own Factoriopedia entry")
    end
  end
  assert(copies > 0, "no band copies exist")
end)

tags("space-age")
test("the band copies of the Aquilo and Fulgora oceans are darker", function()
  for _, original in ipairs({ "ammoniacal-ocean", "brash-ice", "oil-ocean-deep" }) do
    assert(DARK[original], original .. " is not a tile of Aquilo or Fulgora")
  end
  local checked = 0
  for original in pairs(DARK) do
    local copy = prototypes.tile[Water.copy_name(original)]
    if copy then
      local a, b = prototypes.tile[original].map_color, copy.map_color
      assert(b.r + b.g + b.b < a.r + a.g + a.b, copy.name .. " is not darker than " .. original)
      checked = checked + 1
    end
  end
  assert(checked >= 3, "only " .. checked .. " dark copies")
end)
