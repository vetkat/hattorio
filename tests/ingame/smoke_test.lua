-- In-game smoke tests. factorio-test runs them in the headless server, once
-- with the base game only and once with Space Age (tools/ingame.sh).

test("the mod is active", function()
  assert(script.active_mods["hattorio"], "hattorio is not active")
end)

-- watch.yml also runs these tests in newer Factorio releases, so this test
-- checks the minimum version and not the pin.
test("the game is Factorio 2.1 or later", function()
  local major, minor = script.active_mods["base"]:match("^(%d+)%.(%d+)%.")
  major, minor = tonumber(major), tonumber(minor)
  assert(major > 2 or (major == 2 and minor >= 1), "base is " .. script.active_mods["base"])
end)

-- Each run leaves out the tag of the other run, so these two tests check
-- that the run really has, or lacks, Space Age.
tags("base")
test("Space Age is off in the base run", function()
  assert(not script.active_mods["space-age"], "space-age is active")
end)

tags("space-age")
test("Space Age is on in the Space Age run", function()
  assert(script.active_mods["space-age"], "space-age is not active")
end)
