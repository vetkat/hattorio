# Hattorio

**Every planet is divided into cells of the aperiodic "hat" monotile tiling.
No two cells are the same shape. Your blueprint library stops working.**

![The hat tiling](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/tiling.png)

In 2023 four mathematicians found the first shape that tiles the plane and
*never repeats* — the hat. Hattorio builds your factory on it.

Each hat is a buildable **cell**. Between cells runs a narrow **band** you
cannot build on. You can walk and drive across a band freely, underground
belts and pipes tunnel beneath it, rails cross it, and power and bots ignore
it entirely — but nothing gets built there.

That one rule is the whole mod.

![How it looks in game](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-41-3.png)

## Why your blueprints stop fitting

Not because of rotation. Because **every cell is a genuinely different
shape**.

Hat cells sit at irrational offsets from Factorio's square tile grid, so each
one rounds onto the squares differently. Measured across 1,156 cells at the
default settings: **885 distinct buildable shapes**, with no single shape
covering more than **0.5%** of the map.

A layout that fills one cell will not fit the next one along. You cannot
stamp your way out of this.

**Small blueprints still travel.** Anything up to 17×17 at the default
settings fits every cell, so an assembler cluster or a splitter bank is fine.
What dies is anything that wants to *use* a cell efficiently — fill the space
and you have fitted it to that cell and nowhere else.

The result is a factory that has to be built for the ground it sits on.

## What you actually do differently

- **Think in cells, not in a bus.** A main bus assumes you can run parallel
  lines indefinitely. You cannot. Each cell becomes a small factory with a job.
- **Every crossing is a decision.** Belts leave a cell by underground pair,
  against an edge that is never axis-aligned.
- **Trains matter more.** Rails cross bands freely, so at distance they are
  far less painful than belts.
- **Bots soften everything.** They fly over the whole problem, and they arrive
  with normal progression. That is intended.

## Settings

Cell size and band width are set **per planet**, at world creation.

| Cell size | Cell area | Largest blueprint that fits every cell |
|---|---|---|
| 15 — very hard | 63 tiles | 5×5 |
| 26 — hard | 294 tiles | 10×10 |
| **41 — normal (default)** | **858 tiles** | **17×17** |
| 52 — easy | 1,473 tiles | 22×22 |

For scale: a smelter block is around 20×20 and a mall around 30×30, so
**every option defeats real imported blueprints**. The size only decides how
much room you get to improvise in.

Band width runs 1 to 4 tiles. All widths can be spanned by underground belts,
so cells never become isolated.

Bands are animated dark liquid by default, in one of five colourways, or a
flat void if you prefer stillness. About one cell in eight is a mirror image
— mathematically unavoidable in this tiling — and is tinted so you can pick
it out.

Ore that bands put out of reach of a 3×3 mining drill is compensated for
automatically, scaled to your settings. `/hattorio-info` reports the geometry
and richness in force on your surface.

## Before you start

- **Start a new world.** Bands are painted as chunks generate, so an existing
  save keeps vanilla ground wherever you have already explored, leaving a
  permanent boundary. The mod warns you if you add it to a world in progress.
- **Single player for now.** The multiplayer determinism argument is sound —
  the tiling uses only correctly-rounded IEEE arithmetic, no trigonometry —
  but it has not been verified with two clients. Please do not rely on it in
  multiplayer yet.
- Factorio 2.0 or later. Space Age is supported but not required.

## Credits

The hat monotile was discovered by David Smith, Joseph Samuel Myers, Craig S.
Kaplan and Chaim Goodman-Strauss in 2023. The substitution structure here is
derived from Kaplan's [hatviz](https://github.com/isohedral/hatviz).

[Hextorio](https://mods.factorio.com/mod/hextorio) did this for hexagons
first and solved several of the same problems.

MIT licensed. Source, and a write-up of how the tiling is generated, at
[github.com/vetkat/hattorio](https://github.com/vetkat/hattorio).
