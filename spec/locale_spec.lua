-- Guards on the locale files.
--
-- These failures are all silent in-game: a mangled value shows as truncated
-- text, a mangled key shows as the raw key like
-- "hattorio-band-colour-violet". None of them crash, so none of them announce
-- themselves.

local function locale_files()
  -- busted runs from the repo root, and there is only the one language today
  return { "locale/en/hattorio.cfg" }
end

local function read(path)
  local f = assert(io.open(path, "r"), "cannot open " .. path)
  local s = f:read("*a")
  f:close()
  return s
end

describe("locale", function()
  it("never puts a semicolon in a value", function()
    -- Factorio's .cfg format documents ';' as a comment marker. Whether it is
    -- honoured mid-line is undocumented, and vanilla never risks it: zero of
    -- 7,301 vanilla English values contain one, while '#' appears four times.
    -- Cheaper to avoid than to depend on.
    for _, path in ipairs(locale_files()) do
      local n = 0
      for line in read(path):gmatch("[^\n]+") do
        n = n + 1
        if not line:match("^%s*[;#]") and not line:match("^%s*%[") then
          assert.is_nil(line:find(";", 1, true),
            path .. ":" .. n .. " has a semicolon in a value: " .. line)
        end
      end
    end
  end)

  it("has no whitespace around the equals sign in keys", function()
    -- "title =Value" defines the key "title " with a trailing space, which
    -- then never matches. Factorio gives no warning.
    for _, path in ipairs(locale_files()) do
      local n = 0
      for line in read(path):gmatch("[^\n]+") do
        n = n + 1
        if line:find("=", 1, true) and not line:match("^%s*[;#]")
           and not line:match("^%s*%[") then
          assert.is_nil(line:match("^[^=]*%s="),
            path .. ":" .. n .. " has whitespace before '=': " .. line)
        end
      end
    end
  end)

  it("declares no key twice", function()
    for _, path in ipairs(locale_files()) do
      local seen, section = {}, ""
      for line in read(path):gmatch("[^\n]+") do
        local header = line:match("^%s*%[(.-)%]%s*$")
        if header then
          section = header
        elseif not line:match("^%s*[;#]") then
          local key = line:match("^([^=]+)=")
          if key then
            local full = section .. "." .. key
            assert.is_nil(seen[full], "duplicate key " .. full .. " in " .. path)
            seen[full] = true
          end
        end
      end
    end
  end)

  it("puts every key inside a section", function()
    for _, path in ipairs(locale_files()) do
      local section, n = nil, 0
      for line in read(path):gmatch("[^\n]+") do
        n = n + 1
        if line:match("^%s*%[(.-)%]%s*$") then
          section = line
        elseif line:find("=", 1, true) and not line:match("^%s*[;#]") then
          assert.is_not_nil(section,
            path .. ":" .. n .. " defines a key before any [section]")
        end
      end
    end
  end)
end)
