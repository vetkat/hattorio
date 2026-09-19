local T = require("hat.transform")
local G = require("hat.geometry")

describe("hat geometry", function()
  it("has 13 outline vertices", function()
    assert.are.equal(13, #G.OUTLINE)
  end)

  it("matches hatviz's hexPt outline", function()
    local hr3 = math.sqrt(3) / 2
    local hex = { {0,0},{-1,-1},{0,-2},{2,-2},{2,-1},{4,-2},{5,-1},
                  {4,0},{3,0},{2,2},{0,3},{0,2},{-1,2} }
    for i = 1, 13 do
      local x, y = hex[i][1] + 0.5 * hex[i][2], hr3 * hex[i][2]
      assert.is_true(math.abs(G.OUTLINE[i][1] - x) < 1e-9, "x @" .. i)
      assert.is_true(math.abs(G.OUTLINE[i][2] - y) < 1e-9, "y @" .. i)
    end
  end)

  it("reports a circumradius near 4.5826", function()
    assert.is_true(math.abs(G.RADIUS - 4.5826) < 0.001)
  end)

  it("produces 13 world-space vertices and edges", function()
    assert.are.equal(13, #G.polygon(T.IDENTITY, 1))
    assert.are.equal(13, #G.edges(T.IDENTITY, 1))
  end)

  it("closes the edge loop", function()
    local e = G.edges(T.IDENTITY, 1)
    assert.is_true(math.abs(e[13][3] - e[1][1]) < 1e-12)
    assert.is_true(math.abs(e[13][4] - e[1][2]) < 1e-12)
  end)

  it("scales with unit", function()
    local p = G.polygon(T.IDENTITY, 10)
    assert.is_true(math.abs(p[7].x - 45) < 1e-9)
  end)

  it("has the expected area", function()
    local p = G.polygon(T.IDENTITY, 1)
    local a = 0
    for i = 1, #p do
      local q = p[i % #p + 1]
      a = a + p[i].x * q.y - q.x * p[i].y
    end
    assert.is_true(math.abs(math.abs(a) / 2 - 13.856406) < 1e-5)
  end)

  it("tests point containment", function()
    local poly = G.polygon(T.IDENTITY, 1)
    assert.is_true(G.point_in_polygon(0.5, 0.2, poly))
    assert.is_false(G.point_in_polygon(100, 100, poly))
  end)

  it("measures distance to a segment", function()
    assert.is_true(math.abs(G.dist_to_segment(0, 5, -10, 0, 10, 0) - 5) < 1e-12)
    assert.is_true(math.abs(G.dist_to_segment(20, 0, -10, 0, 10, 0) - 10) < 1e-12)
    assert.is_true(math.abs(G.dist_to_segment(3, 0, -10, 0, 10, 0)) < 1e-12)
  end)
end)
