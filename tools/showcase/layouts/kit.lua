-- The five stages for a planet, built from its configuration:
--   lines:   ore lines in the order the stages add them. Each line is
--            { ore = name, drill = "electric" or "big", chain = "smelt",
--            "recycle" or "sink" }.
--   special: a function(b) that builds the industry of the planet in stage 4.
--   power:   "solar" (the default) or "lightning". Fulgora has 20% light, and
--            its islands are too small for enough solar panels. There a
--            line gets banks of accumulators around a lightning attractor,
--            as players build them. The banks start full, as if earlier
--            storms charged them, and storms charge them again.
--   unlock:  technologies to research before stage 1, with their
--            prerequisites. An inserter puts an item into a furnace only if
--            its recipe is unlocked, and recycling is not unlocked at the
--            start of a game.
--   load:    the power of a line in kW, for the size of its solar fields.
-- Each stage sets b.focus to the block that its screenshot shows.

local M = require("modules")

local Kit = {}

local function abs(origin, rel)
  if not origin then return nil end
  return { origin[1] + rel[1], origin[2] + rel[2] }
end
Kit.abs = abs

-- Solar fields near a tile, enough for `kw` on this planet, wired to `to`.
-- A field holds 12 panels of 60 kW at Nauvis light. The light differs from
-- planet to planet, so the number of fields does too.
function Kit.power(b, near, kw, to)
  -- Space Age gives each planet a solar-power property, in percent.
  local light = b.surface.get_property("solar-power") / 100
  local fields = math.max(1, math.ceil(kw / (12 * 60 * light)))
  local last, placed = to, 0
  for i = 1, fields do
    local solar, sat = M.solar(6)
    local origin = b:place_near(solar, abs(near, { 0, 12 * (i - 1) }), 2000)
    if origin then
      b:poles(abs(origin, sat.pole), last)
      last = abs(origin, sat.pole)
      placed = placed + 1
    end
  end
  log(string.format("showcase: %d of %d solar fields for %d kW at light %.2f", placed, fields,
    kw, light))
end

-- A bank of 8 accumulators with a lightning collector and a pole.
local function bank()
  local l = {}
  for i = 0, 3 do
    l[#l + 1] = { "accumulator", 2 * i, 0 }
    l[#l + 1] = { "accumulator", 2 * i, 2 }
  end
  l[#l + 1] = { "lightning-collector", 8, 0 }
  l[#l + 1] = { "medium-electric-pole", 8, 3 }
  return l, { 8, 3 }
end

-- Banks near a tile, about one for each 150 kW, wired to `to`.
function Kit.lightning(b, near, kw, to)
  local count, placed, last = math.max(1, math.ceil(kw / 150)), 0, to
  for i = 1, count do
    local layout, pole = bank()
    local origin = b:place_near(layout, abs(near, { 0, 6 * (i - 1) }), 2000)
    if origin then
      for _, e in ipairs(b.surface.find_entities_filtered({ type = "accumulator",
        area = { { origin[1], origin[2] }, { origin[1] + 8, origin[2] + 4 } } })) do
        e.energy = e.electric_buffer_size
      end
      b:poles(abs(origin, pole), last)
      last = abs(origin, pole)
      placed = placed + 1
    end
  end
  log(string.format("showcase: %d of %d lightning banks for %d kW", placed, count, kw))
end

local function mine_layout(line)
  if line.drill == "big" then return M.big_mining(line.rows or 2) end
  return M.mining(line.rows or 3)
end

local function chain_layout(line)
  if line.chain == "smelt" then return M.smelting(line.chain_rows or 8) end
  if line.chain == "recycle" then return M.machines(line.chain_rows or 4, "recycler") end
  return nil
end

-- A mine with its own solar field. Returns the origin of the mine and the
-- tile where its belt leaves.
local function mine(b, cfg, line, near)
  local patch = b:ore(line.ore, near, 150)
  if not patch then
    log("showcase: no " .. line.ore .. " near " .. near[1] .. "," .. near[2])
    return nil
  end
  local layout, at = mine_layout(line)
  local origin = b:place_near(layout, patch, 800)
  if not origin then
    log(string.format("showcase: no place for a %s mine near %d,%d", line.ore, patch[1], patch[2]))
    local types = {}
    for _, e in ipairs(b.surface.find_entities_filtered({ position = patch, radius = 12 })) do
      types[e.type .. ":" .. e.name] = (types[e.type .. ":" .. e.name] or 0) + 1
    end
    local parts = {}
    for k, v in pairs(types) do parts[#parts + 1] = k .. "=" .. v end
    log("showcase: around the patch: " .. table.concat(parts, " "))
    log("showcase: drill fits at patch: " .. tostring(b:can_place("electric-mining-drill",
      patch[1], patch[2], "east")))
    return nil
  end
  local power = cfg.power == "lightning" and Kit.lightning or Kit.power
  power(b, abs(origin, { 16, 0 }), line.load or cfg.load or 900, abs(origin, at.pole))
  return origin, abs(origin, at.out)
end

-- The chain of a line from the tile where its belt leaves the mine, and a
-- sink at its end. Returns the origin of the chain block.
local function chain(b, line, start, key)
  local layout, at = chain_layout(line)
  if not layout then
    b:sink(key, start, "south")
    return nil
  end
  -- South first. At a coast or a band, the belt can turn east or west.
  local origin
  for _, dir in ipairs({ "south", "east", "west" }) do
    origin = b:place_along(layout, start, dir)
    if origin then break end
  end
  if not origin then
    b:sink(key, start, "south")
    return nil
  end
  b:link(abs(origin, at.pole))
  b:sink(key, abs(origin, at.out), "south")
  return origin
end

local function line_full(b, cfg, line, near, key)
  -- A patch may have no room for a mine, so the line tries more places.
  local origin, out
  for _, off in ipairs({ { 0, 0 }, { 60, 0 }, { -60, 0 }, { 0, 60 }, { 0, -60 } }) do
    if near then origin, out = mine(b, cfg, line, abs(near, off)) end
    if origin then break end
  end
  if not origin then return nil end
  return origin, chain(b, line, out, key)
end

local function unlock(force, name)
  local tech = force.technologies[name]
  if not tech or tech.researched then return end
  for _, pre in pairs(tech.prerequisites) do unlock(force, pre.name) end
  tech.researched = true
end

function Kit.stages(cfg)
  local s = {}
  local lines = cfg.lines

  -- 1. The first mine, and a sink at the end of its belt.
  s[1] = function(b)
    for _, name in ipairs(cfg.unlock or {}) do unlock(b.force, name) end
    local origin, out = mine(b, cfg, lines[1], { 0, 0 })
    b:sink("first-sink", out, "south")
    b.anchor.first = origin
    b.anchor.power = origin and abs(origin, { -1, 1 })
    b.focus = abs(origin, { 4, 6 })
  end

  -- 2. The chain of the first line in the next cell, under a band.
  s[2] = function(b)
    local start = b:unsink("first-sink")
    local origin = chain(b, lines[1], start, "first-end")
    if not origin and start then
      -- A line without a chain carries its belt on to a sink further away.
      b:unsink("first-end")
      local yard
      for _, dir in ipairs({ "south", "east", "west" }) do
        yard = b:place_along({ { "transport-belt", 0, 0, "south" } }, start, dir, 6, 40)
        if yard then break end
      end
      b:sink("first-end", abs(yard, { 0, 1 }), "south")
      origin = yard
    end
    b.focus = origin and { (start[1] + origin[1]) / 2, (start[2] + origin[2]) / 2 + 4 }
  end

  -- 3. The second line.
  s[3] = function(b)
    local near = abs(b.anchor.first, { 40, 0 })
    local origin, block = line_full(b, cfg, lines[2] or lines[1], near, "second")
    b.anchor.second = origin
    b.focus = abs(block or origin, { 4, 6 })
  end

  -- 4. The industry of the planet, and a third line.
  s[4] = function(b)
    local focus = cfg.special and cfg.special(b)
    line_full(b, cfg, lines[3] or lines[1], abs(b.anchor.first, { -40, 20 }), "third")
    b.focus = focus or b:middle()
  end

  -- 5. A fourth line, a train line across the base and roboports.
  s[5] = function(b)
    line_full(b, cfg, lines[4] or lines[2] or lines[1], abs(b.anchor.first, { 20, 50 }), "fourth")
    local box, mid = b:bounds(), b:middle()
    b:rails(math.floor(box.left) - 20, math.floor(box.right) + 20, math.floor(mid[2]) + 24)
    local robots = {
      { name = "construction-robot", count = 10 }, { name = "logistic-robot", count = 10 },
    }
    for _, near in ipairs({ b.anchor.first or mid, b.anchor.second or mid }) do
      local port = { { "roboport", 0, 0, nil, { items = robots } } }
      local rp = b:place_near(port, abs(near, { 8, -6 }))
      local power = cfg.power == "lightning" and Kit.lightning or Kit.power
      if rp then power(b, abs(rp, { 8, 0 }), 200, { rp[1] + 2, rp[2] + 4 }) end
    end
    b.focus = { mid[1], mid[2] + 12 }
  end
  return s
end

return Kit
