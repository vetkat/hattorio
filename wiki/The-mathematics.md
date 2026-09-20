# The mathematics

Background for the curious. You do not need any of this to play.

The interesting problem is not drawing the hat tiling — Craig Kaplan's
[hatviz](https://github.com/isohedral/hatviz) does that in a browser. It is
generating it *lazily, deterministically, and in Lua 5.2*, which is what a
Factorio mod actually needs.

## Why lazy

Factorio maps are effectively unbounded and generate a chunk at a time. Six
levels of substitution is already ~400,000 hats and level 7 is hopeless, so
nothing can be materialised up front.

Instead the mod keeps only a root supertile and descends it per chunk,
pruning any branch whose bounding circle misses the chunk. Cost is
proportional to the output rather than to the tiling. About 0.7 ms per chunk
at full depth.

## Why deterministic

Factorio has no server authority: every client simulates the world
independently, and any divergence is a desync rather than a visual glitch.
So the tiling must be computed identically on every machine.

The usual answer is to avoid floating point. That turns out to be the wrong
lesson, and it cost this project a detour worth describing.

## The detour: exact arithmetic

The hat's vertices are exact integer points in the triangular lattice basis
`{(1,0), (½, √3/2)}`, and the substitution scales by φ². So every coordinate
lives in **ℚ(φ, √3)** — degree 4 over ℚ — and can be carried as four exact
integers with `φ² = φ+1` and `√3² = 3` closing multiplication.

That works beautifully offline. In Lua it collapses.

Lua 5.2 has no integer type; every number is a double, exact only to 2⁵³. The
substitution's per-level rules are exact rationals *converging on irrational
limits*, so their numerators explode:

```
level 6:  numerators 1.4e14   fine
level 7:  numerators 1.7e16   past 2^53
```

Worse, composing two level-6 rules produces a raw product near **10²⁸**, even
though the reduced answer is only ~10⁹. Reducing afterwards is too late.
Cross-reducing beforehand does not help either — the measured gcd between
operands is 1, because the cancellation is *additive*, inside the sums,
rather than multiplicative.

Exact integers cap the descent at **depth 4**, about 546 tiles. Unshippable.

## The resolution: doubles were always fine

The desync risk was never floating point in general. It is `math.sin`,
`math.cos` and `pow`, whose libm implementations genuinely differ between
platforms.

IEEE-754 requires `+ − × ÷` and `sqrt` to be **correctly rounded** — they are
bit-identical everywhere. Lua's interpreter runs each as its own VM
instruction, so no compiler can fuse them into an FMA. Factorio 2.0 is x86-64
only, so there is no x87 80-bit excess precision either.

Doubles are exactly as deterministic as integers here. Only less accurate —
and measured against exact ground truth, that inaccuracy is irrelevant:

| depth | coverage | relative error | absolute error |
|---|---|---|---|
| 8 | 26,660 t | 5.7e-16 | 8e-12 tiles |
| 10 | 183,419 t | 4.3e-16 | 7e-11 tiles |
| 12 | 1,194,588 t | 5.3e-16 | **4e-10 tiles** |

Relative error sits at machine epsilon and does not grow with depth. Depth 12
covers the entire map with an error of four ten-billionths of a tile.

The exact arithmetic still exists — it just stays offline, where it derives
the rule data and proves it correct. Only the values ship.

## Exactifying the limit metatiles

A side quest that produced a genuinely pretty result.

hatviz does not store the substitution as matrices. It holds a 29-entry
combinatorial table and computes transforms by edge-matching against the
*current* metatile outlines, then derives the next level's outlines
geometrically. So the outlines change level to level, converging on limiting
φ-proportioned shapes.

Those limits can be recovered. Normalising a level-22 patch and running
integer-relation recognition gives all 36 coordinates as exact elements of
ℚ(φ)[√3] with denominators dividing 100 — cross-checked independently at
level 14 (10⁻⁸) and level 22 (10⁻¹⁴).

And they are an **exact fixed point**: substituting them reproduces them
scaled by φ², equal as ring elements, not merely close. The resulting
self-similar rule set has maximum coefficient **219**, against 4.8×10²⁶ for
the per-level rules.

It does not, however, solve the depth problem — because a self-similar rule
set cannot reach the hats. Substituting a decorated tile maps 4 hats to 25
smaller ones, so the decoration is not scale-invariant: hats exist only at
level 0, anchored to the original shapes. Attaching them to a self-similar
descent gives correct counts and congruent hats but real overlaps and gaps.

A satisfying result that turned out to be unnecessary once doubles solved the
problem outright. Both are recorded in the design spec.

## How it is checked

The offline pipeline verifies every patch for overlapping hats, gaps by
flood-fill, reflected-hat density converging to 1/(φ⁴+1) ≈ 12.73%, and hat
counts matching **F(2n+3)²** exactly — 4, 25, 169, 1,156, 7,921. It then
exports a golden fixture that the Lua descent must reproduce.

That last check is the important one: it validates the code that ships
against the arithmetic that was proved correct.

## Further reading

- [An aperiodic monotile](https://arxiv.org/abs/2303.10798) — the original paper
- [hatviz](https://github.com/isohedral/hatviz) — Kaplan's reference implementation
- [The design spec](https://github.com/vetkat/hattorio/blob/main/docs/design/hattorio-design.md)
  — including a long section on everything that turned out to be wrong
