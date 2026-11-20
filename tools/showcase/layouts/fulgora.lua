-- Fulgora: scrap into recyclers. Its light is weak, so the lines are small
-- and each has several solar fields.
local Kit = require("layouts.kit")

return { stages = Kit.stages({
  lines = {
    { ore = "scrap", chain = "recycle", rows = 2, chain_rows = 1 },
    { ore = "scrap", chain = "recycle", rows = 2, chain_rows = 1 },
    { ore = "scrap", chain = "recycle", rows = 2, chain_rows = 1 },
  },
  load = 800,
}) }
