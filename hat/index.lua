-- Stable hat identity: the descent path from root to hat, packed as bytes.
--
-- Exact by construction -- no float ever enters the key. Deliberately NOT
-- string.format on a coordinate, which is %.14g underneath and lossy enough
-- that two distinct hats can collide or one hat can produce two ids.
--
-- Prefixes are ancestors: ancestor(key, k) names the level-k supertile, which
-- gives any future region or territory layer a free hierarchy.

local I = {}

function I.encode(path)
  local parts = {}
  for i = 1, #path do
    local v = path[i]
    assert(type(v) == "number" and v >= 0 and v <= 254,
           "child index out of range: " .. tostring(v))
    parts[i] = string.char(v + 1)
  end
  return table.concat(parts)
end

function I.decode(key)
  local out = {}
  for i = 1, #key do
    out[i] = key:byte(i) - 1
  end
  return out
end

function I.ancestor(key, level)
  return key:sub(1, level)
end

function I.depth(key)
  return #key
end

return I
