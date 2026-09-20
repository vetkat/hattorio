-- Band colourways, selected by a startup setting.
--
-- `body` is the surface itself and is near-black in every option: the bands
-- are meant to read as depth, not as paint. `highlight` is what the shader
-- catches at the edges, and is what actually distinguishes one option from
-- another -- comparing the bodies alone, they are indistinguishable.
--
-- `mirror` tints the reflected cells, about one in eight, which are a
-- mathematical property of this tiling rather than a decoration.
--
-- Colour is independent of band style: any of these works with the animated
-- liquid, the flat void or the glowing rift.
return {
  violet = { body = { 30, 19, 48 }, highlight = { 74, 45, 114 }, mirror = { 150, 96, 200 } },
  cold   = { body = { 23, 27, 34 }, highlight = { 46, 58, 69 },  mirror = { 70, 110, 150 } },
  oily   = { body = { 14, 26, 19 }, highlight = { 31, 63, 43 },  mirror = { 90, 170, 110 } },
  ember  = { body = { 29, 16, 11 }, highlight = { 90, 42, 18 },  mirror = { 210, 110, 50 } },
  ink    = { body = { 4, 4, 6 },    highlight = { 10, 10, 14 },  mirror = { 90, 90, 110 } },
}
