# P6.B4 Tabstop State

## Goal

Translate the tabstop table state needed by `horizontalTab`, `horizontalTabBack`,
`tabClear`, `tabSet`, `tabReset`, and terminal full-reset flows without mixing
it into cursor geometry or screen-cell mutation work.

## Upstream files

- `upstream/ghostty/src/terminal/Tabstops.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`

## MoonBit target files

- `src/terminal/terminal_tabstops_state.mbt`
- `src/terminal/terminal_tabstops_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p6-b-roadmap.md`
- `docs/plans/2026-04-21-p6-b4-tabstop-state.md`

## Dependency notes

- this slice is limited to the tabstop table itself; cursor movement loops stay
  in later bridge work
- the upstream `Tabstops.zig` implementation uses a bitset; this translation
  keeps bitset semantics and the same `set` / `unset` / `get` / `reset`
  surface while dropping allocator-specific resize behavior that the current
  parser/bridge plan does not consume
- out-of-range accesses are adapted to safe no-ops / `false` results rather
  than debug assertions so the MoonBit carrier does not abort the process

## Acceptance criteria

- a tabstop carrier exists with default terminal interval initialization,
  explicit `set`, `unset`, `get`, and interval-based `reset`
- default reset behavior matches upstream terminal expectations on common widths
  including the eighty-column count and last-column exclusion
- zero-interval reset clears all tabstops
- out-of-range `get` / `set` / `unset` calls are safe and do not crash
- blackbox tests cover defaults, custom interval reset, clear-all reset,
  eighty-column count, and safe out-of-range behavior

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/terminal_tabstops_state.mbt` is fully covered by the added
  blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not touch that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the public API stays limited to one opaque state carrier with method-based
  access; no raw tabstop storage or mutable public fields leak into `.mbti`
- this slice keeps the upstream `set` / `unset` / `get` / `reset` surface and
  bitset-style storage, but deliberately drops allocator and resize concerns
  because the current parser bridge only consumes fixed-width terminal state
- out-of-range access is handled as a safe no-op / `false` read instead of a
  debug assertion so the MoonBit translation does not abort the process

## Audit / result notes

- added `TerminalTabstopsState` with default eight-column initialization and
  explicit `set`, `unset`, `get`, and interval-based `reset`
- preserved the upstream reset rule that excludes the last column from default
  and custom interval placement
- added blackbox tests for default interval setup, explicit set/unset, zero
  reset, custom interval reset, the eighty-column default count, and safe
  zero/out-of-range access
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
