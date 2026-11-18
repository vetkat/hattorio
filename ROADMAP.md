# Roadmap

This file lists the planned work. Each item links to the place that
describes it. The maintainer decides what moves from Ideas to Next.
[CHANGELOG.md](CHANGELOG.md) lists the finished work.

## Next

- [ ] Portal images at the width of the text: the branch `docs/image-width`
  waits for review.
- [ ] The release workflow sends the long description to the mod portal.
  The API key needs the *ModPortal: Edit Mods* permission
  ([toolchain decisions][releasing]).
- [x] A prose check in CI, and a review of all the prose in the comments,
  the docs and the wiki ([toolchain decisions][prose]).
- [ ] A multiplayer test with two connected clients. The argument for
  determinism is sound, but no such test exists yet
  ([README](README.md)).

## For 2.0

- [ ] Move the root of the tiling, so that spawn is not on the centre of the
  H metatile. The mod must store the offset for each surface, and the
  change needs a major version ([design section 5][root]).

## Ideas

These are out of scope for now ([design section 15][scope]). The tiling core
and the descent-path hierarchy can take them without changes to the core.

- Claims on cells, cores and trades.
- Ore gating by cell.
- Impassable band variants, and band removal.
- A territory layer.

[releasing]: docs/design/toolchain-decisions.md#releases
[prose]: docs/design/toolchain-decisions.md#prose-check
[scope]: docs/design/hattorio-design.md#15-out-of-scope
[root]: docs/design/hattorio-design.md#root-placement
