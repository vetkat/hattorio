local I = require("hat.index")

describe("hat index", function()
  it("round-trips a path", function()
    local p = { 0, 5, 28, 13, 1 }
    assert.are.same(p, I.decode(I.encode(p)))
  end)

  it("is exact for every legal child index", function()
    local p = {}
    for i = 0, 28 do p[#p + 1] = i end
    assert.are.same(p, I.decode(I.encode(p)))
  end)

  it("gives distinct keys for distinct paths", function()
    assert.are_not.equal(I.encode({ 1, 2, 3 }), I.encode({ 1, 3, 2 }))
    assert.are_not.equal(I.encode({ 1, 2 }), I.encode({ 1, 2, 0 }))
  end)

  it("uses prefixes as ancestors", function()
    local key = I.encode({ 4, 7, 2, 9 })
    assert.are.equal(I.encode({ 4, 7 }), I.ancestor(key, 2))
    assert.are.equal(key, I.ancestor(key, 4))
    assert.are.equal("", I.ancestor(key, 0))
  end)

  it("reports depth", function()
    assert.are.equal(4, I.depth(I.encode({ 1, 2, 3, 4 })))
    assert.are.equal(0, I.depth(I.encode({})))
  end)

  it("contains no zero bytes", function()
    assert.is_nil(I.encode({ 0, 0, 0 }):find("%z"))
  end)

  it("is stable and never uses lossy float formatting", function()
    -- the scaffold keyed identity off string.format("%.3f", ...), which is
    -- %.14g underneath and lossy. Byte packing is exact.
    assert.are.equal(I.encode({ 1, 2 }), I.encode({ 1, 2 }))
    assert.are.equal(2, #I.encode({ 1, 2 }))
  end)

  it("rejects out-of-range indices", function()
    assert.has_error(function() I.encode({ -1 }) end)
    assert.has_error(function() I.encode({ 255 }) end)
  end)
end)
