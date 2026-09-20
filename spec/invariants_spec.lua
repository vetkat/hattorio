local T = require("hat.transform")
local Ti = require("hat.tiling")

describe("spec invariants", function()
  it("uses no platform-nondeterministic functions in shipped modules", function()
    -- IEEE + - * / and sqrt are correctly rounded and so bit-identical across
    -- platforms. sin, cos, random and pow are not, and a divergence between
    -- two Factorio clients is a desync.
    for _, name in ipairs({ "transform", "geometry", "index", "tiling" }) do
      local f = assert(io.open("hat/" .. name .. ".lua", "r"))
      local src = f:read("*a"); f:close()
      src = src:gsub("%-%-[^\n]*", "")          -- strip comments
      assert.is_nil(src:find("math%.sin"), name .. " uses math.sin")
      assert.is_nil(src:find("math%.cos"), name .. " uses math.cos")
      assert.is_nil(src:find("math%.random"), name .. " uses math.random")
      assert.is_nil(src:find("%^"), name .. " uses the pow operator")
    end
  end)

  it("covers the whole Factorio map at max depth", function()
    -- half-extent of a Factorio map is ~1e6 tiles
    local t = Ti.new({ unit = 4.365, depth = Ti.max_depth() })
    assert.is_true(t:coverage() > 1e6, "coverage " .. t:coverage())
  end)

  it("reports coverage that grows with depth", function()
    local prev = 0
    for d = 0, Ti.max_depth() do
      local c = Ti.new({ unit = 4.365, depth = d }):coverage()
      assert.is_true(c > prev, "coverage must increase at depth " .. d)
      prev = c
    end
  end)

  it("stays finite and well-scaled at maximum depth", function()
    local t = Ti.new({ unit = 4.365, depth = Ti.max_depth() })
    local hats = t:hats_in_box({ left = 0, top = 0, right = 64, bottom = 64 })
    assert.is_true(#hats > 0)
    for _, h in ipairs(hats) do
      local s = T.scale(h.xf)
      assert.is_true(s == s, "NaN scale")                 -- x ~= x is the NaN test
      assert.is_true(s > 0 and s < math.huge, "scale " .. s)
      local x, y = T.origin(h.xf)
      assert.is_true(x == x and y == y, "NaN position")
    end
  end)

  it("never mutates a returned transform on a later call", function()
    local t = Ti.new({ unit = 4, depth = 3 })
    local b = { left = -100, top = -100, right = 100, bottom = 100 }
    local first = t:hats_in_box(b)
    local snap = {}
    for i, h in ipairs(first) do snap[i] = h.xf[3] end
    t:hats_in_box(b)
    for i, h in ipairs(first) do assert.are.equal(snap[i], h.xf[3]) end
  end)

  it("data files are generated, not hand-edited", function()
    for _, p in ipairs({ "data/hat_rules.lua", "data/hat_geometry.lua" }) do
      local f = assert(io.open(p, "r"))
      local head = f:read("*l"); f:close()
      assert.is_not_nil(head:find("GENERATED"), p .. " lost its header")
    end
  end)
end)
