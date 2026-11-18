local planets = require("mod.planets")

-- STARTUP, not runtime. The geometry controls the terrain. If it changed in
-- an existing save, every generated chunk would keep the old geometry. The
-- mod stores the values for each surface when it creates the surface
-- (`mod/surface.lua`). So a later change affects only NEW surfaces, and no
-- seams appear.
--
-- This file copies the bounds, and does not load them from `mod/config.lua`.
-- The settings stage cannot load a module that loads the generated data of
-- `hat/tiling.lua`. A test in `spec/config_spec.lua` keeps the two copies the
-- same.
local settings_list = {}
local order = 0

for planet, _ in pairs(planets) do
  order = order + 1
  -- Dropdowns, not sliders. The number does not show how hard a size is,
  -- and the interesting range is four values, not seventy-six. The values
  -- are strings, because Factorio requires strings for a dropdown.
  -- mod/surface.lua converts them.
  settings_list[#settings_list + 1] = {
    type = "string-setting",
    name = "hattorio-hat-size-" .. planet,
    setting_type = "startup",
    default_value = "41",
    allowed_values = { "15", "26", "41", "52" },
    order = string.format("a[size]-%02d[%s]", order, planet),
  }
  settings_list[#settings_list + 1] = {
    type = "string-setting",
    name = "hattorio-band-width-" .. planet,
    setting_type = "startup",
    default_value = "3",
    allowed_values = { "1", "2", "3", "4" },
    order = string.format("b[band]-%02d[%s]", order, planet),
  }
end

-- Band appearance. This is a startup setting, because it selects which tile
-- prototypes exist.
settings_list[#settings_list + 1] = {
  type = "string-setting",
  name = "hattorio-band-style",
  setting_type = "startup",
  default_value = "liquid",
  allowed_values = { "liquid", "void" },
  order = "c[style]-a[style]",
}

-- Band colour. It is independent of the style: every colour works with every
-- shader. The default is deep violet. It is the only option that looks
-- deliberate and not like dark ground. Every body colour here is nearly black,
-- and the highlight is what makes them different.
settings_list[#settings_list + 1] = {
  type = "string-setting",
  name = "hattorio-band-colour",
  setting_type = "startup",
  default_value = "violet",
  allowed_values = { "violet", "cold", "oily", "ember", "ink" },
  order = "c[style]-b[colour]",
}

-- Map scope, because everyone on the map shares the ore. 0 means "use the
-- automatic compensation from the cell size and band width". Any other value
-- replaces it completely.
settings_list[#settings_list + 1] = {
  type = "double-setting",
  name = "hattorio-richness-override",
  setting_type = "runtime-global",
  default_value = 0.0,
  minimum_value = 0.0,
  maximum_value = 10.0,
  order = "d[richness]",
}

-- Per player, because it is only presentation. If one player turns the
-- overlay on, that does not change what anyone else sees, or the terrain.
settings_list[#settings_list + 1] = {
  type = "bool-setting",
  name = "hattorio-show-outline",
  setting_type = "runtime-per-user",
  default_value = false,
  order = "e[outline]",
}

data:extend(settings_list)
