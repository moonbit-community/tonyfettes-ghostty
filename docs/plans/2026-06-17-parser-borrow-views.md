# Parser performance: borrow views for dispatch payloads (align with upstream slices)

Post-translation performance work on the escape/CSI/DCS parser → stream hot
path. No behavior change; emitted actions are byte-for-byte identical. This is a
fidelity-improving deviation: it makes the MoonBit payloads borrow the parser's
reused buffers the way upstream borrows fixed-buffer slices.

## Goal

Stop copying the intermediate/param accumulators on every escape-sequence
dispatch. The prior pass (`2026-06-16-parser-alloc-reuse.md`) reused the
accumulator buffers but still handed each `Csi`/`Esc`/`Dcs` an *owned copy*
(`clone_bytes` → `Bytes`, `clone_params` → `ReadOnlyArray`). Upstream instead
builds the payload from borrowed slices into its fixed buffers and copies only at
the real persistence boundary. Recover that: the parser payloads borrow views;
the only copies are at the two points where a value escapes to a (possibly
storing) handler — exactly where upstream copies.

## Upstream files

- `upstream/ghostty/src/terminal/Parser.zig`
  - `next` / `doAction` build `.csi_dispatch` / `.esc_dispatch` / `.dcs_hook`
    from `self.intermediates[0..idx]` and `self.params[0..idx]` — borrowed
    slices into the reused fixed buffers, no allocation.
- `upstream/ghostty/src/terminal/dcs.zig`
  - `hook` reads the borrowed slices synchronously and, at line ~175, *"we copy
    it into the resulting command"* — the persistence boundary copies, the
    parser→handler hand-off borrows.
- `upstream/ghostty/src/terminal/sgr.zig`
  - `Unknown = struct { full: []const u16, partial: []const u16, ... }` — the
    unknown-SGR payload is borrowed slices; ghostty's handler reads it
    synchronously (logs/ignores).

## MoonBit target files

- `terminal/parser/parser.mbt`
  - `Csi` / `Esc` / `Dcs`: `intermediates : ArrayView[Byte]`,
    `params : ArrayView[UInt16]` (was `Bytes` / `ReadOnlyArray[UInt16]`).
  - `do_action` / `next` build the payloads from `self.intermediates` /
    `self.params` directly (MoonBit auto-inserts the `Array → ArrayView`
    conversion); no clone.
  - `clone_bytes`, `clone_params`, `empty_intermediates`, `empty_params`
    removed — an empty dispatch is now just an empty view, no allocation, no
    shared singleton.
- `terminal/stream.mbt`
  - ~40 CSI/ESC consumer sites + their helper signatures take `ArrayView` instead
    of `Bytes` / `ReadOnlyArray[UInt16]`; bodies are unchanged (`ArrayView`
    supports `.length()`, indexing, `for … in`, and array patterns).
  - `csi.intermediates == []` / `== [b'>']` / `== [b'$']` and the `esc`
    equivalents became `is`-pattern matches (`x is []`, `x is [b'>']`).
  - `emit_sgr` takes `ArrayView[UInt16]`.
- `terminal/sgr/sgr.mbt`
  - `SgrParser::from_params` takes `ArrayView[UInt16]`; `SgrParser.params` is an
    `ArrayView` (borrows the caller's CSI params, consumed synchronously).
  - `set_params` snapshots its owned-`Array` argument with `params.copy()` (the
    stored view keeps the copy alive); replaces the removed `@parser.clone_params`.

## The two persistence boundaries (owned, matching upstream)

These escape the synchronous parser→`csi_dispatch` window and cross the public
`StreamHandler` trait to a consumer that may store them, so they own their data.
Both are *rare* variants, off the hot path.

- `DcsHookPayload` (`terminal/stream.mbt`) keeps owned `Bytes` /
  `ReadOnlyArray[UInt16]`; `from_dcs` copies the `@parser.Dcs` views in
  (`to_owned`). A DCS hook is typically held across the following `dcs_put` /
  `dcs_unhook` bytes, which rewind the parser buffers — mirrors `dcs.zig`'s
  copy-into-Command.
- `SgrUnknown` (`terminal/sgr/sgr.mbt`) keeps `full : ReadOnlyArray[UInt16]`;
  `make_unknown` copies the param view (`to_owned`), with `partial` a slice of
  that copy. Known SGR attributes (the common path) are borrow-free value types;
  only the unrecognized-code branch copies.

## Dependencies and invariants

- **Synchronous-consume contract.** `Parser::next` returns the borrowed payloads;
  the stream dispatches them inline (`dispatch_action` → `H::vt`, which never
  re-enters the parser), and only the *next* byte's `next()` rewinds the buffers
  via `clear()`. So a `Csi`/`Esc`/`Dcs` view is always fully consumed before its
  backing buffer is touched. Documented on the payload doc-comments.
- **Why the two boundaries copy.** A `StreamHandler` may accumulate actions and
  inspect them after further parsing (the test harness in
  `terminal/stream_test.mbt` does exactly this). A borrowed `SgrUnknown` /
  `DcsHookPayload` would read stale params there. Copying at these two
  handler-facing variants keeps the public action stream storable; the internal
  parser→`csi_dispatch` payloads stay borrowed because that boundary is
  synchronous.
- **`#valtype` not applied.** Marking `Csi` `#valtype` (to match upstream's
  by-value payload) is rejected by the compiler: a value type may not hold the
  abstract `SepList` field. Left as plain structs; the borrow conversion is the
  win.

## Acceptance criteria

- Escape/CSI/ESC dispatch allocates nothing per sequence (no clone); emitted
  actions byte-for-byte identical. Met.
- DCS-hook / unknown-SGR payloads remain owned and storable. Met.

## Validation commands

- `moon check && moon test && moon coverage analyze && moon fmt && moon info`
- `moon bench -p bench/workloads --release --target native`
- `moon run bench/query_storm --release --target native --profile`

## Coverage findings

- No new uncovered line in the touched code. The one uncovered line reported in
  `terminal/stream.mbt` (`next_slice_capped`'s `consume_until_ground` arm) is
  pre-existing and untouched by this change. 550 terminal tests pass.

## Public API visibility findings

- `terminal/parser/pkg.generated.mbti`: `Csi`/`Esc`/`Dcs` field types →
  `ArrayView`; `clone_bytes` / `clone_params` removed.
- `terminal/sgr/pkg.generated.mbti`: `SgrParser::from_params` param →
  `ArrayView[UInt16]`. `SgrUnknown` unchanged (`full` stays `ReadOnlyArray`).
- `terminal/pkg.generated.mbti` (stream): unchanged — `DcsHookPayload` stayed
  owned, so its accessors keep their `Bytes` / `ReadOnlyArray` signatures.

## Commit scope

- `perf(parser)!` (public `.mbti` field-type change on the dispatch payloads).

## Audit/result notes

- Benchmarks (`moon bench`, native release), baseline → after:
  - `query_storm` 9.91 ms → 8.49 ms (-14%) — each CSI dispatch no longer copies
  - `scroll_full` 8.90 ms → 8.54 ms (-4%); `mixed_realistic` 959 µs → 926 µs
    (-3.4%); `cjk_text` 814 µs → 790 µs (-3%); `sgr_storm` 9.19 ms → 8.96 ms
    (-2.5%)
  - controls `wrapped_blob` / `colored_log` / `scroll_storm` / `color_storm` /
    `osc_titles` flat; `plain_lines` within run noise (no CSI on its path)
- Profile (`query_storm`): `clone_params` / `clone_bytes` / `Bytes::from_array`
  drop off the table entirely; `moonbit_make_bytes` 2.3%. The remaining
  `Stream::csi_dispatch` time is the actual dispatch/emit work, not payload
  copying.
