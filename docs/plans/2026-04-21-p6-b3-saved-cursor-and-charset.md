# P6.B3 Saved Cursor And Charset

## Goal

Translate the saved-cursor carrier and charset state needed by
`saveCursor` / `restoreCursor` without pulling tabstop layout, screen cell
storage, or bridge-side cursor restoration logic into the same slice.

## Upstream files

- `upstream/ghostty/src/terminal/Screen.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`

## MoonBit target files

- `src/terminal/terminal_saved_cursor_state.mbt`
- `src/terminal/terminal_saved_cursor_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p6-b-roadmap.md`
- `docs/plans/2026-04-21-p6-b3-saved-cursor-and-charset.md`

## Dependency notes

- reuses `TerminalCursorState` for active x/y and pending-wrap capture
- reuses `CellStyle` for cursor style snapshots
- reuses `charsets.mbt` slot and charset enums instead of inventing a second
  terminal-local charset vocabulary
- MoonBit structs are reference-semantics, so save/restore needs explicit deep
  copies for style and charset state to match the upstream snapshot contract

## Acceptance criteria

- a charset carrier exists with slot configuration, GL/GR selection,
  single-shift storage, and reset behavior that matches the upstream
  `CharsetState`
- a saved-cursor state exists with overwrite-on-save, default-on-empty-restore,
  and reset-to-empty behavior that matches upstream `saveCursor`,
  `restoreCursor`, and `Screen.reset`
- saving a cursor snapshots style and charset state instead of aliasing later
  mutations from the live terminal state
- blackbox tests cover defaults, charset invocation behavior, save/restore
  capture, overwrite semantics, reset behavior, and copy isolation

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/terminal_saved_cursor_state.mbt` is fully covered by the added
  blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not touch that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the public API stays limited to three opaque carriers with method-based
  access; there are no new public fields or public mutable fields
- explicit deep-copy helpers are required because MoonBit structs are
  reference-semantics, and plain assignment would break upstream save/restore
  snapshot behavior
- `cursor_protected` is used instead of `protected` to avoid introducing a new
  reserved-keyword warning into the package API

## Audit / result notes

- added `ScreenCharsetState` for slot configuration, GL/GR selection,
  single-shift storage, and reset behavior that matches the upstream
  `CharsetState`
- added `ScreenSavedCursor` and `ScreenSavedCursorState` so saved cursor
  snapshots can capture x/y, style, protection state, pending-wrap state,
  origin mode, and charset configuration
- added blackbox tests for charset defaults/reset, charset invocation,
  default restore behavior, save-time snapshot capture, overwrite semantics,
  reset behavior, and copy isolation on both save and restore paths
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
