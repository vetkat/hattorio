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

  describe("the look of a dark copy", function()
    local tiles = {
      ["oil-ocean-shallow"] = { fluid = "heavy-oil", layer = 4 },
      ["oil-ocean-shallow-2"] = { fluid = "heavy-oil", layer = 4 },
      ["oil-ocean-deep"] = { fluid = "heavy-oil", layer = 2, effect = "oil-deep" },
      ["oil-ocean-deep-2"] = { fluid = "heavy-oil", layer = 3, effect = "oil-deep" },
      ["ammoniacal-ocean"] = { fluid = "ammoniacal-solution", layer = 2, effect = "water" },
      ["brash-ice"] = { fluid = "ammoniacal-solution", layer = 3, effect = "brash-ice-2" },
      ["texture-ice"] = { fluid = "ammoniacal-solution", layer = 3 },
      ["lone-texture"] = { fluid = "lava", layer = 5 },
    }
    local dark = {}
    for name in pairs(tiles) do dark[name] = true end

    it("lends a texture ocean the look of the lowest shader ocean with its fluid", function()
      assert.are.equal("oil-ocean-deep", Water.look_donor("oil-ocean-shallow", tiles, dark))
      assert.are.equal("ammoniacal-ocean", Water.look_donor("texture-ice", tiles, dark))
    end)

    it("lends nothing to a shader ocean, or where no ocean shares the fluid", function()
      assert.is_nil(Water.look_donor("oil-ocean-deep", tiles, dark))
      assert.is_nil(Water.look_donor("lone-texture", tiles, dark))
    end)

    it("takes a donor only from a lower layer, so that the shore draws onto it", function()
      local high = { low = { fluid = "oil", layer = 2 }, deep = { fluid = "oil", layer = 5,
        effect = "oil-deep" } }
      assert.is_nil(Water.look_donor("low", high, { low = true, deep = true }))
    end)

    it("lends nothing to a tile with no fluid", function()
      local dry = { a = { layer = 4 }, b = { layer = 2, effect = "water" } }
      assert.is_nil(Water.look_donor("a", dry, { a = true, b = true }))
    end)

    it("takes a donor only from the dark tiles", function()
      local only = { ["oil-ocean-shallow"] = true }
      assert.is_nil(Water.look_donor("oil-ocean-shallow", tiles, only))
    end)

    it("darkens an oil shader, and leaves the original as it is", function()
      local fx = { name = "oil-deep", water = { shader_variation = "oil",
        specular_lightness = { 3, 3, 3 }, foam_color_multiplier = 0.1,
        dark_threshold = { 2, 2 }, reflection_threshold = { 5, 5 } } }
      local dark_fx = Water.dark_effect(fx)
      assert.are.equal("hattorio-band-dark-oil-deep", dark_fx.name)
      assert.are.same({ 0.5, 0.5, 0.5 }, dark_fx.water.specular_lightness)
      assert.are.equal(0, dark_fx.water.foam_color_multiplier)
      assert.are.same({ 0, 0 }, dark_fx.water.dark_threshold)
      assert.are.same({ 0, 0 }, dark_fx.water.reflection_threshold)
      assert.are.same({ 3, 3, 3 }, fx.water.specular_lightness)
    end)

    it("leaves a shader alone that takes its colour from the tile", function()
      assert.is_nil(Water.dark_effect({ name = "water", water = { specular_lightness = { 1 } } }))
      assert.is_nil(Water.dark_effect(nil))
    end)
  end)
end)
