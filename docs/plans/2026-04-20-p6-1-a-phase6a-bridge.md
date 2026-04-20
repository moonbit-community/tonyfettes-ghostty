# P6.1.A Phase-6A-Only State Bridge

## Goal

Land the first `stream_terminal.zig` bridge slice by applying only the stream
actions whose backing state was completed in Phase 6A.

## Upstream file

- `upstream/ghostty/src/terminal/stream_terminal.zig`

## MoonBit target files

- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/stream_terminal_bridge_test.mbt`
- `src/terminal/color.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p6-1-bridge-roadmap.md`
- `docs/plans/2026-04-20-p6-1-a-phase6a-bridge.md`

## Dependency notes

- `ScreenProtectedState`, `TerminalDisplayState`, and `TerminalColors` are the
  only translated state carriers this slice depends on
- query and effect callbacks remain outside this slice
- cursor, mode, tab, and screen mutations remain in later `P6.1` slices

## Acceptance criteria

- a bridge state exists for the Phase 6A terminal-owned and screen-owned state
- `StreamProtectedMode*`, `StreamActiveStatusDisplay`, `StreamMouseShape`, and
  `StreamColorOperation` are applied with upstream-equivalent state changes
- non-terminal dynamic color targets and special color targets stay no-op
- unsupported actions return `false` so later slices can extend the bridge
- blackbox tests cover protected-mode semantics, display updates, color set and
  reset behavior, reset-palette handling, and unsupported actions

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream_terminal_bridge.mbt` is fully covered by blackbox tests
- `src/terminal/color.mbt` retains full touched-line coverage after the private
  palette-change helper addition
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not change that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the bridge is explicit about partial coverage through `apply(...) -> Bool`
  instead of pretending to be the full terminal handler already
- `ResetPalette` now checks palette-change state before setting the dirty flag,
  matching the upstream intent more closely than an unconditional reset
- the bridge keeps the upstream ownership split between screen protected state
  and terminal display/color state

## Audit / result notes

- added `StreamTerminalBridgeState` as the first `stream_terminal.zig`-derived
  bridge carrier
- translated the Phase 6A-only action handling path from `stream_terminal.zig`
- added blackbox tests for the handled action subset and intentional no-op
  targets
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
