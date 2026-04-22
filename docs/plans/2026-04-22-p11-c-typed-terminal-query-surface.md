# P11.C Typed Terminal Query Surface

## Goal

Close the non-graphics `src/terminal/c/terminal.zig` query surface as typed
MoonBit methods on `StreamTerminal`, without reintroducing ABI-shaped
`TerminalData` / `get_multi` dispatch.

## Upstream files

- `upstream/ghostty/src/terminal/c/terminal.zig`

## MoonBit targets

- `src/terminal/color.mbt`
- `src/terminal/stream_terminal.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/stream_terminal_query_test.mbt`
- `src/terminal/terminal_screen_state.mbt`
- `src/terminal/terminal_scrollbar.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p11-c-typed-terminal-query-surface.md`

## Scope

- add typed getters for the remaining host query surface:
  - cursor visibility and pending-wrap state
  - kitty keyboard flags
  - mouse tracking aggregate state
  - scrollbar snapshot
  - current/default foreground, background, cursor colors
  - current/default palette snapshots
- add host-side default color/palette setters needed to exercise the upstream
  default-vs-override semantics from blackbox tests

## Acceptance criteria

- `StreamTerminal` exposes typed query methods instead of enum-keyed dispatch
- `get_multi` stays out of the public API
- color/palette setters mutate terminal defaults, not OSC override state
- palette/scrollbar snapshots are returned as copies, not mutable aliases into
  terminal internals
- kitty-graphics queries remain deferred to `P13.C`

## Validation

Ran:

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage review

Touched-file coverage is clean.

Remaining uncovered lines are pre-existing:

- `src/terminal/stream.mbt:222`
- `src/terminal/stream_terminal_bridge.mbt:2427`
- `tools/stream_terminal_perf/main.mbt`

## Public API review

Intentional new public surface:

- `TerminalScrollbar`
- `StreamTerminal::{cursor_visible,cursor_pending_wrap,kitty_keyboard_flags,mouse_tracking,scrollbar}`
- `StreamTerminal::{foreground_color,background_color,cursor_color}`
- `StreamTerminal::{default_foreground_color,default_background_color,default_cursor_color}`
- `StreamTerminal::{palette,default_palette}`
- `StreamTerminal::{set_default_foreground_color,set_default_background_color,set_default_cursor_color,set_default_palette}`

No public mutable fields were introduced.

Kept out of the public API on purpose:

- `TerminalData`
- `get`
- `get_multi`
- internal color/scrollback helper structs

## Notes

- `set_default_palette` accepts `Array[RGB]?` so MoonBit can express the C
  wrapper's `NULL` reset behavior. Length mismatches return
  `TerminalResultCode::InvalidValue`.
- `title()` / `pwd()` remain the existing optional MoonBit snapshots rather
  than being forced back into empty-string ABI behavior.
- Host-side color setters were included in this slice because the upstream
  query tests depend on default-vs-current color semantics; keeping them out
  would have left that part of `terminal.zig` untestable through the public
  MoonBit surface.
