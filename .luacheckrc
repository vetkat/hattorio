std = "lua52"
max_line_length = 100

-- Factorio's Lua environment. The game provides these, not Lua.
local factorio_globals = {
  "data", "mods", "settings", "defines", "game", "script",
  "prototypes", "remote", "commands", "rendering", "log", "serpent",
  "table_size", "helpers",
}

-- storage is the persistent table of the mod. Factorio provides it and mods
-- write to it, so it is not read-only.
local factorio_writable = { "storage", "table" }

files["prototypes"] = {
  read_globals = factorio_globals,
  -- Factorio adds `table.deepcopy`.
  globals = factorio_writable,
}

files["mod"] = {
  read_globals = factorio_globals,
  globals = factorio_writable,
}

files["spec"] = { std = "+busted" }

-- hat/ deliberately has no Factorio dependencies. It must load under plain
-- lua5.2, so that CI can test it. No Factorio globals here.
files["hat"] = {}

-- The showcase tool runs in the game as a mod of its own, so it sees the
-- Factorio globals. place.lua and camera.lua use none of them. It sets
-- game.speed for the warm-up.
local showcase_read = {}
for _, name in ipairs(factorio_globals) do
  if name ~= "game" then showcase_read[#showcase_read + 1] = name end
end
files["tools/showcase"] = { read_globals = showcase_read, globals = { "storage", "table", "game" } }

-- The stage entry points see the same Factorio globals as mod/.
for _, path in ipairs({ "control.lua", "data.lua", "data-final-fixes.lua", "settings.lua" }) do
  files[path] = { read_globals = factorio_globals, globals = factorio_writable }
end

-- The in-game tests see the game, plus the globals of factorio-test.
local ingame = {
  "test", "describe", "it", "before_each", "after_each", "before_all",
  "after_all", "async", "done", "after_ticks", "on_tick", "ticks_between_tests",
  "tags",
}
for _, name in ipairs(factorio_globals) do ingame[#ingame + 1] = name end
-- A test may change game state, such as the map settings, so it can write to
-- game.
files["tests/ingame"] = { read_globals = ingame, globals = { "storage", "table", "game" } }
