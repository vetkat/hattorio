local Ti = require("hat.tiling")
local Config = require("mod.config")
local Bands = require("mod.bands")

local function setup(size, band)
  local g = Config.geometry(size, band)
  return Ti.new({ unit = g.unit, depth = g.depth }), g
end

describe("band rasterisation", function()
  it("returns band tiles inside the requested area only", function()
    local t, g = setup(26, 2)
    local area = { left = -40, top = -40, right = 40, bottom = 40 }
    local tiles = Bands.for_area(t, g, area)
    assert.is_true(#tiles > 0)
    for _, p in ipairs(tiles) do
      assert.is_true(p.x >= area.left and p.x < area.right, "x " .. p.x)
      assert.is_true(p.y >= area.top and p.y < area.bottom, "y " .. p.y)
    end
  end)

  it("covers a plausible fraction of the area", function()
    local t, g = setup(26, 2)
    local n = #Bands.for_area(t, g, { left=-64, top=-64, right=64, bottom=64 })
    local frac = n / (128 * 128)
    assert.is_true(frac > 0.10 and frac < 0.40, "fraction " .. frac)
  end)

  it("marks some tiles as mirror and most not", function()
    local t, g = setup(26, 2)
    local tiles = Bands.for_area(t, g, { left=-96, top=-96, right=96, bottom=96 })
    local m = 0
    for _, p in ipairs(tiles) do if p.mirror then m = m + 1 end end
    assert.is_true(m > 0, "no mirror tiles")
    assert.is_true(m < #tiles / 2, "too many mirror tiles")
  end)

  it("is deterministic", function()
    local t, g = setup(26, 2)
    local a = { left = 0, top = 0, right = 32, bottom = 32 }
    local one, two = Bands.for_area(t, g, a), Bands.for_area(t, g, a)
    assert.are.equal(#one, #two)
    for i = 1, #one do
      assert.are.equal(one[i].x, two[i].x)
      assert.are.equal(one[i].y, two[i].y)
      assert.are.equal(one[i].mirror, two[i].mirror)
    end
  end)

  it("agrees across a chunk boundary", function()
    -- a band must not break where two chunks meet: every chunk derives its
    -- tiles from the tiling, never from a neighbour's tiles
    local t, g = setup(26, 2)
    local l = Bands.for_area(t, g, { left=-32, top=0, right=0,  bottom=32 })
    local r = Bands.for_area(t, g, { left=0,   top=0, right=32, bottom=32 })
    local b = Bands.for_area(t, g, { left=-32, top=0, right=32, bottom=32 })
    assert.are.equal(#l + #r, #b)
  end)

  it("makes a wider band cover more tiles", function()
    local t1, g1 = setup(26, 1)
    local t3, g3 = setup(26, 3)
    local a = { left = -48, top = -48, right = 48, bottom = 48 }
    assert.is_true(#Bands.for_area(t3, g3, a) > #Bands.for_area(t1, g1, a))
  end)

  it("leaves cells connected: no area is entirely band", function()
    local t, g = setup(26, 2)
    local a = { left = -64, top = -64, right = 64, bottom = 64 }
    assert.is_true(#Bands.for_area(t, g, a) < 128 * 128)
  end)
end)
