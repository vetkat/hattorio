# Settings

Two settings per planet, both fixed when the world is created.

| Setting | Default | Choices |
|---|---|---|
| Cell size (centre to vertex, in tiles) | **41** (normal) | 15, 26, 41, 52 |
| Band width (tiles) | **3** (wide) | 1, 2, 3, 4 |
| Band appearance | Dark liquid | liquid, void |
| Band colour | Deep violet | violet, cold, oily, ember, void black |

Cell size and band width are dropdowns, labelled with how hard each makes the
game. They are set per planet.

## Hat size is the dial

It decides how much room a cell gives you, and — more importantly — how large
a blueprint can still be reused everywhere.

At the default band width of 3:

| Size | Difficulty | Cell area | Largest blueprint that fits every cell |
|---|---|---|---|
| 15 | very hard | 63 tiles | 5×5 |
| 26 | hard | 294 tiles | 10×10 |
| **41** (default) | **normal** | **858 tiles** | **17×17** |
| 52 | easy | 1,473 tiles | 22×22 |

A wider band shrinks the cell, a narrower one grows it. At band 1 a size-41
cell holds 1,012 tiles and takes a 19×19 blueprint.

For scale: a smelter block is around 20×20 and a mall around 30×30. **Every
size on this table breaks those**, so the choice is not whether blueprints
survive — it is how much room you get to improvise in.

- **15** is brutal. One machine and some belt. Novel, probably exhausting.
- **26** is hard. 10×10 is roughly one assembler cluster: enough that you are
  building, not fighting, while everything larger is hand-fitted.
- **41** is the default. Real sub-builds per cell, spaghetti mostly between
  them, and every imported blueprint still breaks.
- **52** matches Hextorio's hexagons by area, if you want that feel.

![size 15](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-15-2.png)
![size 26](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-26-2.png)
![size 41](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-41-2.png)
![size 52](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-52-2.png)

## Band appearance

Two independent settings: what the bands are made of, and what colour they
are. Any combination works.

**Style** picks the surface. *Dark liquid* is the default: animated, it moves
and oozes. *Void* is flat and still, a hole rather than a liquid.

**Colour** tints it. Every option is near-black on purpose, so the bands read
as depth rather than paint — what separates them is the highlight the surface
catches at its edges. *Deep violet* is the default and the most deliberate
looking; *near-black cold*, *oily green-black* and *ember black* are quieter;
*pure void black* is a flat hole with no sheen at all.

Reflected cells — about one in eight, and mathematically unavoidable in this
tiling — are tinted more strongly so you can pick them out.

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
ore ends up out of reach. Richness is raised to compensate, using measured
values rather than a guess — the fraction reachable ranges from 80% at the
largest cells down to 5% at the smallest with the widest band.

`/hattorio-info` reports the cell size, band width and the richness multiplier
actually in force on your surface, and whether it was derived automatically or
taken from the override setting.

## Combinations to avoid

Cell size and band width are independent dropdowns, so a few combinations are
possible but not sensible:

| | cell | largest blueprint | reachable ore | |
|---|---|---|---|---|
| 15 / 3 | 63 tiles | 5×5 | 11% | ore very scarce |
| 15 / 4 | 46 tiles | 4×4 | 5% | close to unplayable |

A mining drill and an assembling machine are both 3×3, so a 4×4 cell leaves no
room to connect anything. The mod warns you on load if you pick one of these.
