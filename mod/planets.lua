-- Which surfaces get tiled, and what the band looks like there.
--
-- base_tile is a vanilla tile whose graphics and transitions are cloned; only
-- the name, colours and collision mask change. Cloning is what makes this
-- affordable: authoring tile transition graphics from scratch is the
-- expensive part, and vanilla has already done it.
--
-- NOTE: map_color differs per planet but the in-world graphics do not yet,
-- since they come from base_tile. Real per-planet art is a later job.
return {
  nauvis   = { base_tile = "stone-path", map_color = { 43, 47, 54 },
               mirror_color = { 20, 121, 201 } },
  vulcanus = { base_tile = "stone-path", map_color = { 38, 26, 24 },
               mirror_color = { 176, 64, 32 } },
  fulgora  = { base_tile = "stone-path", map_color = { 46, 38, 56 },
               mirror_color = { 150, 96, 200 } },
  gleba    = { base_tile = "stone-path", map_color = { 34, 46, 32 },
               mirror_color = { 120, 170, 70 } },
  aquilo   = { base_tile = "stone-path", map_color = { 48, 56, 62 },
               mirror_color = { 120, 180, 210 } },
}
