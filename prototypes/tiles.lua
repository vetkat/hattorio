local planets = require("mod.planets")

-- Band appearance is a startup setting, so the tiles differ by what the
-- player chose. All three styles clone `deepwater`: its transitions are
-- authored for liquid meeting land, which is the edge a rift wants, and it
-- carries the only animated shader in the base game.
local STYLE = settings.startup["hattorio-band-style"].value

-- The glowing style needs Vulcanus's lava shader, which only Space Age ships.
-- Fall back rather than fail to load, and say so in the log.
if STYLE == "rift" and not mods["space-age"] then
  log("hattorio: band style 'rift' needs Space Age for the lava shader; " ..
      "falling back to 'liquid'")
  STYLE = "liquid"
end

-- Body and highlight colours per style. The body is deliberately near-black
-- in every case; the highlight is what distinguishes them.
local STYLE_COLOURS = {
  liquid = { body = { 23, 27, 34 },  highlight = { 46, 58, 69 },  effect = "water" },
  void   = { body = { 8, 9, 12 },    highlight = { 8, 9, 12 },    effect = nil },
  rift   = { body = { 26, 12, 8 },   highlight = { 167, 59, 27 }, effect = "lava-2" },
}

local style = STYLE_COLOURS[STYLE] or STYLE_COLOURS.liquid

local function band_tile(name, map_color)
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

  t.effect = style.effect
  t.effect_color = style.body
  t.effect_color_secondary = style.highlight

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
for planet, cfg in pairs(planets) do
  tiles[#tiles + 1] = band_tile("hattorio-band-" .. planet, cfg.map_color)
  tiles[#tiles + 1] = band_tile("hattorio-band-" .. planet .. "-mirror", cfg.mirror_color)
end

data:extend(tiles)
