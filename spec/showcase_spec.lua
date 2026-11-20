-- The pure logic of the showcase tool in tools/showcase/: placement, belt
-- routes under bands, and the camera path.

local Place = require("tools.showcase.place")
local Camera = require("tools.showcase.camera")

-- blocked["x,y"] = true for a band tile.
local function grid(blocked)
  return function(_, x, y) return not blocked[x .. "," .. y] end
end

describe("showcase placement", function()
  it("spirals out from the centre", function()
    local p = Place.spiral(0, 0, 4, 9)
    assert.are.same({ 0, 0 }, p[1])
    assert.are.equal(9, #p)
    for i = 2, 9 do assert.is_true(math.abs(p[i][1]) <= 4 and math.abs(p[i][2]) <= 4) end
  end)

  it("fits a layout only where every building can go", function()
    local layout = { { "stone-furnace", 0, 0 }, { "stone-furnace", 2, 0 } }
    assert.is_true(Place.fit(layout, { 0, 0 }, grid({})))
    assert.is_false(Place.fit(layout, { 0, 0 }, grid({ ["2,0"] = true })))
  end)

  it("gives up when a layout fits nowhere", function()
    local layout = { { "stone-furnace", 0, 0 } }
    assert.is_nil(Place.find(layout, { 0, 0 }, 4, 25, function() return false end))
  end)

  it("routes a belt under a band with the cheapest underground", function()
    local band = { ["5,0"] = true, ["6,0"] = true, ["7,0"] = true }
    local route = Place.route({ 0, 0 }, "east", 12, grid(band),
      { { "underground-belt", 4 }, { "fast-underground-belt", 6 } })
    local names = {}
    for _, e in ipairs(route) do names[#names + 1] = e[1] end
    assert.are.equal("underground-belt", names[5])
    assert.are.equal("underground-belt", names[6])
  end)

  it("takes the next tier for a wider gap, and gives up past the last", function()
    local five = {}
    for x = 5, 9 do five[x .. ",0"] = true end
    local tiers = { { "underground-belt", 4 }, { "fast-underground-belt", 6 } }
    local route = Place.route({ 0, 0 }, "east", 14, grid(five), tiers)
    assert.are.equal("fast-underground-belt", route[5][1])
    local nine = {}
    for x = 5, 13 do nine[x .. ",0"] = true end
    assert.is_nil(Place.route({ 0, 0 }, "east", 18, grid(nine), tiers))
  end)
end)

describe("showcase camera", function()
  it("pans from start to end in the given number of frames", function()
    local path = Camera.pan({ 0, 0 }, { 100, 50 }, 600)
    assert.are.equal(600, #path)
    assert.are.same({ 0, 0 }, path[1])
    assert.are.same({ 100, 50 }, path[600])
    assert.is_true(path[2][1] - path[1][1] < path[301][1] - path[300][1])
  end)
end)
