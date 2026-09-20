# Settings

Two settings per planet, both fixed when the world is created.

| Setting | Default | Range |
|---|---|---|
| Hat size (centre to vertex, in tiles) | **26** | 15–90 |
| Band width (tiles) | **2** | 1–6 |

## Hat size is the dial

It decides how much room a cell gives you, and — more importantly — how large
a blueprint can still be reused everywhere.

| Size | Cell area | Unbuildable | Largest blueprint that fits every cell |
|---|---|---|---|
| 15 | 116 tiles | 37% | about 5×5 |
| **26** (default) | **347 tiles** | **22%** | **11×11** |
| 41 | 944 tiles | 15% | 18×18 |
| 52 | 1,584 tiles | 12% | 23×23 |

For scale: a smelter block is around 20×20 and a mall around 30×30. **Every
size on this table breaks those**, so the choice is not whether blueprints
survive — it is how much room you get to improvise in.

- **15** is brutal. One machine and some belt. Novel, probably exhausting.
- **26** is the default because 11×11 is roughly one assembler cluster: enough
  that you are building, not fighting, while everything larger is hand-fitted.
- **41** is comfortable. Real sub-builds per cell, spaghetti mostly between them.
- **52** matches Hextorio's hexagons by area, if you want that feel.

![size 15](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-15-2.png)
![size 26](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-26-2.png)
![size 41](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-41-2.png)
![size 52](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-52-2.png)

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
