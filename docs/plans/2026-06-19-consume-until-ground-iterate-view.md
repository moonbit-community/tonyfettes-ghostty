# `consume_until_ground`: iterate the byte view instead of indexing

Readability refactor of the parser-drain loop in `terminal/stream.mbt`. No
behavior change; every test (550 on wasm/wasm-gc/native, 572 on js) passes. No
public API change (the function is a private `fn[H]`; `moon info` regenerates no
`.mbti` delta). **Performance-neutral** — see the measurement note below.

## What

`Stream::consume_until_ground` drains bytes into the parser until it returns to
the ground state (or input runs out) and returns the number of bytes consumed.
It was a manual indexed loop:

```moonbit
let input_length = input.length()
for offset = start
    offset < input_length && !self.parser.is_ground()
    offset = offset + 1 {
  self.next_non_utf8(input[offset])
} nobreak {
  offset - start
}
```

rewritten to iterate the tail view with a consumed-counter:

```moonbit
let mut consumed = 0
for b in input[start:] {
  if self.parser.is_ground() {
    break
  }
  self.next_non_utf8(b)
  consumed = consumed + 1
}
consumed
```

## Why

Two reasons, both about the loop, neither about throughput:

1. **No per-byte bounds check.** An `input[offset]` index on a `Bytes` emits a
   bounds check on every byte — confirmed in the native (C backend) codegen, the
   indexed form expands to
   `if (offset < 0 || offset >= Moonbit_array_length(input)) moonbit_panic();`
   guarding the load, *even though* the loop condition already guarantees
   `offset < length`. Iterating the view (`for b in input[start:]`) carries its
   bound as the loop condition, so the byte load is emitted raw
   (`bytes[start + i]`, no guard, no `moonbit_panic`). The view is bounds-checked
   once at creation, not once per byte.

2. **A single return value, no off-by-`start` trap.** An earlier iterator
   rewrite (`for i, b in input[start:] { … break i } nobreak { input.length() -
   start }`) had *two* different expressions for "bytes consumed" at its two
   exits, and an `i` (view-relative) vs `i - start` (double-subtracted) mix-up
   there was a real bug. Counting only the bytes actually fed (`consumed`) gives
   one return expression that is correct whether the loop stops at ground or
   exhausts the input.

## Measurement

`moon bench -p bench/workloads --release --target native`, this change vs `main`,
median of 4 alternating-order rounds: **performance-neutral.** All workloads land
within ±~4%, the win/loss split has weak per-round consistency, signs flip
between repeated runs (e.g. `mixed_realistic` +2.1% then −1.0%), and controls
that never call `consume_until_ground` (`scroll_storm`, `cjk_text`, `wrapped_blob`)
swing as much as the escape-heavy ones — i.e. the band is recompile/code-layout
noise, not signal. This is expected: the per-byte bounds check is a
well-predicted branch, and the real cost of escape handling is in
`do_action`/dispatch, not the byte-feeding loop. The change is justified on
readability + cleaner codegen, not throughput.

## Validation

- `moon check && moon test --target all && moon fmt && moon info`
  (550/550/572/550; no `.mbti` delta).
- Native C codegen inspected to confirm the byte load is emitted without a
  per-byte bounds-check `moonbit_panic` (the indexed form is not).

### Coverage (completion gate)

`moon test --enable-coverage --target native && moon coverage analyze`. The only
touched executable file is `terminal/stream.mbt`; the doc is non-executable.

- The refactored `consume_until_ground` body is **fully covered** — it does not
  appear in the uncovered list.
- `stream.mbt` reports exactly **one** uncovered line, `:241`
  (`offset += self.consume_until_ground(input, offset)` in the `else` arm of
  `next_slice_capped`'s main loop). This is an **accepted pre-existing gap**, not
  introduced or affected by this change: line 241 is in `next_slice_capped`,
  which this refactor does not touch, and the refactor preserves
  `consume_until_ground`'s external contract (bytes consumed + parser end-state),
  so the reachability of that call site is identical before and after. The
  existing suite never drives the parser into a non-ground state at the top of
  that loop. Closing it would require a `next_slice_capped`-specific test for
  untouched control flow and is out of scope for this loop rewrite.

## Commit scope

- `refactor(stream)` (internal loop rewrite; no behavior or public API change).
