# P6.A1 Style Core

## Goal

Land the first Phase 6A slice by introducing the terminal-side style value and
the SGR attribute application rules that `Screen.setAttribute` depends on.

## Upstream files

- `upstream/ghostty/src/terminal/style.zig`
- `upstream/ghostty/src/terminal/Screen.zig`

## MoonBit target files

- `src/terminal/terminal_style.mbt`
- `src/terminal/terminal_style_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p6-a-roadmap.md`
- `docs/plans/2026-04-20-p6-a1-style-core.md`

## Dependency notes

- this slice does not introduce the full terminal model yet
- palette mutation and OSC color-operation storage remain `P6.A2`
- protected-mode state remains `P6.A3`

## Acceptance criteria

- a terminal-side style value exists with:
  - foreground color
  - background color
  - underline color
  - SGR flag state
- SGR attribute application follows the translated `Screen.setAttribute`
  behavior for:
  - flag toggles and resets
  - fg/bg/underline color updates
  - whole-style reset
- blackbox tests cover default state, flag resets, color updates, and unset

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/terminal_style.mbt` is fully covered by blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not change that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the style and style-color types are opaque and accessor-based
- `StyleColor` now uses an opaque enum shape so the public interface does not
  leak an internal representation helper
- bright 8-color attributes reuse the translated palette codes instead of
  introducing a second bright-color encoding path
- this slice intentionally avoids terminal/page dependencies

## Audit / result notes

- added `CellStyle` as the terminal-side style carrier for Phase 6 state work
- translated the `Screen.setAttribute`-relevant SGR mutations for flags,
  underline state, and fg/bg/underline colors
- kept the public surface limited to opaque style values plus read accessors and
  the SGR application entrypoint
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
