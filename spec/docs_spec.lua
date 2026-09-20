-- Guards that the documentation still describes the software.
--
-- Every figure in the docs comes from a measurement, and the defaults have
-- moved twice. Both times the prose kept citing numbers from the previous
-- default, which is invisible until a reader tries to reconcile them. These
-- assertions tie the docs to Config, so a changed default fails the build
-- instead of silently making the README wrong.

local Config = require("mod.config")

local function read(path)
  local f = assert(io.open(path, "r"), "cannot open " .. path)
  local s = f:read("*a")
  f:close()
  return s
end

local DOCS = { "README.md", "wiki/Settings.md", "wiki/Home.md",
               "wiki/Building-in-hats.md", "docs/portal-description.md" }

describe("documentation", function()
  local default = Config.cell_stats(Config.DEFAULT_SIZE, Config.DEFAULT_BAND)

  it("has measurements for the defaults to quote", function()
    assert.is_not_nil(default)
  end)

  it("quotes the default cell area, not a previous default's", function()
    local area = tostring(default.area)
    local found = false
    for _, path in ipairs(DOCS) do
      if read(path):find(area, 1, true) then found = true end
    end
    assert.is_true(found,
      "no doc cites the default cell area of " .. area .. " tiles")
  end)

  it("quotes the default reusable-blueprint size", function()
    local sq = default.square
    local pattern = sq .. "×" .. sq          -- README and wiki use an en dash
    local found = false
    for _, path in ipairs(DOCS) do
      if read(path):find(pattern, 1, true) then found = true end
    end
    assert.is_true(found,
      "no doc cites the default largest square of " .. pattern)
  end)

  it("does not still present a superseded default as current", function()
    -- 26/2 and 41/2 were defaults at different points; their figures linger
    local stale = {}
    for _, size in ipairs(Config.SIZE_CHOICES) do
      for _, band in ipairs(Config.BAND_CHOICES) do
        if not (size == Config.DEFAULT_SIZE and band == Config.DEFAULT_BAND) then
          local st = Config.cell_stats(size, band)
          stale[#stale + 1] = { area = st.area, sq = st.square }
        end
      end
    end
    for _, path in ipairs(DOCS) do
      local text = read(path)
      for line in text:gmatch("[^\n]+") do
        if line:lower():find("default", 1, true) then
          for _, s in ipairs(stale) do
            -- a line naming the default must not also quote another
            -- combination's cell area
            assert.is_nil(line:find(tostring(s.area) .. " t", 1, true),
              path .. ": a line about the default cites " .. s.area ..
              " tiles, which belongs to a different setting: " .. line)
          end
        end
      end
    end
  end)

  it("does not claim the square grid is replaced", function()
    -- Factorio's grid is engine-level. The mod decides where you may build;
    -- it cannot and does not change the unit of construction.
    for _, path in ipairs({ "README.md", "wiki/Home.md", "info.json",
                            "docs/portal-description.md" }) do
      local text = read(path):lower()
      assert.is_nil(text:find("replaces the square grid", 1, true),
        path .. " claims to replace the square grid, which is not possible")
    end
  end)
end)
