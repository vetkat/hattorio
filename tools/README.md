# tools/

This is the offline pipeline. It does not ship with the mod. It needs Python
3.11 or later and uses only the standard library.

```bash
python3 -m tools.emit_lua      # regenerate data/*.lua
python3 -m tools.export_golden # regenerate spec fixtures
python3 -m pytest tools/tests  # pipeline tests
```

## Previewing the tiling

```bash
lua5.2 tools/render.lua [depth] [unit] [extent] [out.svg]
lua5.2 tools/render_bands.lua [hat-size] [band] [tiles] [out.svg]
```

`render.lua` draws the tiling itself, with reflected hats in dark blue.
`render_bands.lua` shows how the mod will look in the game: it rasterises the
hat cells onto Factorio's tile grid and puts unbuildable bands between them.

Both scripts use the Lua descent, so they run the same code that ships.
To make a PNG, run `rsvg-convert -w 900 x.svg -o x.png`.
