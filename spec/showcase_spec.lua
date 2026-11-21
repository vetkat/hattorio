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

  it("finds the first place along a line where a layout fits", function()
    local layout = { { "stone-furnace", 0, 0 }, { "stone-furnace", 0, 1 } }
    local blocked = { ["10,0"] = true, ["11,1"] = true }
    local origin, k = Place.find_along(layout, { 0, 0 }, "east", 10, 20, grid(blocked))
    assert.are.same({ 12, 0 }, origin)
    assert.are.equal(12, k)
    assert.is_nil(Place.find_along(layout, { 0, 0 }, "east", 10, 20, function() return false end))
  end)

  it("bends once when nothing fits on the straight line", function()
    local layout = { { "stone-furnace", 0, 0 } }
    -- Only (6, 5) is free for the furnace. The line x = 0 is all blocked for it.
    local function can_place(name, x, y)
      if name == "stone-furnace" then return x == 6 and y == 5 end
      return true
    end
    local origin, k, side, j = Place.find_bent(layout, { 0, 0 }, "south", 10, 10, can_place)
    assert.are.same({ 6, 5 }, origin)
    assert.are.equal(5, k)
    assert.are.equal("east", side)
    assert.are.equal(6, j)
    assert.is_nil(Place.find_bent(layout, { 0, 0 }, "south", 10, 10, function() return false end))
  end)

  it("goes west on a straight line only where the block leaves the route free", function()
    local layout = { { "stone-furnace", 0, 0 } }
    local function covers(origin)
      return function(x, y) return y == origin[2] and x >= origin[1] and x <= origin[1] + 6 end
    end
    local tiers = { { "underground-belt", 4 } }
    local free = function() return true end
    assert.is_nil(Place.find_along(layout, { 0, 0 }, "west", 4, 6, free, tiers, covers))
    assert.are.same({ -4, 0 },
      Place.find_along(layout, { 0, 0 }, "west", 4, 6, free, tiers, function(o)
        return function(x, y) return x == o[1] and y == o[2] end
      end))
  end)

  it("bends west only where the block does not cover its own route", function()
    -- The block reaches 6 tiles east of its origin.
    local function covers(origin)
      return function(x, y) return y == origin[2] and x >= origin[1] and x <= origin[1] + 6 end
    end
    local layout = { { "stone-furnace", 0, 0 } }
    -- The only free spot for the furnace is west of the line, at (-4, 5).
    local function can_place(name, x, y)
      if name == "stone-furnace" then return x == -4 and y == 5 end
      return true
    end
    local tiers = { { "underground-belt", 4 } }
    assert.is_nil(Place.find_bent(layout, { 0, 0 }, "south", 10, 10, can_place, tiers, covers))
    local function short(origin)
      return function(x, y) return x == origin[1] and y == origin[2] end
    end
    local origin, _, side = Place.find_bent(layout, { 0, 0 }, "south", 10, 10, can_place, tiers,
      short)
    assert.are.same({ -4, 5 }, origin)
    assert.are.equal("west", side)
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

describe("showcase routes stay inside their length", function()
  local tiers = { { "underground-belt", 4 } }

  it("refuses a route whose gap runs to its last tile", function()
    local band = { ["0,8"] = true, ["0,9"] = true }
    assert.is_nil(Place.route({ 0, 0 }, "south", 10, grid(band), tiers))
    assert.is_not_nil(Place.route({ 0, 0 }, "south", 12, grid(band), tiers))
  end)

  it("skips a place that no route can reach", function()
    local layout = { { "stone-furnace", 0, 0 } }
    -- A band just before x = 10 leaves no room for the exit of the route.
    local band = { ["8,0"] = true, ["9,0"] = true }
    local origin = Place.find_along(layout, { 0, 0 }, "east", 8, 20, grid(band), tiers)
    assert.are.same({ 11, 0 }, origin)
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
