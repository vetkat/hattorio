-- /hattorio-info shows the geometry and richness that are actually in use.
--
-- Some settings of this mod have effects that you cannot see directly. "Ore
-- richness override = 0" means "derive it from the cell size and the band
-- width". Without this command you cannot see the derived value, or if an
-- override had any effect.

local Surface = require("mod.surface")

local function report(command)
  local player = command.player_index and game.get_player(command.player_index)
  local function say(msg)
    if player then player.print(msg) else game.print(msg) end
  end

  local surface = player and player.surface or game.surfaces[1]
  if not Surface.is_tiled(surface) then
    say("hattorio: " .. surface.name .. " is not tiled by this mod.")
    return
  end

  local g = Surface.get(surface)
  local mult, source = Surface.richness(g)

  say(string.format("hattorio on %s:", surface.name))
  say(string.format("  cell size %d tiles, band %d tiles", g.size, g.band))
  say(string.format("  substitution depth %d", g.depth))
  say(string.format("  ore richness x%.2f (%s)", mult, source))
  if source == "automatic" then
    say("  set the ore richness override above 0 to replace that")
  end
  say("  geometry is fixed for this surface and unaffected by later " ..
      "settings changes")
end

commands.add_command("hattorio-info",
  { "command-help.hattorio-info" }, report)
