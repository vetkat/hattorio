# The mathematics

This page is background for readers who are curious. You do not need it to
play.

To draw the hat tiling is easy. Craig Kaplan's
[hatviz](https://github.com/isohedral/hatviz) does it in a browser. A Factorio
mod must generate the tiling *lazily, deterministically and in Lua 5.2*. That
is the interesting problem.

## Why lazy

Factorio maps have no practical limit, and the game generates them one chunk
at a time. Six levels of substitution already give about 400,000 hats, and
level 7 is far too large. So the mod cannot build the tiling in advance.

The mod keeps only one root supertile. For each chunk, it goes down from that
root and skips each branch whose bounding circle misses the chunk. The cost
grows with the output, not with the size of the tiling. At full depth, this
takes about 0.7 ms per chunk.

## Why deterministic

Factorio runs in deterministic lockstep. The server orders the inputs, and
every client simulates the whole world on its own. So any difference between
clients is a desync and not a visual glitch. Every machine must calculate
exactly the same tiling.

The usual answer is to avoid floating point. That lesson was wrong here, and
it sent this project on a long detour. The detour is worth a description.

## The detour: exact arithmetic

The vertices of the hat are exact integer points in the triangular lattice
basis `{(1,0), (½, √3/2)}`, and the substitution scales by φ². So every
coordinate is in ℚ(φ, √3), which has degree 4 over ℚ. You can store each
coordinate as four exact integers. The identities `φ² = φ+1` and `√3² = 3`
keep multiplication inside that form.

This works very well offline. In Lua it fails.

Lua 5.2 has no integer subtype. In any standard build, its only number type is
a double, so integers are exact only up to 2⁵³. Lua 5.3 added a real 64-bit
integer. For this reason the tests of this project pin Lua 5.2: on 5.4, the
tests would hide the all-doubles behaviour that the core depends on. The rules
for each level of the substitution are exact rationals that *converge on
irrational limits*. Their numerators grow very quickly:

```text
level 6:  numerators 1.4e14   fine
level 7:  numerators 1.7e16   past 2^53
```

It gets worse. When you compose two level-6 rules, the raw product is near
10²⁸, but the reduced answer is only about 10⁹. To reduce after the
product is too late. To cross-reduce before the product does not help either.
The measured gcd between the operands is 1, because the cancellation is
*additive* (inside the sums) and not multiplicative.

With exact integers, the descent stops at depth 4, which covers about 546
tiles. That is not enough to ship.

## The answer: doubles were always fine

Floating point in general was never the desync risk. The risk is `math.sin`,
`math.cos` and `pow`, because their libm implementations really are different
on different platforms.

IEEE-754 requires correct rounding for `+ − × ÷` and `sqrt`, so they give
the same bits everywhere. The Lua interpreter runs each operation as a
separate VM instruction, so no compiler can fuse two of them into an FMA.
Factorio runs on 64-bit x86 and ARM processors, which do double arithmetic
without the 80-bit excess precision of x87.

Here, doubles are exactly as deterministic as integers. They are only less
accurate. Measured against exact values, the error is too small to matter:

| depth | coverage | relative error | absolute error |
| --- | --- | --- | --- |
| 8 | 26,660 t | 5.7e-16 | 8e-12 tiles |
| 10 | 183,419 t | 4.3e-16 | 7e-11 tiles |
| 12 | 1,194,588 t | 5.3e-16 | 4e-10 tiles |

The relative error stays at machine epsilon and does not grow with depth.
Depth 12 covers the whole map with an error of four ten-billionths of a tile.

The exact arithmetic is still in the project, but only offline. There it
derives the rule data and proves that the data is correct. Only the values
ship.

## Exact values for the limit metatiles

hatviz does not store the substitution as matrices. It holds a combinatorial
table with 29 entries. To calculate the transforms, it matches edges against
the *current* metatile outlines. Then it derives the outlines for the next
level from the geometry. So the outlines change from level to level, and they
converge on limiting shapes with φ proportions.

You can recover those limits. The offline pipeline normalised a level-22 patch
and ran integer-relation recognition on it. The result gives all
36 coordinates as exact elements of ℚ(φ)\[√3\], with denominators that
divide 100. Two independent checks confirm this, at level 14 (10⁻⁸) and level
22 (10⁻¹⁴).

These limits are an exact fixed point. If you substitute them, you get the
same shapes scaled by φ². They are equal as ring elements, not only close. The
self-similar rule set that results has a maximum coefficient of 219. The
rules for each level have a maximum of 4.8×10²⁶.

But this does not solve the depth problem, because a self-similar rule set
cannot reach the hats. A substitution maps the 4 hats on a decorated tile to
25 smaller hats, so the decoration does not stay the same under scaling. Hats
exist only at level 0, where they attach to the original shapes. If you attach
them to a self-similar descent, the counts are correct and the hats are
congruent, but real overlaps and gaps appear.

The project did not need the result after doubles solved the problem. The
design spec records both.

## How the pipeline checks it

The offline pipeline checks every patch:

- no hats overlap
- a flood fill finds no gaps
- the density of reflected hats converges to 1/(φ⁴+1) ≈ 12.73%
- the hat counts match F(2n+3)² exactly: 4, 25, 169, 1,156, 7,921

The pipeline then exports a golden fixture, and the Lua descent must produce
the same result.

The last check is the most important one. It tests the code that ships
against arithmetic with a proof of correctness.

## Further reading

- [An aperiodic monotile](https://arxiv.org/abs/2303.10798): the original
  paper
- [hatviz](https://github.com/isohedral/hatviz): Kaplan's reference
  implementation
- [The design spec](https://github.com/vetkat/hattorio/blob/main/docs/design/hattorio-design.md):
  includes a long section on everything that turned out to be wrong
