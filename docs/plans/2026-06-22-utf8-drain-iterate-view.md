# Align `next_slice_capped`'s loops with upstream

Follow-on to #37 (`refactor(stream): iterate the byte view in
consume_until_ground`). Two related cleanups to `Stream::next_slice_capped`,
both bringing it closer to upstream `stream.zig`'s `nextSliceCapped`:

1. The leading UTF-8 continuation-byte drain iterates the byte view instead of
   indexing `input[offset]` (same change #37 made to `consume_until_ground`).
2. The ground-state print loop drops an **unreachable** non-ground `else` branch
   and adopts upstream's `while (parser.state == .ground and offset < len)` loop
   condition.

No behavior change; every test passes (550 wasm/wasm-gc/native, 572 js). No public
API change (private `fn[H]`; `moon info` regenerates no `.mbti` delta). After
change 2, `terminal/stream.mbt` has **zero uncovered lines** — it removes the lone
accepted-gap line carried since #37.

## Change 1 — UTF-8 drain iterates the view

`next_slice_capped` opens by draining any in-flight UTF-8 continuation bytes until
the decoder reaches its accept state (or input runs out). It was a manual indexed
loop:

```moonbit
let mut offset = 0
while !self.utf8decoder.is_accept_state() {
  if offset >= input.length() {
    return
  }
  self.next_utf8(input[offset])
  offset += 1
}
if offset >= input.length() {
  return
}
```

rewritten to iterate `input` from the start with a consumed-counter:

```moonbit
let mut offset = 0
for b in input {
  if self.utf8decoder.is_accept_state() {
    break
  }
  self.next_utf8(b)
  offset += 1
}
if offset >= input.length() {
  return
}
```

### Why

Same rationale as #37, and this loop is the *one part* of `next_slice_capped`
that admits the rewrite:

1. **No per-byte bounds check.** `input[offset]` on a `Bytes` emits a bounds check
   on every byte (`if (offset < 0 || offset >= Moonbit_array_length(input))
   moonbit_panic();`), even though the loop already guarantees the index is in
   range. Iterating the view carries its bound as the loop condition, so the byte
   load is emitted raw. Confirmed in the native (C backend) codegen during #37.
2. **It is separable; the main loop is not.** This loop starts at `offset 0`,
   advances by 1, and the `offset` it produces is exactly "bytes consumed" — the
   same clean linear-drain shape as `consume_until_ground`.

### Why dropping the in-loop early return is safe

The old loop returned from the whole function when it exhausted the input before
reaching accept state. The `for .. in` version has no in-loop bounds test: when
the iterator runs out, `offset == input.length()`, and the **existing**
`if offset >= input.length() { return }` guard immediately below catches exactly
that case. The three exits were checked equivalent to the original (accept +
remaining, accept-at-end, exhausted-not-accept). The only structural difference is
the order of the accept check vs the bounds check between iterations; it is
immaterial because the post-loop guard covers the exhaustion case precisely.

## Change 2 — drop the unreachable non-ground branch in the main loop

After the drain + `consume_until_ground` + `consume_all_escapes` prelude, the
function ran a main loop that was:

```moonbit
while offset < input.length() {
  if self.parser.is_ground() {
    self.next_utf8(input[offset])
    offset += 1
  } else {
    offset += self.consume_until_ground(input, offset)   // unreachable
  }
  if offset < input.length() && self.parser.is_ground() {
    offset += self.consume_all_escapes(input, offset)
  }
}
```

rewritten to upstream's shape:

```moonbit
while self.parser.is_ground() && offset < input.length() {
  self.next_utf8(input[offset])
  offset += 1
  if offset < input.length() && self.parser.is_ground() {
    offset += self.consume_all_escapes(input, offset)
  }
}
```

### Why the `else` branch was dead code

Upstream's main loop (`stream.zig:522`) is
`while (self.parser.state == .ground and offset < input.len)` — it simply **exits**
when the parser is non-ground; there is no non-ground branch. The MoonBit port had
restructured this into `while offset < len { if ground … else … }`, manufacturing
a non-ground arm that cannot execute. Proof that the parser is always ground at the
loop top while bytes remain (so the `else` never fires):

- **The loop-top byte is never `0x1B`.** It is reached either right after the
  prelude's `consume_all_escapes` (`:242`) or after the in-loop one (`:253`), and
  `consume_all_escapes` only stops on a non-`0x1B` byte or on exhaustion.
- **`next_utf8` can leave the parser non-ground only by printing `0x1B`**
  (`handle_codepoint` → `enter_escape`). 8-bit C1 controls (`0x80–0x9F`) go through
  `execute` → `esc_dispatch` as single-shot dispatches and stay ground.

Since the loop-top byte is never `0x1B`, the print branch never feeds `0x1B`, the
parser stays ground after every print, the `consume_all_escapes` guard always runs
and re-establishes the non-`0x1B`/ground invariant — an airtight induction whose
base case is the prelude `consume_all_escapes`. Breaking the invariant would
require the print branch to feed a `0x1B` that the invariant already forbids. The
full 550-test suite passing unchanged corroborates the equivalence.

The new `while is_ground() && offset < length` condition is behavior-identical
(the old loop only ever exited on `offset >= length`, since non-ground-with-bytes
never occurs) and faithful to upstream.

## Measurement

Neither change separately benched. Both are the same micro-shapes covered by #37,
which measured **performance-neutral** (the per-byte bounds check is a
well-predicted branch; real cost is in `do_action`/dispatch). The drain loop is a
cold, short path (only the bytes of a multi-byte UTF-8 sequence straddling a slice
boundary); the dead-branch removal is pure code deletion on a never-taken path.
Justified on readability + fidelity + coverage, not throughput.

## Validation

- `moon check && moon test --target all && moon fmt && moon info`
  (550/550/572/550; no `.mbti` delta).
- Native C codegen reasoning carried over from #37 (`for b in <view>` → raw load;
  `input[offset]` → per-byte `moonbit_panic` guard).

### Coverage (completion gate)

`moon coverage clean && moon test --enable-coverage --target native && moon
coverage analyze`. The only touched executable file is `terminal/stream.mbt`; the
doc is non-executable. After change 2, **`stream.mbt` reports zero uncovered
lines** — Change 1's rewritten drain loop is fully covered, and Change 2 removes
the previously-accepted uncovered line (`consume_until_ground` in the dead
non-ground arm, `:241`/`:249` across #37 and the interim commit). The completion
gate is fully satisfied with no remaining accepted gap in this file.

## Commit scope

- `refactor(stream)` (internal loop rewrites; no behavior or public API change).
