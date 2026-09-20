-- Which surfaces get tiled, and what the band looks like there.
--
-- All three band styles clone `deepwater`. That is not laziness: its
-- transitions are authored for "liquid meets land", which is exactly the edge
-- a rift needs, and it is the only base tile carrying an animated shader.
-- The styles differ only in the effect and the colours laid over it.
--
--   liquid  the water shader, recoloured dark -- it moves and oozes
--   void    no effect at all -- a flat, still hole in the world
--   rift    Vulcanus's lava shader -- glows, REQUIRES Space Age
--
-- effect_color is the body of the surface; effect_color_secondary is the
-- highlight the shader catches at the edges.
return {
  nauvis   = { map_color = { 23, 27, 34 },  mirror_color = { 20, 121, 201 } },
  vulcanus = { map_color = { 29, 16, 11 },  mirror_color = { 176, 64, 32 } },
  fulgora  = { map_color = { 30, 19, 48 },  mirror_color = { 150, 96, 200 } },
  gleba    = { map_color = { 14, 26, 19 },  mirror_color = { 120, 170, 70 } },
  aquilo   = { map_color = { 26, 32, 38 },  mirror_color = { 120, 180, 210 } },
}
