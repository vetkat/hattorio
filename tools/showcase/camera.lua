-- The camera path of a showcase clip. Pure: no Factorio API.

local Camera = {}

--- `frames` positions from `from` to `to`, eased in and out (smoothstep).
function Camera.pan(from, to, frames)
  local out = {}
  for i = 1, frames do
    local t = (i - 1) / (frames - 1)
    local s = t * t * (3 - 2 * t)
    out[i] = { from[1] + (to[1] - from[1]) * s, from[2] + (to[2] - from[2]) * s }
  end
  return out
end

return Camera
