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
-- Colour is independent of band style: each works with the animated liquid
-- and with the flat void.
return {
  violet = { body = { 30, 19, 48 }, highlight = { 98, 60, 152 }, mirror = { 158, 104, 208 } },
  cold   = { body = { 23, 27, 34 }, highlight = { 62, 78, 93 },  mirror = { 82, 124, 166 } },
  oily   = { body = { 14, 26, 19 }, highlight = { 42, 85, 58 },  mirror = { 102, 180, 122 } },
  ember  = { body = { 29, 16, 11 }, highlight = { 120, 56, 24 }, mirror = { 216, 120, 56 } },
  ink    = { body = { 4, 4, 6 },    highlight = { 18, 18, 24 },  mirror = { 104, 104, 126 } },
}
