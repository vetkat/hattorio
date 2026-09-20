std = "lua52"
max_line_length = 100

-- Factorio's Lua environment. These are provided by the game, not by Lua.
local factorio_globals = {
  "data", "mods", "settings", "defines", "game", "script",
  "prototypes", "remote", "commands", "rendering", "log", "serpent",
  "table_size", "helpers",
}

-- storage is the mod's persistent table: Factorio provides it, mods write to
-- it, so it is not read-only.
local factorio_writable = { "storage", "table" }

files["prototypes"] = {
  read_globals = factorio_globals,
  -- Factorio adds table.deepcopy
  globals = factorio_writable,
}

files["mod"] = {
  read_globals = factorio_globals,
  globals = factorio_writable,
}

files["spec"] = { std = "+busted" }

-- hat/ is deliberately free of Factorio dependencies: it must load under
-- plain lua5.2 so it can be tested in CI. No Factorio globals here.
files["hat"] = {}
