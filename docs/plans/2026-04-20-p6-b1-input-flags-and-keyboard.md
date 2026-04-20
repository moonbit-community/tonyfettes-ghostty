# P6.B1 Input Flags And Kitty Keyboard Stack

## Goal

Land the smallest independent `P6.B` slice by translating the terminal-owned
input flags and kitty keyboard stack state used by `stream_terminal.zig`.

## Upstream files

- `upstream/ghostty/src/terminal/Terminal.zig`
- `upstream/ghostty/src/terminal/kitty/key.zig`
- `upstream/ghostty/src/terminal/Screen.zig`

## MoonBit target files

- `src/terminal/terminal_input_state.mbt`
- `src/terminal/terminal_input_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p6-b-roadmap.md`
- `docs/plans/2026-04-20-p6-b1-input-flags-and-keyboard.md`

## Dependency notes

- reuses the already translated `ModifyKeyFormat` enum from `ansi.mbt`
- reuses `KittyKeyboardFlags` from the stream action surface instead of
  introducing a duplicate flag type
- intentionally avoids cursor position, saved cursor, margins, and tabstop
  layout so this slice can stay green on its own

## Acceptance criteria

- a terminal input-flags state exists for `mouse_shift_capture` and
  `modify_other_keys_2`
- applying `ModifyKeyFormat` mirrors the upstream behavior where only
  `OtherKeysNumeric` sets `modify_other_keys_2`
- a kitty keyboard state exists with current / set / or / not / push / pop
  behavior matching the upstream fixed stack semantics
- blackbox tests cover defaults, resets, flag toggles, stack order, wraparound,
  and oversized pop reset behavior

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/terminal_input_state.mbt` is fully covered by the added
  blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not touch that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the public API stays limited to opaque state carriers and bridge-facing
  methods; no public mutable fields were introduced
- reusing `KittyKeyboardFlags` from the stream layer avoids duplicate bit-flag
  definitions while keeping the state carrier faithful to the upstream action
  surface
- `mouse_shift_capture` remains tri-state through `Bool?`, matching the
  upstream `null/false/true` storage without exposing internal enum plumbing

## Audit / result notes

- added `TerminalInputFlags` for `mouse_shift_capture` and
  `modify_other_keys_2`
- added `KittyKeyboardState` with fixed-stack current / set / or / not /
  push / pop behavior
- added blackbox tests for defaults, full reset, modify-key-format handling,
  stack order, wraparound, and oversized-pop reset behavior
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
