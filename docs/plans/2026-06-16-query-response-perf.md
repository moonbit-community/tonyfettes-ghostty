# Query-response performance: cache constant replies + core utf8 encode

Post-translation performance work on the stream-terminal query/report path. No
behavior change; every edit maps to an existing upstream symbol or to the
approved compatibility adapter recorded below.

## Goal

Stop rebuilding identical device-status / version reply bytes on every query.
Upstream encodes these replies into a fixed stack buffer or a `*std.Io.Writer`
and allocates nothing per query; the MoonBit facade reintroduced a per-call
`Bytes` allocation by returning the reply as a value. Precompute the constant
default replies once so the hot query path (`\x1b[c`, `\x1b[>q`) hands the
writer a shared value, recovering upstream's no-per-query-allocation property.

## Upstream files

- `upstream/ghostty/src/terminal/device_attributes.zig`
  - `Primary.encode(writer)`, `Secondary.encode(writer)`, `Tertiary.encode(writer)`
    (each streams the reply into a writer; the default config is constant)
- `upstream/ghostty/src/termio/stream_handler.zig`
  - `reportXtversion` — `bufPrint("\x1BP>|{s} {s}\x1B\\", ...)` into a fixed
    `[288]u8` stack buffer, i.e. no per-query heap allocation
- `upstream/ghostty/src/terminal/stream.zig`
  - CSI `>q` dispatch → `.xtversion`; primary DA dispatch → device attributes

## Approved compatibility adapters

All of the following are package-private translation-side state introduced to
recover upstream's no-per-query-allocation property. They cache the constant
output of an existing upstream-mapped encoder; the emitted bytes are identical
to the per-call result. None are exported (`.mbti` unchanged).

- `default_primary_da_response`, `default_secondary_da_response`,
  `default_tertiary_da_response` (`Bytes`) cache the output of the existing
  `DeviceAttributes::default().encode(Primary|Secondary|Tertiary)` — itself the
  translation of `device_attributes.zig`'s `Primary/Secondary/Tertiary.encode`,
  which upstream streams into a `*std.Io.Writer` (no per-query heap alloc). The
  default device config is constant, so its three encodings never change. The
  `None`-effect branch of `report_device_attributes` reads the matching cache
  instead of rebuilding the `DeviceAttributes::default()` struct graph
  (3 nested structs + `[AnsiColor]` array) plus a `Buffer` on every query.
- `encode_xtversion_response(reported : Bytes) -> Bytes` is the approved adapter
  for upstream's `reportXtversion` reply construction. Upstream uses a single
  `bufPrint` into a fixed `[288]u8` stack buffer; MoonBit has no equivalent
  stack-format primitive in the facade, so this names that one construction
  (`DCS >| <name> ST`) in one place. It is called from the live
  `report_xtversion` path and reused to precompute `default_xtversion_response`
  once. Rationale for a named function rather than two inline copies: avoids
  duplicating the byte-layout literal between the cache initializer and the
  custom-name path, keeping a single source of truth for the reply framing.

## MoonBit target files

- `terminal/stream_terminal_bridge.mbt`
  - `default_primary_da_response`, `default_secondary_da_response`,
    `default_tertiary_da_response`: module-level `Bytes` caching the output of
    the existing `DeviceAttributes::default().encode(Primary|Secondary|Tertiary)`
  - `encode_xtversion_response` + `default_xtversion_response` (above)
  - `report_device_attributes` / `report_xtversion`: None / empty-effect
    branches send the cached value
  - `truncate_utf8` and the xtversion path: `utf8_bytes` (local helper, removed)
    replaced with `@moonbitlang/core/encoding/utf8.encode`

## Dependencies and invariants

- The cached replies are only used on the default branch (`device_attributes`
  effect returns `None`; `xtversion` effect returns `""`). When a host supplies
  custom attributes / a custom version string, the live encode path runs
  unchanged, so the cache never masks host-provided values.
- `DeviceAttributes::default()` and its `encode` are unchanged; the cache stores
  their constant output, byte-for-byte identical to the per-call result.
- `@utf8.encode(StringView)` produces the same UTF-8 bytes as the removed
  `Buffer::write_string_utf8` for well-formed strings; it allocates one
  exact-size array via the core intrinsic instead of a grow-and-copy `Buffer`.
- `MaxXtversionBytes` truncation guard is preserved for the custom-name path;
  the constant default name (`libghostty`) is statically within the limit.

## Acceptance criteria

- Default device-attributes and XTVERSION replies are encoded once, not per
  query; reply bytes are byte-for-byte identical to the previous behavior.
- No new public API surface.

## Validation commands

- `moon check && moon test && moon coverage analyze && moon fmt && moon info`
- `moon bench -p bench/workloads --release --target native`

## Coverage findings

- `moon coverage analyze` ran clean over the native test build. After splitting
  the `None` device-attributes branch into per-request arms, the default
  Secondary (`>c`) and Tertiary (`=c`) reply arms were initially uncovered (the
  pre-split single line was covered only via Primary). Added
  `test "stream terminal/default secondary and tertiary device attributes"` in
  `terminal/stream_terminal_test.mbt`, which drives `\x1b[c\x1b[>c\x1b[=c`
  against a default `StreamTerminal` and asserts the three cached replies
  (`\x1B[?62;22c`, `\x1B[>1;0;0c`, `\x1BP!|00000000\x1B\\`).
- After the new test, no touched line in `stream_terminal_bridge.mbt` is
  uncovered. The default `xtversion` reply, the custom-name xtversion path, and
  `truncate_utf8` remain covered by existing title / version tests. 550 terminal
  tests pass.

## Commit scope

- `perf(terminal)`

## Public API visibility findings

- `.mbti` reviewed: no change. `encode_xtversion_response` and the four
  `default_*_response` bindings are package-private (`fn` / `let`, no `pub`);
  the removed `utf8_bytes` was package-private as well. No new exported items.

## Audit/result notes

- Benchmarks (`moon bench`, native release): `query_storm` 23.74 ms → 16.29 ms
  (-31%); `osc_titles` benefits from the `@utf8.encode` swap on `truncate_utf8`.
  Controls (`plain_lines`, `sgr_storm`) unchanged. Profile confirms
  `moonbit_make_bytes` 5.1% → 2.8% and `Buffer::grow_if_necessary` drops off the
  `query_storm` self-time table.
