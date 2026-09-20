local planets = require("mod.planets")
local colours = require("mod.colours")

-- Band appearance is two independent startup settings: STYLE picks the shader
-- laid over the surface, COLOUR picks what that shader is tinted. They are
-- orthogonal, so a glowing rift can be violet and a flat void can be ember.
--
-- All styles clone `deepwater`. Its transitions are authored for liquid
-- meeting land, which is the edge a rift wants, and it carries the only
-- animated shader in the base game.
local STYLE = settings.startup["hattorio-band-style"].value
local COLOUR = settings.startup["hattorio-band-colour"].value

-- The glowing style needs Vulcanus's lava shader, which only Space Age ships.
-- Fall back rather than refuse to load, and say so in the log.
if STYLE == "rift" and not mods["space-age"] then
  log("hattorio: band style 'rift' needs Space Age for the lava shader; " ..
      "falling back to 'liquid'")
  STYLE = "liquid"
end

-- Only the effect differs between styles; the colours come from COLOUR.
local STYLE_EFFECT = {
  liquid = "water",
  void = nil,
  rift = "lava-2",
}

local c = colours[COLOUR] or colours.violet
local effect = STYLE_EFFECT[STYLE]

local function band_tile(name, highlight, map_color)
  local src = data.raw.tile["deepwater"]
  if not src then
    error("hattorio: base tile 'deepwater' does not exist")
  end
  local t = table.deepcopy(src)
  t.name = name
  t.map_color = map_color
  t.order = "z[hattorio]"
  t.localised_name = { "tile-name.hattorio-band" }

  -- Only the band layer. The tile blocks nothing else, so the character and
  -- vehicles pass over it -- a rift you can step across.
  t.collision_mask = { layers = { hattorio_band = true } }

  t.effect = effect
  t.effect_color = c.body
  t.effect_color_secondary = highlight

  -- Not water: must not feed an offshore pump, must not merge with lakes,
  -- must not be minable or appear in blueprints, and must never autoplace.
  t.fluid = nil
  t.transition_merges_with_tile = nil
  t.autoplace = nil
  t.minable = nil
  t.mined_sound = nil
  t.can_be_part_of_blueprint = false
  t.walking_speed_modifier = nil
  t.factoriopedia_alternative = nil

  return t
end

local tiles = {}
for planet, _ in pairs(planets) do
  tiles[#tiles + 1] = band_tile("hattorio-band-" .. planet, c.highlight, c.body)
  tiles[#tiles + 1] = band_tile("hattorio-band-" .. planet .. "-mirror", c.mirror, c.mirror)
end

data:extend(tiles)
