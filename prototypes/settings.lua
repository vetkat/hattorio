local planets = require("mod.planets")

-- STARTUP, not runtime. The geometry decides terrain, so changing it under an
-- existing save would leave every generated chunk built to the old geometry.
-- mod/surface.lua stores the values per surface at creation, so a later change
-- affects only NEW surfaces and nothing ever seams.
--
-- The bounds are repeated here rather than required from mod/config.lua: the
-- settings stage cannot load a module that pulls in hat/tiling.lua's generated
-- data. A test in spec/config_spec.lua keeps the two in step.
local settings_list = {}
local order = 0

for planet, _ in pairs(planets) do
  order = order + 1
  settings_list[#settings_list + 1] = {
    type = "int-setting",
    name = "hattorio-hat-size-" .. planet,
    setting_type = "startup",
    default_value = 26,
    minimum_value = 15,
    maximum_value = 90,
    order = string.format("a[size]-%02d[%s]", order, planet),
  }
  settings_list[#settings_list + 1] = {
    type = "int-setting",
    name = "hattorio-band-width-" .. planet,
    setting_type = "startup",
    default_value = 2,
    minimum_value = 1,
    maximum_value = 6,
    order = string.format("b[band]-%02d[%s]", order, planet),
  }
end

-- Band appearance. Startup, because it selects which tile prototypes exist.
--
-- "rift" needs Space Age for Vulcanus's lava shader; prototypes/tiles.lua
-- falls back to "liquid" and logs if it is unavailable, rather than refusing
-- to load.
settings_list[#settings_list + 1] = {
  type = "string-setting",
  name = "hattorio-band-style",
  setting_type = "startup",
  default_value = "liquid",
  allowed_values = { "liquid", "void", "rift" },
  order = "c[style]",
}

-- Map-scoped, because ore is shared between everyone on it. 0 means "use the
-- automatic compensation derived from cell size and band width"; any other
-- value replaces it outright.
settings_list[#settings_list + 1] = {
  type = "double-setting",
  name = "hattorio-richness-override",
  setting_type = "runtime-global",
  default_value = 0.0,
  minimum_value = 0.0,
  maximum_value = 10.0,
  order = "d[richness]",
}

-- Per player, because it is pure presentation: one player having the overlay
-- on cannot affect what anyone else sees or what the terrain is.
settings_list[#settings_list + 1] = {
  type = "bool-setting",
  name = "hattorio-show-outline",
  setting_type = "runtime-per-user",
  default_value = false,
  order = "e[outline]",
}

data:extend(settings_list)
