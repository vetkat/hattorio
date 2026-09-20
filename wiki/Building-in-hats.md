# Building in hats

Practical notes for your first base. None of this is enforced by the mod —
it is just what the shape of the ground pushes you toward.

## Start by looking, not building

Cells differ. Before committing to a spawn area, open the map and find a
cluster of cells that sit well together — some neighbours share long edges,
others meet at awkward points. A good starting cluster is worth walking for.

## Think in cells, not in a bus

A main bus assumes you can run parallel lines indefinitely. You cannot. What
works instead is treating each cell as a small factory with a job, and moving
items between them.

That makes the awkward part the *connections*, which is where the mod puts
the interesting decisions.

## Crossing bands

- **Underground belts and pipes** tunnel under bands. This is the intended
  route and the main thing you will build.
- **Rails** are exempt and cross freely. Trains work normally — for anything
  at distance, rails are far less painful than belts.
- **Power poles** ignore the ground entirely. Power is never the problem.
- **Bots** fly over everything. Once you have logistics bots, a lot of the
  constraint softens — this is intended, and it arrives with normal progression.

## What to blueprint

Blueprint the things that fit inside the largest square your settings allow
(11×11 at the default). Those work everywhere:

- an assembler with its inserters and a short belt
- a splitter or balancer block
- a small power or radar block

Do not try to blueprint a whole cell. It will fit exactly one cell, and you
have 624 shapes to go.

## Things that catch people out

- **Mining drills need a clear 3×3.** Ore under a band is not minable. Check
  before you plan a patch.
- **Bands are walkable.** They look like a wall and are not one. You can
  always get there.
- **Reflected cells.** About 1 in 8 cells is a mirror image, and no amount of
  rotation makes it match the others. This is a mathematical property of the
  tiling, not a bug — mirrored tiles are provably unavoidable.
