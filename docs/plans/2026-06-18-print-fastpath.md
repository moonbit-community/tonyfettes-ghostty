# Print hot-path fast lane: bypass the boxed `StreamAction` for `print`

Post-translation performance work on the per-codepoint print path. No behavior
change; the terminal state produced is identical and every test (550) passes.
This is a fidelity-improving deviation: it gives `print` a dedicated typed
dispatch entry the way upstream's `vt` is comptime-specialized per action tag,
instead of routing the single most frequent action through a heap-boxed union.

## Goal

Stop allocating + freeing a `StreamPrint` box on every printable character.

The stream dispatches handler actions through the generic `StreamHandler::vt`,
which takes a `StreamAction` — a `pub(all) enum` with 40+ variants, so it is a
*boxed* value. The hottest action by far, `StreamPrint(codepoint)` (one per
printable char), was built via `self.emit(StreamPrint(codepoint))`, passed to
`vt`, immediately destructured by `apply`'s `match`, and then dropped. The box
exists only to carry a `UInt` through the generic interface — a per-character
heap alloc + free for nothing.

The profile (`plain_lines`) showed this directly: a
`Stream::handle_codepoint <- moonbit_drop_object` leaf line at ~3.5%, i.e. the
freeing of that transient box, attributed to `handle_codepoint` after `print` /
`emit` inline into it.

## Upstream reference

- `upstream/ghostty/src/terminal/stream.zig` — `Stream.next` dispatches actions
  through a `vt(comptime action, value)` that is specialized per action tag at
  compile time. `.print` is a direct typed call into the handler; there is no
  boxed action union on the print path. MoonBit has no comptime specialization,
  so we model the same shape with a dedicated trait method.

## Change

- `terminal/stream.mbt`
  - `StreamHandler` trait gains `fn print(Self, UInt) -> Unit` — a typed fast
    lane for the print action. (`pub(open)` trait, so this is a public `.mbti`
    addition: every implementor must provide it.)
  - `Stream::print` calls `H::print(self.handler, codepoint)` instead of
    `self.emit(StreamPrint(codepoint))`. Both print sources funnel here — the
    ground-state codepoint path (`handle_codepoint`) and the parser-dispatched
    `Print` action (`dispatch_action`) — so both stop boxing.
- `terminal/stream_terminal.mbt`
  - `StreamTerminalHandler::print` goes straight to `self.bridge.print(cp)`.
    `apply(StreamPrint(cp))` did exactly that (`{ self.print(cp); true }`, the
    `Bool` ignored by `vt`), so the fast lane is behavior-identical, minus the
    box build + `match`.
- Test recorders (`stream_test.mbt`, `stream_wbtest.mbt`,
  `stream_terminal_bridge_wbtest.mbt`, `screen_semantic_state_test.mbt`)
  implement `print(cp)` as `self.actions.push(StreamPrint(cp))`, so the recorded
  action stream the tests assert on is unchanged.

## Why the variant stays

`StreamPrint(UInt)` remains in the `StreamAction` enum: it is still the value a
recording handler stores, and any handler that wants the uniform action stream
can route `print` through `vt`. The fast lane is purely an alternative typed
entry for the one hot action; the generic `vt` path is untouched for the other
~40 (rare, off the hot path) actions.

## Acceptance criteria

- Print path allocates no `StreamPrint` box per character; terminal state and
  emitted-action stream identical. Met (550 tests pass).
- `handle_codepoint <- moonbit_drop_object` leaf disappears from the profile.
  Met — the top `drop_object` source becomes `unsafe_blit[GridLine]` (the
  row-object scroll/resize churn), the next lever.

## Validation commands

- `moon check && moon test && moon fmt && moon info`
- `moon bench -p bench/workloads --release --target native`
- `moon run bench/plain_lines --release --target native --profile`
- Three-way: `ghostty-benchmark/run.sh` (ours vs upstream Ghostty vs xterm.js).

## Public API visibility findings

- `terminal/pkg.generated.mbti`: `StreamHandler` trait gains
  `fn print(Self, UInt) -> Unit`. Breaking for external implementors of the open
  trait (must add the method). Justified: it is the print fast lane, a
  fidelity + performance fix.

## Commit scope

- `perf(stream)!` (public `.mbti` trait-method addition).

## Audit/result notes

- `moon bench` (native release), baseline → after:
  - `plain_lines` 581 µs → 498 µs (-14.2%); `wrapped_blob` 551 µs → 461 µs
    (-16.4%); `mixed_realistic` 916 µs → 866 µs (-5.5%); `cjk_text` 805 µs →
    774 µs (-3.7%).
- Three-way net throughput (MB/s, 32 MB corpora, 120×80, baseline-subtracted),
  before → after:
  - `printable` 25.9 → 30.6 (+18%; 5.2× → 4.4× behind Ghostty)
  - `lines` 19.4 → 21.1 (+8.8%; 6.8× → 6.2×)
  - `sgr` 32.4 → 35.5 (+9.6%; 3.6× → 3.4×)
  - `cursor` 30.4 → 33.5 (+10.2%; 4.2× → 3.8×)
  - Ghostty / xterm columns flat (within noise), confirming the move is ours.
  - `sgr` / `cursor` gain too because their corpora interleave printable text
    that now takes the fast lane.
- Profile (`plain_lines`): `handle_codepoint <- moonbit_drop_object` gone; the
  remaining `drop_object` is dominated by `unsafe_blit[GridLine]` (row-object
  blit on scroll/resize) — the next print/scroll-path target.
