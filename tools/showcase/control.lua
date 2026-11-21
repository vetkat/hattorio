-- The showcase: builds a base in five stages on each planet in planets.lua,
-- and records a screenshot and a clip of each stage.
--
-- tools/showcase.sh writes planets.lua and runs the game. The script logs
-- lines that start with SHOWCASE, and tools/showcase.sh reads them.

local Build = require("build")
local Camera = require("camera")
local planets = require("planets")

-- require works only while control.lua loads, so the layouts load here.
local layouts = {}
for _, name in ipairs(planets) do layouts[name] = require("layouts." .. name) end

local WARM_TICKS = 18000
local WARM_SPEED = 16
local CLIP_FRAMES = 600
local MIN_WORKING = 0.6

local steps = {}
local wait = 0

local STATUS = {}
for k, v in pairs(defines.entity_status) do STATUS[v] = k end

local function say(text) log("SHOWCASE " .. text) end

-- No character in the shots. A player in single player joins after the
-- first tick, so the script removes characters before each screenshot.
local function no_characters()
  for _, player in pairs(game.players) do
    if player.character then player.character.destroy() end
  end
end

local function shot(surface, position, zoom, path, resolution, quality)
  no_characters()
  game.take_screenshot({
    surface = surface, position = position, zoom = zoom, path = path,
    resolution = resolution or { 1600, 900 }, quality = quality,
    show_gui = false, show_entity_info = false, daytime = 0, anti_alias = true,
  })
end

-- Mark the prerequisites of a technology as researched, and queue it, so
-- that labs have something to work on.
local function research(force, name)
  local function done(tech)
    for _, pre in pairs(tech.prerequisites) do
      done(pre)
      pre.researched = true
    end
  end
  done(force.technologies[name])
  force.add_research(name)
end

local function add(fn, ticks) steps[#steps + 1] = { fn = fn, ticks = ticks or 0 } end

local function plan_planet(name)
  local layout = layouts[name]
  local b
  add(function()
    local planet = game.planets[name]
    local surface = planet and (planet.surface or planet.create_surface())
    if not surface then say("ERROR missing surface " .. name) return end
    surface.always_day = layout.always_day ~= false
    surface.peaceful_mode = true
    surface.request_to_generate_chunks({ 0, 0 }, 10)
    surface.force_generate_chunk_requests()
    b = Build.new(surface)
  end, 60)
  for stage = 1, 5 do
    local before
    add(function()
      before = b.placed
      local refused = b.refused
      layout.stages[stage](b)
      local placed = b.placed - before
      say(string.format("STAGE %s %d placed=%d refused=%d", name, stage, placed,
        b.refused - refused))
      if placed == 0 then say("ERROR " .. name .. " stage " .. stage .. " placed nothing") end
      if b.research then research(b.force, b.research) b.research = nil end
      game.speed = WARM_SPEED
    end, WARM_TICKS)
    add(function()
      game.speed = 1
      local n, total, by_status = b:working()
      local parts = {}
      for status, count in pairs(by_status) do parts[#parts + 1] = status .. "=" .. count end
      table.sort(parts)
      say(string.format("WORKING %s %d working=%d total=%d %s", name, stage, n, total,
        table.concat(parts, " ")))
      local ins = {}
      for status, count in pairs(b:inserters()) do ins[#ins + 1] = status .. "=" .. count end
      table.sort(ins)
      log("showcase: inserters " .. name .. " " .. stage .. " " .. table.concat(ins, " "))
      for _, e in ipairs(b.built) do
        if e.valid and e.type == "inserter"
          and e.status == defines.entity_status.waiting_for_source_items then
          local pt, dt = e.pickup_target, e.drop_target
          log(string.format("showcase: idle inserter %s at %.1f,%.1f pickup %.1f,%.1f %s to %s",
            e.name, e.position.x, e.position.y, e.pickup_position.x, e.pickup_position.y,
            pt and pt.name or "nothing", dt and dt.name or "nothing"))
        end
      end
      for _, e in ipairs(b.built) do
        if e.valid and e.name == "foundry" then
          local fluids = {}
          for fluid, amount in pairs(e.get_fluid_contents()) do
            fluids[#fluids + 1] = fluid .. "=" .. math.floor(amount)
          end
          local recipe = e.get_recipe()
          log(string.format("showcase: foundry %.1f,%.1f %s %s %s", e.position.x, e.position.y,
            STATUS[e.status] or e.status, recipe and recipe.name or "none",
            table.concat(fluids, " ")))
        end
      end
      for _, e in ipairs(b.built) do
        if e.valid and (e.status == defines.entity_status.no_ingredients
          or e.status == defines.entity_status.fluid_ingredient_shortage) then
          game.take_screenshot({ surface = b.surface, position = e.position, zoom = 3,
            resolution = { 900, 900 }, show_gui = false, daytime = 0,
            path = string.format("showcase/debug/%s-%d-starved.png", name, stage) })
          break
        end
      end
      for _, e in ipairs(b.built) do
        if e.valid and e.type == "mining-drill"
          and e.status == defines.entity_status.waiting_for_space_in_destination then
          game.take_screenshot({ surface = b.surface, position = e.position, zoom = 1,
            resolution = { 1400, 1400 }, show_gui = false, daytime = 0,
            path = string.format("showcase/debug/%s-%d-blocked.png", name, stage) })
          break
        end
      end
      if total > 0 and n / total < MIN_WORKING then
        say(string.format("ERROR %s stage %d: %d of %d machines work", name, stage, n, total))
      end
      -- The stage names its main block in b.focus. Without one, the shot
      -- shows the middle of the base.
      shot(b.surface, b.focus or b:middle(), 1,
        "showcase/shots/" .. name .. "-" .. stage .. ".png")
      b.focus = nil
    end, 1)
    local path
    add(function()
      local box = b:bounds()
      local y = (box.top + box.bottom) / 2
      path = Camera.pan({ box.left, y }, { box.right, y }, CLIP_FRAMES)
    end)
    for f = 1, CLIP_FRAMES do
      add(function()
        shot(b.surface, path[f], 0.75,
          string.format("showcase/frames/%s-%d/%04d.jpg", name, stage, f),
          { 1920, 1080 }, 90)
      end, 1)
    end
    add(function() end, 2)
    add(function() say(string.format("CLIP %s %d frames=%d", name, stage, CLIP_FRAMES)) end)
  end
  add(function()
    shot(b.surface, b:middle(), 0.3, "showcase/shots/" .. name .. "-wide.png")
  end, 2)
end

-- Freeplay shows an intro that waits for a key, and puts a crashed ship at
-- the origin. The showcase needs neither.
script.on_init(function()
  if remote.interfaces.freeplay then
    if remote.interfaces.freeplay.set_skip_intro then
      remote.call("freeplay", "set_skip_intro", true)
    end
    if remote.interfaces.freeplay.set_disable_crashsite then
      remote.call("freeplay", "set_disable_crashsite", true)
    end
  end
end)

local started = false
script.on_event(defines.events.on_tick, function()
  if not started then
    started = true
    no_characters()
    for _, name in ipairs(planets) do plan_planet(name) end
    add(function() say("DONE") end)
  end
  if wait > 0 then
    wait = wait - 1
    return
  end
  -- Run the steps that need no wait in the same tick. A step with a wait
  -- ends the tick: each frame of a clip waits one tick, so that it shows a
  -- tick of its own.
  while #steps > 0 do
    local step = table.remove(steps, 1)
    step.fn()
    if step.ticks > 0 then
      wait = step.ticks - 1
      return
    end
  end
end)
