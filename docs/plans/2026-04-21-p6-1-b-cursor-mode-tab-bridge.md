# P6.1.B Cursor, Mode, and Tab Bridge

## Goal

Translate the `stream_terminal.zig` bridge slice that applies cursor, mode,
charset, input, and tabstop actions against the Phase 6B state carriers
without pulling full screen-cell mutation or PTY effect handling into the same
commit.

## Upstream file

- `upstream/ghostty/src/terminal/stream_terminal.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`

## MoonBit target files

- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/stream_terminal_bridge_test.mbt`
- `src/terminal/terminal_protected_state.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p6-1-bridge-roadmap.md`
- `docs/plans/2026-04-21-p6-1-b-cursor-mode-tab-bridge.md`

## Dependency notes

- this slice consumes the state carriers completed in `P6.B1` through `P6.B4`
- it keeps the bridge pure and state-only: no PTY writes, bell/title effects,
  clipboard effects, or screen-cell mutations are introduced here
- reverse-wrap-specific `cursorLeft` behavior depends on screen row soft-wrap
  state that is not available until `P6.C`, so this slice intentionally keeps
  the non-wrap clamp behavior only and records the gap explicitly

## Acceptance criteria

- `StreamTerminalBridgeState` applies the state-backed `P6.1.B` action subset
- cursor movement, cursor positioning, cursor style, margins, tabs, mode
  toggles, charset updates, and kitty-keyboard/input metadata are all covered
  by blackbox tests
- unsupported actions still return `false`
- public API review confirms the bridge exposes only narrow state-observation
  getters instead of raw mutable internals

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream_terminal_bridge.mbt` is fully covered by the blackbox
  tests added in this slice
- `src/terminal/terminal_protected_state.mbt` is covered through the bridge
  save/restore path and its existing direct tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not modify that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the bridge surface stays method-based and observation-oriented: callers can
  ask for cursor, mode, charset, tabstop, color, and input state, but they do
  not receive raw mutable carrier structs
- `restore_cursor` now mirrors upstream save/restore semantics for cursor
  protection by restoring only the cursor-protected bit while preserving the
  remembered non-off protected mode
- the left/right-margin disable path preserves cursor position by resetting the
  region and then restoring the absolute cursor position, which matches the
  upstream `setMode(.enable_left_and_right_margin, false)` side effect closely
- reverse-wrap-specific `cursorLeft` behavior remains deferred until the screen
  model supplies row soft-wrap state

## Audit / result notes

- added the `P6.1.B` bridge logic for cursor movement/positioning, cursor
  style, charset save/restore, mode toggles, kitty keyboard state, input
  flags, tabs, and margin metadata
- added an internal `ScreenProtectedState::set_cursor_protected(...)` helper so
  restore-cursor can match upstream semantics without widening public API
- extended blackbox bridge tests to cover the handled action subset, edge-case
  clamping, saturation, save/restore behavior, and mode side effects
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
