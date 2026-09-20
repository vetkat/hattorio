-- Which surfaces get tiled.
--
-- A set rather than a list: mod/surface.lua tests membership by name, and
-- anything absent here is left as vanilla terrain -- including space
-- platforms and any planet a mod adds that we have no settings for.
--
-- Band colour is NOT per planet. It is a player setting, shared across every
-- surface, so that the mod looks like one thing rather than five.
return {
  nauvis = true,
  vulcanus = true,
  fulgora = true,
  gleba = true,
  aquilo = true,
}
