# `SepList`: heap-boxed mutable struct → unboxed `UInt64` newtype

Post-translation performance work on the parser's CSI separator bitset. No
behavior change; every test (550, on all four backends) passes. This is a
fidelity-improving deviation: it makes `SepList` an inline value bitset the way
upstream Ghostty's `std.StaticBitSet` is, instead of a mutable heap object.

## Goal

Stop heap-allocating a one-word box on every CSI dispatch. `SepList` wrapped a
single `UInt64`, but as a plain `struct` it was a heap object, and
`SepList::init_empty()` runs on **every** CSI sequence reset
(`parser.mbt`: `self.params_sep = SepList::init_empty()`), not just colon-
separated ones — so every SGR, cursor move, and query allocated and dropped a
box whose only contents were a `UInt64`.

The bitset was:

```moonbit
struct SepList {
  mut bits : UInt64
} derive(Debug)

pub fn SepList::set(self : SepList, index : Int) -> Unit {
  self.bits = self.bits | (1UL << index)   // in-place mutation
}
```

## Upstream reference

- `upstream/ghostty/src/terminal/Parser.zig:90` —
  `pub const SepList = std.StaticBitSet(MAX_PARAMS);`. With `MAX_PARAMS ≤ 64`,
  `StaticBitSet` is an `IntegerBitSet`: a single inline integer value, no heap.
  Zig mutates the parser's own copy in place (`self.params_sep.set(idx)`,
  `Parser.zig:342`) and **copies the value** into the CSI payload
  (`.params_sep = self.params_sep`, `Parser.zig:381`). `.initEmpty()` allocates
  nothing.

Our mutable-`struct` translation added a heap box and a reference where Zig had
a value. Making it an unboxed newtype restores the value semantics exactly.

## Change (`terminal/parser/parser.mbt`)

- `SepList` becomes a newtype: `struct SepList(UInt64) derive(Debug)`. A MoonBit
  newtype is unboxed — represented as the bare `UInt64`, no heap object and no
  refcount, matching Zig's `IntegerBitSet`.
- `set` returns a new bitset instead of mutating in place:
  ```moonbit
  pub fn SepList::set(self : SepList, index : Int) -> SepList {
    self.0 | (1UL << index)
  }
  ```
  `init_empty` is now `0UL`; `is_set`/`count` read `self.0`. No allocation
  anywhere.
- The two holders keep their `mut params_sep` field and **rebind** it
  (`self.params_sep = self.params_sep.set(...)`) instead of mutating a shared
  box — `Parser::consume_param` (`parser.mbt`) and `SgrParser::from_params`
  (`sgr.mbt`). This is the same value-rebind Zig's mutable struct field does.

The `Csi` payload already copied the value (`params_sep: self.params_sep`); with
the newtype that copy is a plain `UInt64` move, and the per-sequence reset
(`init_empty`) no longer touches the heap.

## Why the `.mbti` changes

`SepList::set`'s return type goes `Unit → Self`. `SepList` itself stays an
abstract type (`type SepList derive(@debug.Debug)`) — the newtype representation
is internal, so the only public delta is the one method signature. `moon info`
regenerates exactly that one line in `terminal/parser/pkg.generated.mbti`;
`terminal/sgr` uses `SepList` opaquely and has no delta.

## Acceptance criteria

- No heap allocation on a CSI dispatch's separator bitset. Met — `SepList` is an
  unboxed newtype; `init_empty` is a literal `0UL`.
- Terminal state identical; minimal public API change. Met — 550 tests pass on
  wasm/wasm-gc/js/native; the only `.mbti` delta is `SepList::set`'s return type.
- No workload regresses. Met (see results) — every workload is neutral-to-faster.

## Validation commands

- `moon check && moon test --target all && moon fmt && moon info`
- `moon bench -p bench/workloads --release --target native`

## Audit/result notes

- `moon bench` (native release), main (post-`#34`) baseline → after, median of 4
  alternating-order rounds (the order is flipped each round to cancel thermal
  drift):
  - **CSI-dispatch-heavy** (each dispatch previously boxed a `SepList`):
    `sgr_storm` 9.02 ms → 7.30 ms (−19.1%); `tui_redraw` 1.46 ms → 1.30 ms
    (−11.0%); `query_storm` 8.53 ms → 7.98 ms (−6.4%); `mixed_realistic` 847 µs →
    810 µs (−4.4%); `colored_log` 458 µs → 439 µs (−4.1%); `color_storm`
    21.79 ms → 21.26 ms (−2.4%).
  - **Controls**: `osc_titles` 507 µs → 504 µs (−0.5%) — OSC never touches the
    CSI param path, so ~0% is the clean negative control confirming the win comes
    from the CSI `SepList` allocation. Pure-text `plain_lines` (−1.7%),
    `wrapped_blob` (−1.5%), `cjk_text` (−1.1%) dispatch no CSI and sit in the
    measurement-noise floor.
- `sgr_storm` paired across all four rounds: 8.97→7.30, 8.89→7.27, 9.13→7.28,
  9.02→7.35 ms — the win is rock-solid, not noise.
- Bigger than the preceding grid change despite a smaller diff: `init_empty`
  runs on every CSI sequence, and CSI dispatch (SGR, cursor moves, queries) is
  one of the hottest paths in a terminal.

## Commit scope

- `perf(parser)` (internal storage refactor; one-line `.mbti` change to
  `SepList::set`).
