local T = require("hat.transform")

local function tr(dx, dy) return { 1, 0, dx, 0, 1, dy } end
local function near(a, b) return math.abs(a - b) < 1e-12 end

describe("transform", function()
  it("applies the identity unchanged", function()
    local x, y = T.apply(T.IDENTITY, 3, 4)
    assert.is_true(near(x, 3) and near(y, 4))
  end)

  it("composes translations", function()
    local x, y = T.origin(T.mul(tr(2, 3), tr(10, 20)))
    assert.is_true(near(x, 12) and near(y, 23))
  end)

  it("is associative", function()
    local a, b, c = tr(1, 2), { 0, -1, 3, 1, 0, 5 }, tr(7, -1)
    local x1, y1 = T.origin(T.mul(T.mul(a, b), c))
    local x2, y2 = T.origin(T.mul(a, T.mul(b, c)))
    assert.is_true(near(x1, x2) and near(y1, y2))
  end)

  it("detects reflection by the sign of the determinant", function()
    assert.is_true(T.is_reflected({ 1, 0, 0, 0, -1, 0 }))
    assert.is_false(T.is_reflected(T.IDENTITY))
  end)

  it("reports uniform scale", function()
    assert.is_true(near(T.scale({ 2, 0, 0, 0, 2, 0 }), 2))
    assert.is_true(near(T.scale({ 0, -3, 0, 3, 0, 0 }), 3))
  end)

  it("composes a rotation six times back to the identity", function()
    local h, s = 0.5, math.sqrt(3) / 2
    local r = { h, -s, 0, s, h, 0 }
    local acc = T.IDENTITY
    for _ = 1, 6 do acc = T.mul(acc, r) end
    assert.is_true(near(acc[1], 1) and near(acc[5], 1))
    assert.is_true(math.abs(acc[2]) < 1e-14 and math.abs(acc[4]) < 1e-14)
  end)

  it("never mutates its arguments", function()
    local a, b = tr(1, 1), tr(5, 5)
    T.mul(a, b)
    assert.are.equal(1, a[3])
    assert.are.equal(5, b[3])
  end)
end)
