# P11.0 Terminal Host Surface Checklist

## Goal

Record the exact Phase 11 ownership split for the upstream terminal host object
so the next implementation steps stay faithful to `src/terminal/c/terminal.zig`
and `src/terminal/c/grid_ref.zig` without freezing ABI-shaped glue into the
MoonBit API.

## Upstream files

- `upstream/ghostty/src/terminal/c/terminal.zig`
- `upstream/ghostty/src/terminal/c/grid_ref.zig`

## MoonBit targets

Docs in this task:

- `docs/plan.md`
- `docs/plans/2026-04-22-p11-0-terminal-host-surface-checklist.md`

Planned implementation targets:

- `src/terminal/stream_terminal.mbt`
- `src/terminal/stream_terminal_test.mbt`
- `src/terminal/page_state.mbt`
- `src/terminal/selection.mbt`
- `src/terminal/point.mbt`
- one new grid-ref owner surface if the existing modules cannot hold the
  pin/query helpers cleanly

## Current translated boundary

- `StreamTerminal` already owns a persistent `Stream` plus translated terminal
  state behind one public object.
- The current public surface already covers:
  - `new`
  - `deinit`
  - `next`
  - `next_slice`
  - title snapshot
  - cursor position snapshot
  - cursor visual style snapshot
  - active-screen row and cell snapshots
  - palette-dirty observation and clear
- The current constructor already accepts closure-based effects for:
  - `write_pty`
  - `bell`
  - `color_scheme`
  - `device_attributes`
  - `enquiry`
  - `size`
  - `title_changed`
  - `xtversion`

The missing Phase 11 work is the richer mutable host-object behavior from
`terminal.zig`: callback reconfiguration, resize/reset/scroll/mode mutation,
typed terminal queries, and page-pin-backed grid references.

## MoonBit alignment rules for Phase 11

- Do not mirror `Option`, `TerminalData`, or `get_multi` as public enums just
  because the C wrapper needed ABI-stable dispatch tags.
- Do not introduce a `userdata` field. In MoonBit, callbacks close over their
  own environment, so the upstream `userdata` slot is ABI-only glue.
- Preserve reachable semantics, callback timing, and mutation/query behavior,
  but expose them as typed MoonBit methods and snapshot values.
- Keep `StreamTerminal` as the single public owner of the terminal host object.
  Do not expose raw bridge state or page-list internals.
- Public grid refs must stay opaque and immutable. They represent a stable pin
  into terminal page state, not a mutable coordinate record.

## P11 implementation split

### P11.A `terminal.zig` core host object

Scope:

- lifecycle and write entrypoint:
  - `new`
  - `free`
  - `vt_write`
- typed callback reconfiguration on an existing `StreamTerminal`
- non-query mutators:
  - `scroll_viewport`
  - `resize`
  - `reset`
  - `mode_get`
  - `mode_set`
  - title and pwd setters
  - default/current color and palette setters

Required invariants:

- split escape handling must remain persistent across repeated writes
- callback changes must take effect on the existing terminal object without
  reconstruction
- clearing a callback must be supported
- `resize` must:
  - reject zero rows or columns
  - update pixel dimensions with saturating multiplication
  - disable synchronized-output mode
  - emit the in-band size report only when mode 2048 is enabled and
    `write_pty` is installed
- `device_attributes` callback false/no-callback paths must fall back to the
  translated default attributes
- silent no-callback behavior for bell, ENQ, XTVERSION, size, and title-change
  paths must match upstream

Recommended public shape:

- keep constructor effects for convenience
- add typed setter methods for runtime callback replacement and clearing
- keep setters as methods on `StreamTerminal`, not as public mutable fields

### P11.B `grid_ref.zig` pin/query helpers

Scope:

- create an opaque grid-ref value from a terminal point
- round-trip point reconstruction from a grid ref
- query helpers for:
  - cell snapshot
  - row snapshot
  - style snapshot
  - grapheme codepoint sequence
  - hyperlink URI

Required invariants:

- a grid ref must be backed by a page pin, not by raw row/column coordinates
- null/out-of-bounds/expired refs map to invalid/no-value behavior, not aborts
- returned row/cell/style values are snapshots, not live mutable aliases
- grapheme and hyperlink access must preserve upstream buffer/empty semantics,
  but can use MoonBit `Bytes`, `String`, and arrays instead of output pointers

Dependency note:

- `P11.B` starts only after `P11.A` lands the stable terminal-owned pin entry
  points. After that, `P11.B` and `P11.C` can run in parallel.

### P11.C typed terminal query surface

Scope:

- translate the non-graphics `TerminalData` surface into typed getters
- close the existing Phase 7 snapshots against upstream host-object queries
- include at least:
  - cols and rows
  - cursor x/y and pending-wrap state
  - active screen
  - cursor visible and cursor style
  - kitty keyboard flags
  - mouse tracking aggregate state
  - title and pwd
  - total rows and scrollback rows
  - width and height in pixels
  - current/default foreground, background, and cursor colors
  - current/default palette

MoonBit adaptation rules:

- do not ship a generic `get_multi` unless a real MoonBit caller needs it
- prefer direct getters or a small typed snapshot struct over enum-keyed
  dispatch
- keep graphics-only getters deferred to `P13.C`

## Upstream validation corpus split

### P11.A tests from `terminal.zig`

- `new/free`
- `new invalid value`
- `free null`
- `scroll_viewport`
- `scroll_viewport null`
- `reset`
- `reset null`
- `resize`
- `resize null`
- `resize invalid value`
- `mode_get and mode_set`
- `mode_get null`
- `mode_set null`
- `mode_get unknown mode`
- `mode_set unknown mode`
- `vt_write`
- `vt_write split escape sequence`
- callback tests:
  - `set write_pty callback`
  - `set write_pty without callback ignores queries`
  - `set write_pty null clears callback`
  - `set bell callback`
  - `bell without callback is silent`
  - `set enquiry callback`
  - `enquiry without callback is silent`
  - `set xtversion callback`
  - `xtversion without callback reports default`
  - `set title_changed callback`
  - `title_changed without callback is silent`
  - `set size callback`
  - `size without callback is silent`
  - `set device_attributes callback primary`
  - `set device_attributes callback secondary`
  - `set device_attributes callback tertiary`
  - `device_attributes without callback uses default`
  - `device_attributes callback returns false uses default`
- setter-side state tests:
  - `set and get title`
  - `set and get pwd`
  - `resize updates pixel dimensions`
  - `resize pixel overflow saturates`
  - `resize disables synchronized output`
  - `resize sends in-band size report`
  - `resize no size report without mode 2048`
  - `resize in-band report without write_pty callback`
  - `set and get color_foreground`
  - `set and get color_background`
  - `set and get color_cursor`
  - `set and get color_palette`
  - `set color sets dirty flag`

### P11.B tests from `terminal.zig` and `grid_ref.zig`

- `grid_ref`
- `grid_ref null terminal`
- `grid_ref out of bounds`
- `point_from_grid_ref roundtrip active`
- `point_from_grid_ref roundtrip viewport`
- `point_from_grid_ref history ref to active returns no_value`
- `point_from_grid_ref null terminal`
- `point_from_grid_ref null node`
- all `grid_ref.zig` cell/row/style/grapheme/hyperlink tests

### P11.C tests from `terminal.zig`

- `get cols and rows`
- `get cursor position`
- `get null`
- `get cursor_visible`
- `get active_screen`
- `get kitty_keyboard_flags`
- `get mouse_tracking`
- `get total_rows`
- `get scrollback_rows`
- `get invalid`
- `get title set via vt_write`
- `get color default vs effective with override`
- `get color default returns no_value when unset`
- `get color_palette_default vs current`
- `get_multi success`
- `get_multi error sets out_written`
- `get_multi null keys returns invalid_value`

`get_multi` remains part of the upstream validation corpus, but not a required
MoonBit public API. Re-express those assertions through typed getters unless a
real batch-query consumer appears during implementation.

## Explicit deferrals

These stay out of Phase 11:

- `kitty_image_storage_limit`
- `kitty_image_medium_file`
- `kitty_image_medium_temp_file`
- `kitty_image_medium_shared_mem`
- `kitty_graphics`
- `src/terminal/c/kitty_graphics.zig`

Those close in `P13.C` together with the rest of the graphics-dependent
terminal surface.

## Acceptance criteria

- The Phase 11 write split is explicit and dependency-correct.
- The MoonBit API direction is clear where the C wrapper used ABI-only glue.
- Callback, mutation, query, and grid-pin responsibilities are assigned to
  concrete follow-on tasks.
- Graphics-only fields are explicitly deferred so Phase 11 can stay green and
  reviewable.

## Validation

- docs review only

## Audit/result notes

- `terminal.zig` mixes lifecycle, callback registration, mutators, getters,
  and graphics knobs in one wrapper file. Splitting those semantics across
  `P11.A`, `P11.B`, and `P11.C` gives atomic green tasks without losing the
  upstream ownership model.
- `grid_ref.zig` is not a coordinate helper. Its semantics depend on
  `PageList.Pin`, so the MoonBit translation must model it as an opaque,
  terminal-owned pin snapshot.
- The existing `StreamTerminal` facade already owns the persistent parser
  stream, so Phase 11 should extend that owner instead of adding a second
  public terminal wrapper.
