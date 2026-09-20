# Toolchain

What the project actually uses, and why. Anything proposed but not adopted
has been removed; the reasoning behind the arithmetic choices lives in
`hattorio-design.md` sections 5 and 14.

## Runtime: Lua 5.2.1

Not a choice. Factorio embeds Lua 5.2.1 and the mod runs inside it.

Two consequences that shape the code:

- **No integer subtype.** Every number is a double, exact only to 2^53. The
  tiling core stores values rather than exact integers precisely because of
  this; see design section 5.
- **`tostring` is `%.14g`, and lossy.** This is why hat identity is a packed
  descent path (`hat/index.lua`) and never a formatted coordinate. The
  original scaffold keyed identity off `string.format("%.3f", ...)`, which
  can collide two hats or give one hat two ids.

Where floats are emitted for Lua to read, `%.17g` is used, which round-trips
a double exactly. A test asserts every emitted value survives the round trip.

## Testing: busted + luassert

Red-green-refactor throughout. `spec/*_spec.lua`, auto-discovered via
`.busted`.

Tests must run under **Lua 5.2 specifically**. Running them on 5.4 would
silently mask the all-doubles behaviour the core depends on, since 5.3+ adds
an integer subtype. CI pins 5.2 for the same reason.

On Arch, `lua52-busted` installs the rock off PATH with a shebang pointing at
Lua 5.5, where its modules do not exist. The Makefile prefers a `busted` on
PATH and falls back to the rock path.

**Property-style tests are plain loops over fixed seeds**, not a generative
library. `lua-quickcheck` was considered and dropped: no luarocks package on
Arch ships a CLI, so it cannot be installed without building from source, and
fixed seeds are more reproducible anyway.

## Static analysis: luacheck

Run by `make lint` and in CI, over `hat/` and `spec/`. Zero warnings is the
standard.

**No static type checker is used.** Teal was considered and rejected: it has
no Factorio API definitions, so every game call would become an untyped escape
hatch, and it adds a `.tl` to `.lua` build step. LuaLS annotations were chosen
in the design phase but never actually applied — there are none in the
codebase today. If typing is wanted, that is the route, and it should be
adopted deliberately rather than assumed.

## Layout

```
hat/     tiling core, no Factorio dependencies, loads under plain lua5.2
tools/   offline pipeline (Python 3, stdlib only) and dev renderers
data/    generated Lua data; regenerate with `make data`, never hand-edit
spec/    busted tests, plus fixtures exported from the pipeline
wiki/    source for the GitHub wiki; publish with `make wiki`
```

The split that matters: `hat/` has no Factorio dependencies, so it runs in CI
under plain Lua, and `tools/` never ships. Exactness lives offline where it is
free; only values ship.

## Verification strategy

Formal verification was considered and dropped — no practical tooling exists
for Lua; mechanised semantics are research artifacts, not verifiers.

What replaces it is three layers that do run:

1. **Offline proofs** (`tools/verify.py`) — the generated tiling is checked
   for overlapping hats, gaps by flood-fill, reflected-hat density converging
   to 1/(phi^4+1), and hat counts matching F(2n+3)^2 exactly.
2. **Golden fixtures** — the pipeline exports a reference patch that the Lua
   descent must reproduce. This validates the code that ships against the
   arithmetic that was proved correct.
3. **Invariant tests** — `spec/invariants_spec.lua` greps the shipped modules
   for `math.sin`, `math.cos`, `math.random` and `^`, none of which are
   bit-identical across platforms.

## Functional core

The `hat/` modules are pure: no mutable state, no Factorio API, total
functions of their inputs. Side effects belong in the Factorio-facing layer.

This was arrived at from the determinism constraint rather than from a
principle, but it lines up with SUPER (side effects at the edge, uncoupled
logic, pure and total functions, explicit data flow, replaceable by value).
Design section 7 states the three rules that make it explicit.

The one deliberate exception is the descent's output accumulator, mutated in
place for speed. It is local to `hat/tiling.lua` and never escapes.
