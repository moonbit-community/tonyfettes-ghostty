# Parser performance: reuse accumulator buffers + share empty dispatch payloads

Post-translation performance work on the escape/CSI/DCS parser hot path. No
behavior change; every edit maps to an existing upstream symbol and the emitted
actions are byte-for-byte identical.

## Goal

Stop allocating on every escape-sequence boundary. Upstream's parser keeps the
intermediate/param accumulators as fixed-size arrays plus length counters, so
`clear()` only rewinds the counts and the per-byte parse path allocates nothing.
The MoonBit translation reintroduced churn by (a) reassigning fresh `[]` arrays
in `clear()` on every Escape/CsiEntry/DcsEntry transition, and (b) building a
`Buffer` even for the common no-intermediate / no-param dispatch. Recover
upstream's allocation-free steady state.

## Upstream files

- `upstream/ghostty/src/terminal/Parser.zig`
  - `intermediates: [MaxIntermediate]u8` + `intermediates_idx`,
    `params: [MaxParams]u16` + `params_idx` — fixed storage, length counters
  - `clear()` resets `*_idx = 0` (no allocation, buffers retained)
  - CSI/ESC/DCS dispatch builds the `Action` from slices of those fixed buffers;
    the MoonBit side cannot hand out slices into owned `Array`s, so it copies
    (`clone_bytes` / `clone_params`) — the copies never alias the accumulators.

## MoonBit target files

- `terminal/parser/parser.mbt`
  - `Parser::clear` rewinds the accumulators with `Array::clear()` (length → 0,
    backing buffer retained) instead of `self.intermediates = [] ; self.params = []`.
    The `intermediates` / `params` fields therefore drop `mut` (never reassigned).
  - `clone_bytes` returns a shared module-level empty `Bytes` for an empty source
    and otherwise allocates once via `Bytes::from_array` (was `Buffer` +
    `write_byte` loop + `to_bytes`, i.e. three allocations and a grow loop).
  - `clone_params` returns a shared module-level empty `ReadOnlyArray` for an
    empty source; non-empty stays `ReadOnlyArray::from_array` (a `FixedArray`
    copy).
  - `empty_intermediates : Bytes` / `empty_params : ReadOnlyArray[UInt16]` —
    package-private shared immutables for those fast paths.

## Dependencies and invariants

- **No aliasing.** The dispatched `Csi` / `Esc` / `Dcs` payloads are built from
  `clone_bytes(self.intermediates)` / `clone_params(self.params)`, both of which
  deep-copy (`Bytes::from_array`, `FixedArray::from_array`). No payload retains a
  reference to the parser's `intermediates` / `params` arrays, so rewinding and
  reusing those arrays in `clear()` cannot mutate an already-emitted action.
- **Shared empties are safe.** `Bytes` and `ReadOnlyArray` are immutable, so
  handing the same `empty_intermediates` / `empty_params` instance to every
  no-intermediate / no-param dispatch is behavior-identical to a fresh empty
  value (`b"" == b""`, empty array == empty array).
- The accumulator-size guards (`MaxIntermediate`, `MaxParams`, `MaxParamDigits`)
  and the param-separator bitset are unchanged; only the storage lifecycle of
  the two arrays changes.

## Acceptance criteria

- Escape/CSI/DCS parsing allocates nothing per sequence in steady state beyond
  the dispatched payload copies; emitted actions are byte-for-byte identical.
- No new public API surface.

## Validation commands

- `moon check && moon test && moon coverage analyze && moon fmt && moon info`
- `moon bench -p bench/workloads --release --target native`

## Coverage findings

- `moon coverage analyze` reports no uncovered line in
  `terminal/parser/parser.mbt`. The empty fast paths (`\x1b[c` → empty
  intermediates and params) and the non-empty paths (`\x1b[?7$p` intermediates,
  `\x1b[18t` params) are all exercised by the existing parser and stream tests.
  550 tests pass.

## Public API visibility findings

- `terminal/parser/pkg.generated.mbti` reviewed: no change. `clone_bytes` /
  `clone_params` keep their signatures; the two new bindings are package-private
  `let`s; dropping `mut` on private struct fields is not part of the interface.

## Commit scope

- `perf(parser)`

## Audit/result notes

- Benchmarks (`moon bench`, native release), `clear()` is on every escape-
  sequence boundary so all escape-heavy workloads improve:
  - `query_storm` 17.22 ms → 12.01 ms (-30%)
  - `sgr_storm` 16.84 ms → 11.25 ms (-33%)
  - `color_storm` 29.73 ms → 27.56 ms (-7%)
  - `tui_redraw` 2.02 ms → 1.81 ms (-10%); `colored_log` 629 µs → 556 µs (-12%)
  - `plain_lines` / `wrapped_blob` (no escape sequences) unchanged
- Profile (`moon run bench/query_storm --release --target native --profile`):
  `Parser::enter_escape <- moonbit_drop_object` (was 4.4% leaf) drops off the
  table; the `Buffer::to_bytes` / `Buffer::inner <- moonbit_make_bytes` clone
  costs disappear; `Parser::do_action` self-time 4.7% → 3.3%. The remaining hot
  spot is the `Stream::csi_dispatch` refcount traffic over each `Csi` payload —
  a deeper, more fidelity-sensitive change left for a follow-up.
