# Hattorio

**Factorio, but the ground is an aperiodic tiling.**

Your factory is built on the "hat" monotile — the shape discovered in 2023
that tiles the plane and never repeats. Every cell is a hat. No two are quite
alike. Your blueprints will not save you.

![The tiling](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/tiling.png)

> **Playable, but not released.** Everything works and has been tested in a
> real game. It is not on the mod portal yet, and multiplayer has not been
> verified — play single player for now. Watch
> [the repo](https://github.com/vetkat/hattorio) for the release.

## How it plays

Each hat is a buildable **cell**. Between cells runs a narrow **band** you
cannot build on. You can walk and drive across it freely, and underground
belts and pipes tunnel underneath — but nothing gets built there.

That one rule is the whole mod, and it changes everything downstream.

### Your blueprint library stops working

Not because of rotation. Because **every cell is a different shape**.

Hat cells sit at irrational offsets from Factorio's tile grid, so each one
rounds onto the squares differently. Measured across 1,156 cells at default
settings: **624 distinct buildable shapes**, with no single shape covering
more than 1.1% of the map.

A layout that fills one cell will not fit the next one along.

### Small blueprints still travel

This is not a mod about deleting blueprints. Anything that fits in an 11×11
square works in every cell at the default size — an assembler and its
inserters, a splitter bank, a small power block.

What dies is anything that wants to *use* a cell efficiently. Fill the space
and you have fitted it to that cell and nowhere else.

### Getting between cells is the interesting part

Belts cross a band by underground pair. Bands are never axis-aligned, so the
crossing is never tidy. Rails are exempt and cross freely — trains still
work. Power poles and bots ignore the ground entirely.

The factories that come out of this are not ugly by accident. They are fitted.

![In-game appearance](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-26-2.png)

## Where to go next

- **[Settings](Settings)** — hat size is the dial that matters. Start here.
- **[Building in hats](Building-in-hats)** — practical advice for your first base.
- **[The mathematics](The-mathematics)** — how the tiling is generated, for
  the curious. Not needed to play.

## Credits

The hat monotile was discovered by David Smith, Joseph Samuel Myers, Craig S.
Kaplan and Chaim Goodman-Strauss in 2023. The substitution structure is
derived from Kaplan's [hatviz](https://github.com/isohedral/hatviz).
[Hextorio](https://github.com/sOvr9000/hextorio) did this for hexagons first
and solved several of the same problems.
