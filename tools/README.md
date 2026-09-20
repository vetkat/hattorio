# tools/

Offline pipeline. Not shipped with the mod. Requires Python 3.11+, stdlib only.

    python3 -m tools.emit_lua      # regenerate data/*.lua
    python3 -m tools.export_golden # regenerate spec fixtures
    python3 -m pytest tools/tests  # pipeline tests

## Previewing the tiling

    lua5.2 tools/render.lua [depth] [unit] [extent] [out.svg]
    lua5.2 tools/render_bands.lua [hat-size] [band] [tiles] [out.svg]

`render.lua` draws the tiling itself (reflected hats in dark blue).
`render_bands.lua` previews the mod as it will appear in game: hat cells
rasterised onto Factorio's tile grid with unbuildable bands between them.

Both render from the **Lua** descent, so they exercise the shipped code path.
Rasterise with `rsvg-convert -w 900 x.svg -o x.png`.
