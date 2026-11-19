require("mod.terrain")
require("mod.commands")
require("mod.interface")

-- factorio-test runs the in-game tests in `tests/ingame/`. This does nothing
-- unless the factorio-test mod is active, and the tests do not ship in the
-- mod zip.
if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")({
    "tests/ingame/smoke_test",
    "tests/ingame/bands_test",
    "tests/ingame/collision_test",
    "tests/ingame/interface_test",
  })
end
