-- Fulgora: scrap into recyclers, on lightning power. Storms come at night, so
-- the day cycle runs on Fulgora.
local Kit = require("layouts.kit")

return { always_day = false, stages = Kit.stages({
  lines = {
    { ore = "scrap", chain = "recycle", rows = 2, chain_rows = 1 },
    { ore = "scrap", chain = "recycle", rows = 2, chain_rows = 1 },
    { ore = "scrap", chain = "recycle", rows = 2, chain_rows = 1 },
  },
  load = 650,
  power = "lightning",
  unlock = { "recycling" },
}) }
