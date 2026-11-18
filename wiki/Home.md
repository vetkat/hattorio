# Hattorio

Factorio on an aperiodic tiling.

You build your factory on the "hat" monotile. Four mathematicians found this
shape in 2023. It tiles the plane, and the pattern never repeats. Each cell
is a hat, and no two cells have quite the same shape.

![The tiling](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/tiling.png)

Release 1.0.2 is on [the mod portal](https://mods.factorio.com/mod/hattorio).

> **Warning:** multiplayer is not verified. Play single player for now.

## How it plays

Each hat is a buildable cell. A narrow band runs between the cells, and you
cannot build on it. You can walk and drive across a band, and underground
belts and pipes go under it.

### Your blueprint library stops fitting

Each cell has a different shape. The hat cells sit at irrational offsets from
Factorio's tile grid, so each cell rounds onto the squares in a different
way. At the default settings, 1,156 measured cells have 885 different
buildable shapes. No single shape covers more than 0.5% of the map, so a
layout that fills one cell does not fit the next one.

### Small blueprints still fit everywhere

At the default size, anything that fits in a 17×17 square works in every
cell. Examples are an assembler and its inserters, a bank of splitters or a
small power block. A blueprint that fills a cell fits that cell and no other.

### The connections between cells are the puzzle

Belts cross a band with an underground pair. Bands are never parallel to an
axis, so a crossing is never tidy. Rails cross bands freely, so trains work
as usual. Power poles and bots ignore the ground.

![In-game appearance](https://raw.githubusercontent.com/vetkat/hattorio/main/docs/preview/bands-26-2.png)

## Where to go next

- [Settings](Settings): the cell size sets how much room you get. Start
  here.
- [Building in hats](Building-in-hats): advice for your first base.
- [The mathematics](The-mathematics): how the mod generates the tiling. You
  do not need it to play.

## Credits

David Smith, Joseph Samuel Myers, Craig S. Kaplan and Chaim Goodman-Strauss
discovered the hat monotile in 2023. The substitution structure comes from
Kaplan's [hatviz](https://github.com/isohedral/hatviz).
[Hextorio](https://github.com/sOvr9000/hextorio) did this for hexagons first
and solved several of the same problems.
