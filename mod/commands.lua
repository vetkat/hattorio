-- /hattorio-info -- what geometry and richness are actually in force.
--
-- Exists because several of this mod's settings have effects that cannot be
-- observed directly. "Ore richness override = 0" means "derive it from cell
-- size and band width", and there is otherwise no way to see what that
-- derivation produced, or whether an override took effect at all.

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
