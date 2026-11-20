local Water = require("mod.water_band")

describe("water band", function()
  it("treats a tile that collides with water as water", function()
    assert.is_true(Water.is_water({ water_tile = true, item = true }))
  end)

  it("does not treat out-of-map, empty space or land as water", function()
    assert.is_false(Water.is_water({ water_tile = true, out_of_map = true }))
    assert.is_false(Water.is_water({ water_tile = true, empty_space = true }))
    assert.is_false(Water.is_water({ ground_tile = true }))
  end)

  it("names the band copy of a water tile", function()
    assert.are.equal("hattorio-band-water-deepwater", Water.copy_name("deepwater"))
  end)

  it("finds the original of a band copy, and nothing for other tiles", function()
    assert.are.equal("deepwater", Water.original("hattorio-band-water-deepwater"))
    assert.is_nil(Water.original("deepwater"))
    assert.is_nil(Water.original("hattorio-band-nauvis"))
  end)

  it("finds the tiles that the dark planets place", function()
    local gens = {
      aquilo = { autoplace_settings = { tile = { settings = { ["ammoniacal-ocean"] = {} } } } },
      fulgora = { autoplace_settings = { tile = { settings = { ["oil-ocean-deep"] = {} } } } },
      nauvis = { autoplace_settings = { tile = { settings = { water = {} } } } },
    }
    local dark = Water.dark_tiles(function(planet) return gens[planet] end)
    assert.is_true(dark["ammoniacal-ocean"])
    assert.is_true(dark["oil-ocean-deep"])
    assert.is_nil(dark.water)
  end)

  it("finds no dark tiles without Space Age", function()
    assert.are.same({}, Water.dark_tiles(function() return nil end))
  end)
end)
