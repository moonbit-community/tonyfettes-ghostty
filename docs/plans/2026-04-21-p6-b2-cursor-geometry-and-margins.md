# P6.B2 Cursor Geometry And Margins

## Goal

Translate the cursor-positioning, margin, and cursor-style storage needed by
`stream_terminal.zig` without pulling saved-cursor charset state, tabstops, or
screen cell mutations into the same slice.

## Upstream files

- `upstream/ghostty/src/terminal/Terminal.zig`
- `upstream/ghostty/src/terminal/Screen.zig`

## MoonBit target files

- `src/terminal/terminal_cursor_state.mbt`
- `src/terminal/terminal_cursor_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p6-b-roadmap.md`
- `docs/plans/2026-04-21-p6-b2-cursor-geometry-and-margins.md`

## Dependency notes

- reuses the translated stream-facing `CursorStyle` enum from `ansi.mbt`
- intentionally stops before `saveCursor` / `restoreCursor` because upstream
  save state also captures charset configuration
- intentionally stops before tabstop state because `horizontalTab*` depends on
  a separate tabstop carrier

## Acceptance criteria

- a cursor geometry state exists with active x/y, pending-wrap state, full
  scrolling-region bounds, and cursor visual style storage
- applying a CSI cursor-style request returns the upstream-equivalent blink
  mode and updates the stored visual style
- `setCursorPos` semantics are preserved for clamping, one-indexed inputs,
  origin-mode offsets, and pending-wrap clearing
- top/bottom and left/right margin setters preserve the upstream enable/ignore
  rules and home the cursor via `setCursorPos(1, 1, origin_mode)`
- blackbox tests cover defaults, full reset, style mapping, clamping,
  origin-mode positioning, and invalid/disabled margin cases

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/terminal_cursor_state.mbt` is fully covered by the added
  blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not touch that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the public API stays limited to one opaque cursor carrier plus the
  `CursorVisualStyle` enum required by the read accessor
- margin setters remain explicit about their enable/origin inputs instead of
  quietly baking terminal-mode state into hidden globals
- splitting saved-cursor work back out avoids leaking charset concerns into a
  cursor-positioning slice that otherwise stays independent and green

## Audit / result notes

- added `TerminalCursorState` for cursor position, pending-wrap state,
  scrolling-region bounds, and cursor-style storage
- added `apply_cursor_style` so later bridge work can reuse the upstream CSI
  cursor-style mapping while keeping blink-mode state in the mode layer
- added blackbox tests for defaults, full reset, style mapping, clamping,
  origin-mode positioning, zero-dimension clamping, and invalid/disabled
  margin handling
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
