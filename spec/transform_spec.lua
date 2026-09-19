local E = require("hat.exact")
local T = require("hat.transform")

local function tr(dx, dy)
  return T.new({ E.ONE, E.ZERO, E.new(dx, 0, 0, 0),
                 E.ZERO, E.ONE, E.new(dy, 0, 0, 0) }, 1)
end

describe("transform", function()
  it("applies the identity unchanged", function()
    local x, y = T.apply_float(T.IDENTITY, 3, 4)
    assert.is_true(math.abs(x - 3) < 1e-12 and math.abs(y - 4) < 1e-12)
  end)

  it("composes translations", function()
    local x, y = T.origin_float(T.mul(tr(2, 3), tr(10, 20)))
    assert.is_true(math.abs(x - 12) < 1e-12 and math.abs(y - 23) < 1e-12)
  end)

  it("reduces by gcd", function()
    -- every numerator even with an even denominator must come back halved
    local x = T.new({ E.new(4, 2, 0, 0), E.ZERO, E.new(6, 0, 0, 0),
                      E.ZERO, E.new(4, 0, 0, 0), E.new(2, 0, 0, 0) }, 2)
    local r = T.mul(T.IDENTITY, x)
    assert.are.equal(1, r.den)
    assert.are.equal(2, r.m[1][1])
    assert.are.equal(1, r.m[1][2])
    assert.are.equal(3, r.m[3][1])
  end)

  it("leaves an already-reduced transform alone", function()
    -- a genuine 1/2^n scaling cannot reduce: numerators are 1, sharing no
    -- factor with the denominator. Reduction must not corrupt it.
    local half = T.new({ E.ONE, E.ZERO, E.ZERO, E.ZERO, E.ONE, E.ZERO }, 2)
    local acc = T.IDENTITY
    for _ = 1, 10 do acc = T.mul(acc, half) end
    assert.are.equal(2 ^ 10, acc.den)
    assert.is_true(math.abs(T.scale_float(acc) - 1 / 1024) < 1e-15)
  end)

  it("keeps coefficients bounded when composing a scaling repeatedly", function()
    local s = T.new({ E.new(3, 0, 0, 0), E.ZERO, E.ZERO,
                      E.ZERO, E.new(3, 0, 0, 0), E.ZERO }, 3)
    local acc = T.IDENTITY
    for _ = 1, 40 do acc = T.mul(acc, s) end
    assert.is_true(T.max_coefficient(acc) < 2 ^ 53)
    assert.are.equal(1, acc.den)
  end)

  it("detects reflection by the sign of the determinant", function()
    local flip = T.new({ E.ONE, E.ZERO, E.ZERO, E.ZERO, E.neg(E.ONE), E.ZERO }, 1)
    assert.is_true(T.is_reflected(flip))
    assert.is_false(T.is_reflected(T.IDENTITY))
  end)

  it("reports uniform scale", function()
    local two = T.new({ E.new(2, 0, 0, 0), E.ZERO, E.ZERO,
                        E.ZERO, E.new(2, 0, 0, 0), E.ZERO }, 1)
    assert.is_true(math.abs(T.scale_float(two) - 2) < 1e-12)
  end)

  it("builds from 24 emitted integers", function()
    local ints = {}
    for i = 1, 24 do ints[i] = 0 end
    ints[1] = 1    -- a
    ints[17] = 1   -- e  (element 5, first slot: (5-1)*4+1)
    local x, y = T.apply_float(T.from_ints(ints, 1), 7, 9)
    assert.is_true(math.abs(x - 7) < 1e-12 and math.abs(y - 9) < 1e-12)
  end)

  it("is associative under composition", function()
    local a, b, c = tr(1, 2), tr(-3, 5), tr(7, -1)
    local x1, y1 = T.origin_float(T.mul(T.mul(a, b), c))
    local x2, y2 = T.origin_float(T.mul(a, T.mul(b, c)))
    assert.is_true(math.abs(x1 - x2) < 1e-12 and math.abs(y1 - y2) < 1e-12)
  end)

  it("never mutates its arguments", function()
    local a = tr(1, 1)
    local before = a.m[3][1]
    T.mul(a, tr(5, 5))
    assert.are.equal(before, a.m[3][1])
    assert.are.equal(1, a.den)
  end)
end)
