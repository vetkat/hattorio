-- Vulcanus: coal and calcite with electric drills, and tungsten with big
-- mining drills.
local Kit = require("layouts.kit")

return { stages = Kit.stages({
  lines = {
    { ore = "coal", chain = "sink" },
    { ore = "calcite", chain = "sink" },
    { ore = "tungsten-ore", drill = "big", chain = "sink" },
    { ore = "tungsten-ore", drill = "big", chain = "sink" },
  },
  load = 1300,
}) }
