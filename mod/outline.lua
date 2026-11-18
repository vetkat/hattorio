-- Optional overlay for each player: a line down the centre of each band.
--
-- It is per player because it is only presentation. If one player turns it
-- on, the terrain does not change, and nobody else sees a difference. The mod
-- creates the render objects with `players = {index}`, so they really are
-- private.
--
-- Render objects are game state, so `storage` tracks them, not a module
-- local. A module local would be lost on save and load. The objects would
-- leak, and more would collect every time a player loaded the save again.

local Ti = require("hat.tiling")
local G = require("hat.geometry")
local Surface = require("mod.surface")

local Outline = {}

-- How far around the player to draw, and how far the player can move before
-- the overlay is drawn again. To draw again on every move would waste time.
-- If it never drew again, the overlay would stay behind.
local RADIUS = 64
local MOVE_BEFORE_REDRAW = 24

local tilings = {}

local function tiling_for(surface)
  local g = Surface.get(surface)
  if not g then return nil, nil end
  local t = tilings[surface.index]
  if not t then
    t = Ti.new({ unit = g.unit, depth = g.depth })
    tilings[surface.index] = t
  end
  return t, g
end

local function clear(player_index)
  local state = storage.outlines and storage.outlines[player_index]
  if not state then return end
  for i = 1, #state.objects do
    local o = state.objects[i]
    if o.valid then o.destroy() end
  end
  storage.outlines[player_index] = nil
end

Outline.clear = clear

local function draw(player)
  local surface = player.surface
  local t, g = tiling_for(surface)
  if not t then return end

  local pos = player.position
  local hats = t:hats_in_box({
    left = pos.x - RADIUS, top = pos.y - RADIUS,
    right = pos.x + RADIUS, bottom = pos.y + RADIUS,
  })

  local objects = {}
  for i = 1, #hats do
    local edges = G.edges(hats[i].xf, g.unit)
    for j = 1, #edges do
      local e = edges[j]
      objects[#objects + 1] = rendering.draw_line({
        color = { 0.55, 0.62, 0.72, 0.5 },
        width = 1.5,
        from = { e[1], e[2] },
        to = { e[3], e[4] },
        surface = surface,
        players = { player.index },
        draw_on_ground = true,
      })
    end
  end

  storage.outlines = storage.outlines or {}
  storage.outlines[player.index] = { objects = objects, x = pos.x, y = pos.y }
end

--- Update the overlay of one player. This is cheap when nothing has
-- changed.
function Outline.refresh(player)
  if not (player and player.valid and player.connected) then return end

  local on = settings.get_player_settings(player)["hattorio-show-outline"]
  if not (on and on.value) then
    clear(player.index)
    return
  end
  if not Surface.is_tiled(player.surface) then
    clear(player.index)
    return
  end

  local state = storage.outlines and storage.outlines[player.index]
  if state then
    local dx = player.position.x - state.x
    local dy = player.position.y - state.y
    if dx * dx + dy * dy < MOVE_BEFORE_REDRAW * MOVE_BEFORE_REDRAW then
      return
    end
  end

  clear(player.index)
  draw(player)
end

function Outline.reset()
  tilings = {}
end

return Outline
