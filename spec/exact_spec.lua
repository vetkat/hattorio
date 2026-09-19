local E = require("hat.exact")

-- Deterministic pseudo-random ring elements: property testing without a
-- generative-testing dependency. Fixed seeds, so failures reproduce exactly.
local function gen(seed)
  local s = seed
  local function nxt()
    s = (1103515245 * s + 12345) % 2147483648
    return (s % 41) - 20
  end
  return E.new(nxt(), nxt(), nxt(), nxt())
end

describe("exact ring", function()
  it("has phi^2 = phi + 1", function()
    assert.is_true(E.eq(E.mul(E.PHI, E.PHI), E.add(E.PHI, E.ONE)))
  end)

  it("has sqrt3^2 = 3", function()
    assert.is_true(E.eq(E.mul(E.SQRT3, E.SQRT3), E.new(3, 0, 0, 0)))
  end)

  it("has 1/phi^2 = 2 - phi as an integer element", function()
    local inv = E.sub(E.new(2, 0, 0, 0), E.PHI)
    assert.is_true(E.eq(E.mul(inv, E.mul(E.PHI, E.PHI)), E.ONE))
  end)

  it("is commutative, associative and distributive over many values", function()
    for seed = 1, 200 do
      local x, y, z = gen(seed), gen(seed + 1000), gen(seed + 2000)
      assert.is_true(E.eq(E.mul(x, y), E.mul(y, x)), "commutative @" .. seed)
      assert.is_true(E.eq(E.mul(E.mul(x, y), z), E.mul(x, E.mul(y, z))),
                     "associative @" .. seed)
      assert.is_true(E.eq(E.mul(x, E.add(y, z)),
                          E.add(E.mul(x, y), E.mul(x, z))),
                     "distributive @" .. seed)
      assert.is_true(E.eq(E.add(x, E.neg(x)), E.ZERO), "additive inverse @" .. seed)
      assert.is_true(E.eq(E.mul(x, E.ONE), x), "identity @" .. seed)
    end
  end)

  it("agrees with floating point", function()
    local phi, s3 = (1 + math.sqrt(5)) / 2, math.sqrt(3)
    for seed = 1, 100 do
      local x = gen(seed)
      local want = (x[1] + x[2] * phi) + (x[3] + x[4] * phi) * s3
      assert.is_true(math.abs(E.to_float(x) - want) < 1e-9, "float @" .. seed)
    end
  end)

  it("is multiplicatively consistent with floats", function()
    for seed = 1, 100 do
      local x, y = gen(seed), gen(seed + 500)
      local a, b = E.to_float(x), E.to_float(y)
      local got = E.to_float(E.mul(x, y))
      assert.is_true(math.abs(got - a * b) < 1e-6 * (1 + math.abs(a * b)),
                     "mul float @" .. seed)
    end
  end)

  it("never mutates its arguments", function()
    local x, y = E.new(1, 2, 3, 4), E.new(5, 6, 7, 8)
    local sx = { x[1], x[2], x[3], x[4] }
    local sy = { y[1], y[2], y[3], y[4] }
    E.mul(x, y); E.add(x, y); E.sub(x, y); E.neg(x)
    for i = 1, 4 do
      assert.are.equal(sx[i], x[i])
      assert.are.equal(sy[i], y[i])
    end
  end)

  it("exposes no division, so every operation is total", function()
    assert.is_nil(E.div)
    assert.is_nil(E.inverse)
  end)

  it("reports max absolute coefficient", function()
    assert.are.equal(9, E.max_abs(E.new(3, -9, 0, 4)))
  end)
end)
