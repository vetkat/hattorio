local Water = require("mod.water_band")

describe("water band", function()
  it("treats a tile that collides with water as water", function()
    assert.is_true(Water.is_water({ water_tile = true, item = true }))
  end)

  it("does not treat out-of-map or land as water", function()
    assert.is_false(Water.is_water({ water_tile = true, out_of_map = true }))
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
end)
