-- Optional per-player overlay: a line down the centre of each band.
--
-- Per player because it is pure presentation -- one player turning it on
-- cannot change the terrain or what anyone else sees. The render objects are
-- created with `players = {index}` so they are genuinely private.
--
-- Render objects are game state, so they are tracked in `storage` rather than
-- a module local: a module local would be lost across save/load and the
-- objects would leak, accumulating every time the save was reloaded.

local Ti = require("hat.tiling")
local G = require("hat.geometry")
local Surface = require("mod.surface")

local Outline = {}

-- How far around the player to draw, and how far they may move before it is
-- redrawn. Redrawing on every move would be wasteful; never redrawing would
-- leave the overlay behind.
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

--- Bring one player's overlay up to date. Cheap when nothing has changed.
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
