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

data:extend(settings_list)
