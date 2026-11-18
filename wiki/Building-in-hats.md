# Building in hats

These are practical notes for your first base. The mod does not enforce any
of them. The shape of the ground pushes you this way.

## Look before you build

Cells are all different. Before you choose a spawn area, open the map and find
a group of cells that fit well together. Some neighbours share long edges.
Others meet at awkward points. A good starting group is worth the walk.

## Think in cells, not in a bus

A main bus needs parallel lines that run as far as you want. Here they cannot.
Treat each cell as a small factory with one job, and move items between the
cells.

Then the hard part is the *connections*. The mod puts the interesting
decisions there.

## Crossing bands

- **Underground belts and pipes** go under bands. This is the intended route,
  and you will build it the most.
- **Rails** are exempt and cross bands freely. Trains work normally. Over long
  distances, rails are much easier than belts.
- **Power poles** ignore the ground. Power is never the problem.
- **Bots** fly over everything. When you have logistics bots, the constraint
  becomes much weaker. This is intended, and bots arrive with normal
  progression.

## What to blueprint

Blueprint the things that fit inside the largest square your settings allow
(17×17 at the default). Those blueprints work everywhere:

- an assembler with its inserters and a short belt
- a splitter or balancer block
- a small power or radar block

Do not blueprint a whole cell. The blueprint will fit exactly one cell, and
884 other shapes remain.

## Common mistakes

- **Mining drills need a clear 3×3 area.** You cannot mine ore under a band.
  Check this before you plan a patch.
- **You can walk on bands.** They look like a wall, but they are not one. You
  can always reach a cell.
- **Reflected cells.** About 1 cell in 8 is a mirror image. No rotation makes
  it match the others. This is a mathematical property of the tiling, not a
  bug: a proof shows that the tiling needs mirrored tiles.
