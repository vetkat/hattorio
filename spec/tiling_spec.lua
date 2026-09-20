local Ti = require("hat.tiling")
local T = require("hat.transform")
local I = require("hat.index")

local function box(l, t, r, b) return { left = l, top = t, right = r, bottom = b } end
local ALL = box(-1e7, -1e7, 1e7, 1e7)

describe("tiling descent", function()
  it("produces hats for a box at the origin", function()
    assert.is_true(#Ti.new({ unit = 4, depth = 2 }):hats_in_box(box(-50,-50,50,50)) > 0)
  end)

  it("returns nothing for a box far outside the root", function()
    assert.are.equal(0, #Ti.new({ unit = 4, depth = 1 })
      :hats_in_box(box(1e6, 1e6, 1e6 + 32, 1e6 + 32)))
  end)

  it("gives every hat a distinct path", function()
    local seen = {}
    for _, h in ipairs(Ti.new({ unit = 4, depth = 2 }):hats_in_box(ALL)) do
      assert.is_nil(seen[h.path], "duplicate path")
      seen[h.path] = true
    end
  end)

  it("produces F(2n+3)^2 hats with no pruning", function()
    local want = { [0] = 4, [1] = 25, [2] = 169, [3] = 1156 }
    for d = 0, 3 do
      assert.are.equal(want[d], #Ti.new({ unit = 1, depth = d }):hats_in_box(ALL),
                       "depth " .. d)
    end
  end)

  it("is deterministic across calls", function()
    local t = Ti.new({ unit = 4, depth = 2 })
    local a, b = t:hats_in_box(box(-80,-80,80,80)), t:hats_in_box(box(-80,-80,80,80))
    assert.are.equal(#a, #b)
    for i = 1, #a do assert.are.equal(a[i].path, b[i].path) end
  end)

  it("is monotone in box size", function()
    local t = Ti.new({ unit = 4, depth = 3 })
    assert.is_true(#t:hats_in_box(ALL) >= #t:hats_in_box(box(-40,-40,40,40)))
  end)

  it("prunes without dropping hats that meet the box", function()
    local t = Ti.new({ unit = 4, depth = 3 })
    local G = require("hat.geometry")
    local b = box(-60, -60, 60, 60)
    local pruned = {}
    for _, h in ipairs(t:hats_in_box(b)) do pruned[h.path] = true end
    for _, h in ipairs(t:hats_in_box(ALL)) do
      local poly = G.polygon(h.xf, 4)
      local inside = false
      for _, p in ipairs(poly) do
        if p.x >= b.left and p.x <= b.right and p.y >= b.top and p.y <= b.bottom then
          inside = true; break
        end
      end
      if inside then assert.is_true(pruned[h.path] or false, "dropped " .. h.path) end
    end
  end)

  it("marks some hats reflected, near 1/(phi^4+1)", function()
    local hats = Ti.new({ unit = 1, depth = 3 }):hats_in_box(ALL)
    local r = 0
    for _, h in ipairs(hats) do if h.reflected then r = r + 1 end end
    local phi = (1 + math.sqrt(5)) / 2
    assert.is_true(math.abs(r / #hats - 1 / (phi ^ 4 + 1)) < 0.05)
  end)

  it("reproduces the Python golden fixture exactly", function()
    local golden = dofile("spec/fixtures/golden_depth3.lua")
    local hats = Ti.new({ unit = 1, depth = 3 }):hats_in_box(ALL)
    assert.are.equal(#golden, #hats)
    local by_path = {}
    for _, h in ipairs(hats) do by_path[h.path] = h end
    for _, g in ipairs(golden) do
      local path = {}
      for n in g.path:gmatch("[^,]+") do path[#path + 1] = tonumber(n) end
      local h = by_path[I.encode(path)]
      assert.is_not_nil(h, "missing hat " .. g.path)
      local x, y = T.origin(h.xf)
      assert.is_true(math.abs(x - g.x) < 1e-6, "x mismatch at " .. g.path)
      assert.is_true(math.abs(y - g.y) < 1e-6, "y mismatch at " .. g.path)
      assert.are.equal(g.reflected, h.reflected, "chirality at " .. g.path)
    end
  end)

  it("rejects a depth beyond the generated data", function()
    assert.has_error(function() Ti.new({ depth = Ti.max_depth() + 1 }) end)
  end)
end)

describe("depth derivation", function()
  local CIRC = require("data.hat_geometry").circumradius

  it("derives a depth that covers a requested radius", function()
    for _, size in ipairs({ 15, 20, 26, 41, 52, 90 }) do
      local unit = size / CIRC
      local t = Ti.new({ unit = unit, cover = 1.1e6 })
      assert.is_true(t:coverage() >= 1.1e6,
        "size " .. size .. " covers only " .. t:coverage())
    end
  end)

  it("picks a deeper root for a smaller hat", function()
    local small = Ti.new({ unit = 15 / CIRC, cover = 1.1e6 })
    local large = Ti.new({ unit = 90 / CIRC, cover = 1.1e6 })
    assert.is_true(small.depth > large.depth)
  end)

  it("errors rather than silently under-covering", function()
    assert.has_error(function() Ti.new({ unit = 1e-6, cover = 1e12 }) end)
  end)
end)

describe("root coverage", function()
  local G = require("hat.geometry")

  it("fully tiles a box well inside the root, with no gaps", function()
    local unit = Ti.unit_for_hat_size(26)
    local t = Ti.new({ unit = unit, cover = 2000 })
    local b = { left = -300, top = -300, right = 300, bottom = 300 }
    local polys = {}
    for i, h in ipairs(t:hats_in_box(b)) do polys[i] = G.polygon(h.xf, unit) end
    local miss = 0
    for y = -299, 299, 7 do
      for x = -299, 299, 7 do
        local inside = false
        for i = 1, #polys do
          if G.point_in_polygon(x + 0.5, y + 0.5, polys[i]) then inside = true break end
        end
        if not inside then miss = miss + 1 end
      end
    end
    assert.are.equal(0, miss, miss .. " uncovered points")
  end)

  it("converts hat size to unit and back", function()
    for _, size in ipairs({ 15, 26, 41, 90 }) do
      local u = Ti.unit_for_hat_size(size)
      assert.is_true(math.abs(Ti.hat_size_for_unit(u) - size) < 1e-9)
    end
  end)
end)
