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

## Showcase screenshots

```bash
tools/showcase.sh                 # all five planets
tools/showcase.sh nauvis gleba    # some of them
```

`showcase.sh` builds a base in five stages on each planet, with the mod in
`tools/showcase/`. It takes a screenshot of each stage and a wide shot of the
last one, and records a silent clip of each stage. The screenshots go to
`docs/preview/showcase/` and the clips to `~/Videos/hattorio-showcase/`.

The script runs the Steam copy of Factorio with graphics, because a
screenshot needs a renderer. The game gets its own config, mods and save
folders in `~/.cache/hattorio/showcase/`, so your own game stays as it is. A
game window opens while the script runs.

The builder places a building only where the game allows it, so no building
stands on a band. A stage fails if fewer than 60% of its miners, furnaces and
assemblers work. A machine counts as working if it works at any of 30
checks, one each second, at the end of 5 minutes of game time. The script
also stops after 5 minutes without progress, and after an hour in all.

```bash
FACTORIO_API_KEY=... python3 -m tools.portal_images FIRST.jpg [MORE.jpg ...]
```

`portal_images.py` adds the images to the gallery of the mod page. The
first file leads the gallery, then the images that the gallery has
already, then the other new files. The key needs the *ModPortal: Edit
Mods* permission. Each run uploads the files again, so run it once for
each set of new images.
