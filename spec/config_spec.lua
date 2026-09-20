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
    local large = Config.richness_multiplier(52, 1)
    assert.is_true(small > large, small .. " should exceed " .. large)
    assert.is_true(large >= 1.0)
  end)

  it("compensates more for a wider band", function()
    assert.is_true(Config.richness_multiplier(26, 4) > Config.richness_multiplier(26, 1))
  end)

  it("defaults to 41 and 3", function()
    assert.are.equal(41, Config.DEFAULT_SIZE)
    assert.are.equal(3, Config.DEFAULT_BAND)
  end)

end)

describe("cell statistics", function()
  local Config = require("mod.config")

  it("has measurements for every combination the dropdowns offer", function()
    -- a missing entry silently falls back to the fitted estimate, which is
    -- much worse at small cells; this catches a choice added without
    -- measuring it
    for _, size in ipairs(Config.SIZE_CHOICES) do
      for _, band in ipairs(Config.BAND_CHOICES) do
        local st = Config.cell_stats(size, band)
        assert.is_not_nil(st, "no measurements for size " .. size .. " band " .. band)
        assert.is_true(st.area > 0)
        assert.is_true(st.square > 0)
        assert.is_true(st.drillable > 0 and st.drillable <= 1)
      end
    end
  end)

  it("uses the measurement, not the fit, for offered combinations", function()
    for _, size in ipairs(Config.SIZE_CHOICES) do
      for _, band in ipairs(Config.BAND_CHOICES) do
        assert.are.equal(Config.cell_stats(size, band).drillable,
                         Config.drillable_fraction(size, band))
      end
    end
  end)

  it("gets smaller cells and wider bands right, monotonically", function()
    for _, size in ipairs(Config.SIZE_CHOICES) do
      local prev
      for _, band in ipairs(Config.BAND_CHOICES) do
        local st = Config.cell_stats(size, band)
        if prev then
          assert.is_true(st.area < prev.area, "wider band must shrink the cell")
          assert.is_true(st.drillable < prev.drillable,
            "wider band must reduce drillable ore")
        end
        prev = st
      end
    end
    for _, band in ipairs(Config.BAND_CHOICES) do
      local prev
      for _, size in ipairs(Config.SIZE_CHOICES) do
        local st = Config.cell_stats(size, band)
        if prev then
          assert.is_true(st.area > prev.area, "larger cells must hold more")
        end
        prev = st
      end
    end
  end)

  it("compensates richness back to roughly vanilla yield", function()
    for _, size in ipairs(Config.SIZE_CHOICES) do
      for _, band in ipairs(Config.BAND_CHOICES) do
        local st = Config.cell_stats(size, band)
        local effective = st.drillable * Config.richness_multiplier(size, band)
        assert.is_true(math.abs(effective - 1) < 1e-9,
          string.format("size %d band %d: effective yield %.3f", size, band, effective))
      end
    end
  end)

  it("flags only the combinations that are barely playable", function()
    -- 15/4 gives a 4x4 largest square; a drill and an assembler are both 3x3
    assert.is_true(Config.is_severe(15, 4))
    assert.is_false(Config.is_severe(15, 2))
    assert.is_false(Config.is_severe(26, 4))
    assert.is_false(Config.is_severe(41, 3))
  end)

  it("keeps the fallback fit close to the measurements", function()
    -- used only for sizes that never came from a dropdown
    for _, size in ipairs(Config.SIZE_CHOICES) do
      for _, band in ipairs(Config.BAND_CHOICES) do
        local got = Config.fit_drillable(size, band)
        local want = Config.cell_stats(size, band).drillable
        assert.is_true(math.abs(got - want) < 0.08,
          string.format("size %d band %d: fit %.3f vs measured %.3f",
                        size, band, got, want))
      end
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

describe("band styles", function()
  it("offers only styles the tiles module implements", function()
    local f = assert(io.open("prototypes/settings.lua", "r"))
    local src = f:read("*a"); f:close()
    local allowed = src:match('name = "hattorio%-band%-style".-allowed_values = {(.-)}')
    assert.is_not_nil(allowed, "no band style setting found")

    local g = assert(io.open("prototypes/tiles.lua", "r"))
    local tiles = g:read("*a"); g:close()
    local effects = tiles:match("local STYLE_EFFECT = {(.-)}")
    assert.is_not_nil(effects, "no STYLE_EFFECT table found")

    for quoted in allowed:gmatch('"([%a]+)"') do
      assert.is_not_nil(effects:find(quoted .. " ="),
        "settings offer style '" .. quoted .. "' with no effect defined")
    end
  end)

  it("no longer offers the glowing rift", function()
    -- removed after playtesting: it read as a hazard rather than a void
    local f = assert(io.open("prototypes/settings.lua", "r"))
    local src = f:read("*a"); f:close()
    assert.is_nil(src:find("rift", 1, true))
  end)
end)

describe("highlight contrast", function()
  local colours = require("mod.colours")

  local function brightness(c) return (c[1] + c[2] + c[3]) / 3 end

  it("gives every colourway a clearly lighter highlight", function()
    -- without real contrast between body and highlight the shader has nothing
    -- to catch and the option looks like every other one
    for name, c in pairs(colours) do
      local b, h = brightness(c.body), brightness(c.highlight)
      assert.is_true(h > b + 8,
        string.format("%s: highlight %.0f is too close to body %.0f", name, h, b))
    end
  end)

  it("keeps the colourways distinguishable from each other", function()
    local seen = {}
    for name, c in pairs(colours) do
      for other, oc in pairs(seen) do
        local d = math.abs(c.highlight[1] - oc.highlight[1])
              + math.abs(c.highlight[2] - oc.highlight[2])
              + math.abs(c.highlight[3] - oc.highlight[3])
        assert.is_true(d > 30,
          name .. " and " .. other .. " have near-identical highlights")
      end
      seen[name] = c
    end
  end)
end)
