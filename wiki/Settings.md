# Settings

Two settings per planet, both fixed when the world is created.

| Setting | Default | Choices |
|---|---|---|
| Cell size (centre to vertex, in tiles) | **41** (normal) | 15, 26, 41, 52 |
| Band width (tiles) | **3** (wide) | 1, 2, 3, 4 |
| Band appearance | Dark liquid | liquid, void, glowing rift |

Cell size and band width are dropdowns, labelled with how hard each makes the
game. They are set per planet.

## Hat size is the dial

It decides how much room a cell gives you, and — more importantly — how large
a blueprint can still be reused everywhere.

| Size | Difficulty | Cell area | Largest blueprint that fits every cell |
|---|---|---|---|
| 15 | very hard | 116 tiles | about 5×5 |
| 26 | hard | 347 tiles | 11×11 |
| **41** (default) | **normal** | **944 tiles** | **18×18** |
| 52 | easy | 1,584 tiles | 23×23 |

For scale: a smelter block is around 20×20 and a mall around 30×30. **Every
size on this table breaks those**, so the choice is not whether blueprints
survive — it is how much room you get to improvise in.

- **15** is brutal. One machine and some belt. Novel, probably exhausting.
- **26** is hard. 11×11 is roughly one assembler cluster: enough that you are
  building, not fighting, while everything larger is hand-fitted.
- **41** is the default. Real sub-builds per cell, spaghetti mostly between
  them, and every imported blueprint still breaks.
- **52** matches Hextorio's hexagons by area, if you want that feel.

![size 15](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-15-2.png)
![size 26](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-26-2.png)
![size 41](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-41-2.png)
![size 52](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-52-2.png)

## Band appearance

Three styles, all of them dark. **Dark liquid** is the default: an animated
surface that moves and oozes. **Void** is flat and still, a hole rather than a
liquid. **Glowing rift** uses the lava shader and needs Space Age; without it
the mod falls back to dark liquid and says so in the log.

## Band width

How wide the unbuildable strip is. Keep it below underground-belt reach or
cells become genuinely isolated. 2 is a good default: clearly visible,
crossable by every underground tier.

Wider bands eat more of the map — the unbuildable fraction scales roughly
linearly with it.

## Why you cannot change these mid-game

The geometry decides the terrain. Changing it under an existing save would
leave every generated chunk built to the old geometry and every new one to
the new, and the seam between them would be permanent.

Changing the setting later affects **only newly created surfaces**. Existing
ones keep the geometry their terrain was built with, so nothing ever seams.

## Ore

Bands cut through ore patches, and a mining drill needs a clear 3×3, so some
ore ends up unreachable — from about 40% reachable at size 26 up to 68% at
size 41. Resource richness is raised to compensate, scaled to your size
setting.
