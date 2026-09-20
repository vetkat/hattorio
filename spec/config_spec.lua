local Config = require("mod.config")
local Ti = require("hat.tiling")

describe("config", function()
  it("clamps out-of-range settings", function()
    local s, b = Config.clamp(3, 99)
    assert.are.equal(Config.MIN_SIZE, s)
    assert.are.equal(Config.MAX_BAND, b)
    s, b = Config.clamp(1000, -5)
    assert.are.equal(Config.MAX_SIZE, s)
    assert.are.equal(Config.MIN_BAND, b)
  end)

  it("leaves valid settings alone", function()
    local s, b = Config.clamp(26, 2)
    assert.are.equal(26, s)
    assert.are.equal(2, b)
  end)

  it("falls back to defaults for nil or NaN", function()
    local s, b = Config.clamp(nil, nil)
    assert.are.equal(Config.DEFAULT_SIZE, s)
    assert.are.equal(Config.DEFAULT_BAND, b)
    local nan = 0 / 0
    s, b = Config.clamp(nan, nan)
    assert.are.equal(Config.MIN_SIZE, s)
    assert.are.equal(Config.MIN_BAND, b)
  end)

  it("derives a unit that yields the requested hat size", function()
    for _, size in ipairs({ 15, 26, 41, 90 }) do
      local g = Config.geometry(size, 2)
      assert.is_true(math.abs(Ti.hat_size_for_unit(g.unit) - size) < 1e-9,
        "size " .. size)
    end
  end)

  it("derives a depth that covers the whole map", function()
    for _, size in ipairs({ 15, 26, 41, 90 }) do
      local g = Config.geometry(size, 2)
      local t = Ti.new({ unit = g.unit, depth = g.depth })
      assert.is_true(t:coverage() >= Config.REQUIRED_COVER, "size " .. size)
    end
  end)

  it("uses a deeper root for a smaller cell", function()
    assert.is_true(Config.geometry(15, 2).depth > Config.geometry(90, 2).depth)
  end)

  it("carries half the band width for distance tests", function()
    assert.are.equal(1, Config.geometry(26, 2).half)
    assert.are.equal(1.5, Config.geometry(26, 3).half)
  end)

  it("compensates richness more when less ore is drillable", function()
    local small = Config.richness_multiplier(15, 2)
    local large = Config.richness_multiplier(90, 2)
    assert.is_true(small > large, small .. " should exceed " .. large)
    assert.is_true(large >= 1.0)
    assert.is_true(small <= 5.0, "compensation is capped at 5x")
  end)

  it("caps compensation at the smallest cells", function()
    -- At size 15 / band 2 barely 15% of a cell's ore is reachable, so the
    -- drillable floor of 0.2 binds and compensation saturates at 5x. That is
    -- deliberate: an uncapped formula would hand out absurd richness at the
    -- extreme end of the settings range.
    assert.are.equal(0.2, Config.drillable_fraction(15, 2))
    assert.are.equal(5.0, Config.richness_multiplier(15, 2))
    -- the default is comfortably off the floor
    assert.is_true(Config.drillable_fraction(26, 2) > 0.4)
  end)

  it("compensates more for a wider band", function()
    assert.is_true(Config.richness_multiplier(26, 4) > Config.richness_multiplier(26, 1))
  end)

  it("defaults to 41 and 3", function()
    assert.are.equal(41, Config.DEFAULT_SIZE)
    assert.are.equal(3, Config.DEFAULT_BAND)
  end)

end)

describe("richness calibration", function()


  -- Measured by rasterising a cell's interior and testing where a 3x3 drill
  -- fits, worst case across all 12 orientations. If the formula drifts from
  -- these, ore compensation silently becomes wrong.
  local measured = {
    { 20, 1, 0.511 }, { 20, 2, 0.398 }, { 26, 2, 0.522 },
    { 41, 2, 0.682 }, { 41, 3, 0.610 }, { 52, 2, 0.749 },
  }

  it("predicts the measured drillable fractions", function()
    for _, m in ipairs(measured) do
      local size, band, want = m[1], m[2], m[3]
      local got = Config.drillable_fraction(size, band)
      assert.is_true(math.abs(got - want) < 0.05,
        string.format("size %d band %d: predicted %.3f, measured %.3f",
                      size, band, got, want))
    end
  end)

  it("gives a compensation that restores roughly vanilla yield", function()
    for _, m in ipairs(measured) do
      local size, band, want = m[1], m[2], m[3]
      local effective = want * Config.richness_multiplier(size, band)
      assert.is_true(effective > 0.85 and effective < 1.25,
        string.format("size %d band %d: effective yield %.2f", size, band, effective))
    end
  end)

  it("offers only choices it can actually satisfy", function()
    for _, size in ipairs(Config.SIZE_CHOICES) do
      for _, band in ipairs(Config.BAND_CHOICES) do
        local g = Config.geometry(size, band)
        assert.are.equal(size, g.size)
        assert.are.equal(band, g.band)
      end
    end
  end)

  it("declares the same dropdown values as prototypes/settings.lua", function()
    local f = assert(io.open("prototypes/settings.lua", "r"))
    local src = f:read("*a"); f:close()
    assert.is_not_nil(src:find('default_value = "' .. Config.DEFAULT_SIZE .. '"', 1, true),
      "settings.lua default size differs from Config.DEFAULT_SIZE")
    assert.is_not_nil(src:find('default_value = "' .. Config.DEFAULT_BAND .. '"', 1, true),
      "settings.lua default band differs from Config.DEFAULT_BAND")
    for _, v in ipairs(Config.SIZE_CHOICES) do
      assert.is_not_nil(src:find('"' .. v .. '"', 1, true), "size choice " .. v .. " missing")
    end
  end)

  it("has a locale label for every dropdown value", function()
    local f = assert(io.open("locale/en/hattorio.cfg", "r"))
    local src = f:read("*a"); f:close()
    for _, v in ipairs(Config.SIZE_CHOICES) do
      assert.is_not_nil(src:find("hattorio%-hat%-size%-nauvis%-" .. v .. "="),
        "no label for size " .. v)
    end
    for _, v in ipairs(Config.BAND_CHOICES) do
      assert.is_not_nil(src:find("hattorio%-band%-width%-nauvis%-" .. v .. "="),
        "no label for band " .. v)
    end
  end)
end)

describe("band colours", function()
  local colours = require("mod.colours")

  it("declares the same colourways as prototypes/settings.lua", function()
    local f = assert(io.open("prototypes/settings.lua", "r"))
    local src = f:read("*a"); f:close()
    local allowed = src:match('name = "hattorio%-band%-colour".-allowed_values = {(.-)}')
    assert.is_not_nil(allowed, "no band colour setting found")
    for name, _ in pairs(colours) do
      assert.is_not_nil(allowed:find('"' .. name .. '"', 1, true),
        "colourway " .. name .. " is not offered in settings")
    end
    for quoted in allowed:gmatch('"([%a]+)"') do
      assert.is_not_nil(colours[quoted], "settings offer unknown colourway " .. quoted)
    end
  end)

  it("defaults to deep violet", function()
    local f = assert(io.open("prototypes/settings.lua", "r"))
    local src = f:read("*a"); f:close()
    local block = src:match('name = "hattorio%-band%-colour".-order')
    assert.is_not_nil(block:find('default_value = "violet"', 1, true))
  end)

  it("gives every colourway a body, a highlight and a mirror tint", function()
    for name, c in pairs(colours) do
      for _, key in ipairs({ "body", "highlight", "mirror" }) do
        assert.is_table(c[key], name .. " is missing " .. key)
        assert.are.equal(3, #c[key], name .. "." .. key .. " is not RGB")
        for i = 1, 3 do
          assert.is_true(c[key][i] >= 0 and c[key][i] <= 255,
            name .. "." .. key .. " component out of range")
        end
      end
    end
  end)

  it("has a locale label for every colourway", function()
    local f = assert(io.open("locale/en/hattorio.cfg", "r"))
    local src = f:read("*a"); f:close()
    for name, _ in pairs(colours) do
      assert.is_not_nil(src:find("hattorio%-band%-colour%-" .. name .. "="),
        "no label for colourway " .. name)
    end
  end)

  it("keeps every body near-black, so bands read as depth", function()
    for name, c in pairs(colours) do
      local brightness = (c.body[1] + c.body[2] + c.body[3]) / 3
      assert.is_true(brightness < 40, name .. " body is too light: " .. brightness)
      -- the highlight must actually be lighter, or the option is invisible
      local hl = (c.highlight[1] + c.highlight[2] + c.highlight[3]) / 3
      assert.is_true(hl >= brightness, name .. " highlight is not lighter than its body")
    end
  end)
end)
