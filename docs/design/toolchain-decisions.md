> **Status: partly superseded.** Written before the project had Factorio
> context. The runtime question is settled (Factorio embeds Lua 5.2.1, not a
> choice), and most of the floating-point section is moot now that the tiling
> core composes in doubles rather than exact integers. What survives: busted +
> luassert, luacheck, the 2^53 ceiling, and `tostring` being lossy `%.14g`.
> See `hattorio-design.md` sections 5 and 14 for the current position.

# Approach

## Verification strategy
Formal verification: **dropped**. No practical tooling exists for Lua
(mechanized semantics are research artifacts, not verifiers).

Replaced by three layers:
1. TDD (red-green-refactor) — busted + luassert
2. Static typing — Teal (`tl`), or Luau `--!strict` if on that runtime
3. Static analysis — luacheck

## Testing
- busted: test runner
- luassert: assertions, spies, stubs, mocks
- luacov: coverage (optional, add once suite has shape)
- lua-quickcheck: property-based tests for numeric kernels

## IEEE / floating-point constraints
- 5.1/5.2/LuaJIT: all numbers are doubles; exact-integer ceiling 2^53
- 5.3+: int64 and float subtypes; `math.type()` distinguishes;
  integer overflow wraps silently
- LuaJIT NaN-boxing: NaN payloads and signaling NaNs do not round-trip
- `%` is floor-mod, not C `fmod`; differs from IEEE remainder
- `tostring` is `%.14g` — lossy. Use `%a` or `%.17g` to round-trip
- `0.0 == -0.0` is true, but `1/0.0` ~= `1/-0.0`; -0.0 normalizes as table key
- NaN as table key is an error; `x ~= x` is the only NaN test
- No rounding modes, no `fma`, no FP exception flags without a C module

For FP error bounds, validate outside Lua (FPBench/FPCore + FPTaylor or
Gappa; Herbie for expression rewriting), then port and pin with tests.

## SUPER/ SPIRALS
here is super/spirals: https://cyrusradfar.com/thoughts/functional-programming-is-the-only-way-to-scale-with-ai.

```
I can't open that URL — no tools in this response. So I can't tell you what SUPER/SPIRALS actually stands for in Radfar's piece.

What I can say from the title alone: "Functional programming is the only way to scale with AI" points at a fairly recognizable cluster of ideas — pure functions, immutability, explicit data flow, small composable units, no hidden state — on the argument that these make code tractable for AI agents to reason about and modify safely. If SUPER and SPIRALS are acronyms in that piece, each letter presumably expands into one of those principles. But I'd be reconstructing them from the genre, not from the text, and a fabricated acronym is worse than no acronym — especially since you want the whole code layout built on it.

Worth noting, though: the design already in flight lines up with that family of ideas independently, which is probably why it appealed to you here. The five pure modules — hat/exact.lua, transform.lua, tiling.lua, geometry.lua, index.lua — have zero Factorio dependencies, no mutable state, and are total functions of their inputs. hats_in_box() is referentially transparent. The exact ℤ[φ][√3] ring is immutable values with algebraic laws. Side effects are quarantined in exactly two places, hat/surface.lua and the control.lua/render layer. That's roughly what a functional-core/imperative-shell argument would ask for, arrived at from the determinism constraint rather than from the principle.

So the useful question when the main thread picks this up is narrower than "apply SUPER/SPIRALS": it's whether those principles demand anything the current structure doesn't already have. Candidates that come to mind — an explicit no-mutation rule enforced by the linter, persistent rather than in-place data structures in the descent accumulator, or pushing the storage reads in surface.lua up into the shell so even that module is pure.

Paste the two acronyms' expansions and that comparison becomes concrete rather than speculative.
```

## Questions brainstorming needs to settle
These are the ones where a wrong assumption costs real rework:

- Target runtime — this is the first fork. Lua 5.4, 5.3, 5.1, or LuaJIT? It determines whether you have an integer subtype at all, and whether NaN-boxing is a constraint.
- Teal or Luau — Teal is runtime-agnostic and more mature as a standalone; Luau only makes sense if you're already on that runtime. If Teal: is the build step (.tl → .lua) acceptable, and do tests run against .tl sources or generated .lua?
- Where the IEEE-sensitive code lives — is there a numeric core that should be isolated from the rest, so property tests and tolerance decisions concentrate in one module?
- Comparison policy — exact bit equality, ULP distance, or relative epsilon? This wants to be a single shared test helper, decided once, not re-improvised per test.
- Distribution — luarocks package, vendored, or embedded in a host application? Affects layout more than anything else on this list.
- Directory shape — src/ + spec/ is the busted default (busted auto-discovers spec/**/*_spec.lua). Worth confirming before files start landing.
- When the main thread picks this up, the sequence is: brainstorming first to resolve the above, then /tdd once the first test is ready to be written.

