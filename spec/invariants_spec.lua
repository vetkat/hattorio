local E = require("hat.exact")
local T = require("hat.transform")
local Ti = require("hat.tiling")

local ALL = { left = -1e7, top = -1e7, right = 1e7, bottom = 1e7 }

describe("spec invariants", function()
  it("keeps every coefficient inside 2^53", function()
    local t = Ti.new({ unit = 4.365, depth = Ti.safe_depth() })
    local hats = t:hats_in_box({ left=-3000, top=-3000, right=3000, bottom=3000 })
    assert.is_true(#hats > 0)
    local worst = 0
    for _, h in ipairs(hats) do
      local c = T.max_coefficient(h.xf)
      if c > worst then worst = c end
    end
    assert.is_true(worst < 2 ^ 53, "max coefficient " .. worst .. " exceeds 2^53")
  end)

  it("uses no platform-nondeterministic functions in shipped modules", function()
    for _, name in ipairs({ "exact", "transform", "geometry", "index", "tiling" }) do
      local f = assert(io.open("hat/" .. name .. ".lua", "r"))
      local src = f:read("*a"); f:close()
      -- strip comments so prose about the rule is not flagged
      src = src:gsub("%-%-[^\n]*", "")
      assert.is_nil(src:find("math%.sin"), name .. " uses math.sin")
      assert.is_nil(src:find("math%.cos"), name .. " uses math.cos")
      assert.is_nil(src:find("math%.random"), name .. " uses math.random")
      assert.is_nil(src:find("%^"), name .. " uses the pow operator")
    end
  end)

  it("never mutates a returned transform on a later call", function()
    local t = Ti.new({ unit = 4, depth = 3 })
    local b = { left=-100, top=-100, right=100, bottom=100 }
    local first = t:hats_in_box(b)
    local snap = {}
    for i, h in ipairs(first) do snap[i] = h.xf.m[3][1] end
    t:hats_in_box(b)
    for i, h in ipairs(first) do assert.are.equal(snap[i], h.xf.m[3][1]) end
  end)

  it("overflows past the safe depth, as documented", function()
    -- guards the ceiling: if this ever passes, the limit has moved and
    -- Ti.safe_depth() plus the spec must be updated together.
    local t = Ti.new({ unit = 4.365, depth = Ti.safe_depth() + 2 })
    local worst = 0
    for _, h in ipairs(t:hats_in_box({left=-3000,top=-3000,right=3000,bottom=3000})) do
      local c = T.max_coefficient(h.xf)
      if c > worst then worst = c end
    end
    assert.is_true(worst > 2 ^ 53,
      "per-level rules no longer overflow at depth " .. (Ti.safe_depth() + 2))
  end)

  it("reports coverage that grows with depth", function()
    local prev = 0
    for d = 0, Ti.max_depth() do
      local c = Ti.new({ unit = 4.365, depth = d }):coverage()
      assert.is_true(c > prev, "coverage must increase at depth " .. d)
      prev = c
    end
  end)

  it("data files are generated, not hand-edited", function()
    for _, p in ipairs({ "data/hat_rules.lua", "data/hat_geometry.lua" }) do
      local f = assert(io.open(p, "r"))
      local head = f:read("*l"); f:close()
      assert.is_not_nil(head:find("GENERATED"), p .. " lost its header")
    end
  end)
end)
