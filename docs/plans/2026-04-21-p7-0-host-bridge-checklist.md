# P7.0 Host Bridge Checklist And Validation Corpus

## Goal

Record the exact public host-bridge shape for the next implementation step so
`P7.1` can land a small, stable VT-facing API instead of exposing translation
scaffolding directly.

## Upstream files

- `upstream/ghostty/src/terminal/stream_terminal.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`
- `upstream/ghostty/src/terminal/c/terminal.zig`
- `upstream/ghostty/src/termio/stream_handler.zig`
- `upstream/ghostty/src/termio/Termio.zig`

## MoonBit targets

Docs in this task:

- `docs/plan.md`
- `docs/plans/2026-04-21-p7-0-host-bridge-checklist.md`

Planned implementation targets for `P7.1`:

- `src/terminal/stream_terminal.mbt`
- `src/terminal/stream_terminal_test.mbt`

## Current translated boundary

- `Stream::next` and `Stream::next_slice` already accept `Byte` and `Bytes`
  and preserve split-sequence parser state across calls.
- `StreamTerminalBridgeState` already applies the translated
  `stream_terminal.zig` action surface and owns the parser-facing terminal
  model.
- `StreamTerminalBridgeEffects` already models the host callback boundary for
  PTY writes, bell, title changes, device attributes, ENQ, XTVERSION, size
  queries, and color-scheme queries.
- The missing piece is the persistent host-facing wrapper that owns both the
  stream parser state and the translated terminal state behind one public API.

## P7.1 implementation checklist

### Public facade

- Add an opaque `StreamTerminal` type in `src/terminal/stream_terminal.mbt`.
- `StreamTerminal` owns:
  - persistent `Stream[Handler]` parser state
  - translated terminal state currently held by `StreamTerminalBridgeState`
  - host effect callbacks
- External callers feed bytes to `StreamTerminal`; they do not assemble
  `Stream`, `StreamAction`, or `StreamTerminalBridgeState` manually.

### Public methods required for P7.1

- constructor with default readonly effects
- constructor with explicit effects callbacks
- `next(Byte)`
- `next_slice(Bytes)`
- `deinit()`

### Public read-only observation surface

Expose only the minimum read-only surface needed by blackbox tests and external
consumers in the current parser scope:

- title snapshot
- cursor position and cursor style snapshot
- row and cell snapshots for the active screen
- palette-dirty observation and clear

Do not expose raw mutable terminal internals or raw action streams just to make
tests easier.

### Visibility target

By the end of `P7.1`, these should not remain part of the intended public host
API:

- `StreamAction`
- `StreamTerminalBridgeState`
- `StreamTerminalBridgeEffects`

The façade may reuse them internally, but the public package surface should
shift toward `StreamTerminal` plus small read-only snapshot types. If any of
the bridge symbols must stay public temporarily to avoid a red transition,
record that as explicit temporary debt in the `P7.1` audit.

## Validation corpus for P7.1 and P7.2

### P7.1 required blackbox facade tests

These tests should land with the `StreamTerminal` façade in the same green
commit:

- plain printable write from `Bytes`
- split escape sequence across multiple writes
- bell callback
- DECRQM / mode report through `write_pty`
- ENQ custom response and silent no-callback path
- XTVERSION custom response and default fallback
- title change callback plus title snapshot
- XTWINOPS size report callback path and silent no-callback path
- device attributes primary, secondary, tertiary, and default fallback
- color-scheme device-status reply path

### Existing translated suites to keep green during P7.1

- `src/terminal/stream_test.mbt`
- `src/terminal/stream_terminal_bridge_test.mbt`

These stay as internal confidence tests while the public façade is added.

### Agreed parity corpus for P7.2

Start parity expansion from upstream tests that already exercise the host-side
VT boundary directly:

- `upstream/ghostty/src/terminal/c/terminal.zig`
  - `vt_write`
  - `vt_write split escape sequence`
  - `set write_pty callback`
  - `set bell callback`
  - `set enquiry callback`
  - `set xtversion callback`
  - `xtversion without callback reports default`
  - `set title_changed callback`
  - `set size callback`
  - `set device_attributes callback primary`
  - `set device_attributes callback secondary`
  - `set device_attributes callback tertiary`
  - `device_attributes without callback uses default`
  - `get title set via vt_write`

Treat those as the first public-facade parity set because they map directly to
the parser-stack scope already translated.

## Explicit deferrals

These are outside the `P7.1` host-bridge surface and should not be smuggled in
as incidental API growth:

- `termio/stream_handler.zig` mailboxes, renderer wakeups, clipboard write
  policy, and other application-runtime side effects
- richer DCS host behavior such as XTGETTCAP integration
- APC host behavior beyond the current parser-facing no-op surface
- resize/configuration APIs beyond the callback-based query responses already
  translated
- PWD getter/setter parity
- formatter, render, search, and scrollback behavior beyond the agreed
  host-facade parity corpus

## Acceptance criteria

- `P7.1` has a concrete ownership model for the public VT façade.
- The intended public API is explicit and smaller than the current bridge
  scaffolding surface.
- The first parity corpus for the public façade is explicitly listed and tied
  to upstream tests.
- Deferred work is listed so `P7.1` stays reviewable and green.

## Validation

- docs review only

## Audit/result notes

- Upstream exposes a persistent VT stream through `Terminal.vtStream()` and a
  C wrapper that owns both the terminal state and the persistent stream object.
  The MoonBit translation now has those pieces separately, so `P7.1` should
  restore that ownership boundary instead of freezing the bridge scaffolding as
  the long-term public API.
- The current public surface still reflects translation staging more than
  intended external use. This checklist makes the cleanup part of the next
  implementation gate rather than a vague later cleanup.
