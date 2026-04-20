# P6.A3 Protected, Status, And Mouse State

## Goal

Translate the remaining lightweight state needed from `Screen.zig` and
`Terminal.zig` before the stream-to-terminal bridge starts applying actions.

## Upstream files

- `upstream/ghostty/src/terminal/Screen.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`

## MoonBit target files

- `src/terminal/terminal_protected_state.mbt`
- `src/terminal/terminal_display_state.mbt`
- `src/terminal/terminal_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plans/2026-04-20-p6-a-roadmap.md`
- `docs/plans/2026-04-20-p6-a3-protected-display-state.md`

## Dependency notes

- this slice reuses `ProtectedMode`, `StatusDisplay`, and `MouseShape` from the
  existing translated modules
- protected-mode history stays screen-scoped, while status display and mouse
  shape stay terminal-scoped as in upstream
- `P6.1` will embed these carriers into the bridge-facing terminal model

## Acceptance criteria

- screen protected-mode state exists with translated `setProtectedMode`
  semantics, including preserving the last non-off mode on `.off`
- terminal display state exists for status-display and mouse-shape tracking
- full-reset behavior resets status display to main without inventing a mouse
  reset that upstream does not do
- blackbox tests cover defaults, setters, protected-mode transitions, and
  display reset behavior

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/terminal_protected_state.mbt` is fully covered by blackbox tests
- `src/terminal/terminal_display_state.mbt` is fully covered by blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not change that code path

## Commit scope

- `feat(terminal)`

## Review findings

- protected-mode history and cursor protection are modeled together so the
  bridge can preserve the upstream `.off` behavior without exposing mutable
  internals
- display reset only resets `status_display`; mouse shape remains sticky to
  match upstream `fullReset`
- the new public surface is accessor- and method-based only

## Audit / result notes

- added `ScreenProtectedState` for screen-side protected mode bookkeeping
- added `TerminalDisplayState` for status-display and mouse-shape state
- added blackbox tests for protected-mode and display-state transitions
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
