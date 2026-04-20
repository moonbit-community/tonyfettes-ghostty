# P6.A2 Dynamic Palette And Terminal Colors

## Goal

Translate the dynamic terminal color state from `terminal/color.zig` so the
future terminal model can apply OSC-driven color updates without inventing a
second representation.

## Upstream files

- `upstream/ghostty/src/terminal/color.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`

## MoonBit target files

- `src/terminal/color.mbt`
- `src/terminal/color_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plans/2026-04-20-p6-a-roadmap.md`
- `docs/plans/2026-04-20-p6-a2-dynamic-colors.md`

## Dependency notes

- this slice reuses the existing translated `RGB` model from `color.mbt`
- `P6.A1` style values keep storing palette indexes; they do not resolve colors
  directly here
- protected mode, status display, and mouse-shape state remain `P6.A3`

## Acceptance criteria

- the default 256-color palette is available from translated terminal color
  data
- dynamic rgb state supports unset, set, and reset semantics
- dynamic palette state supports set, reset, reset-all, and default-palette
  replacement while preserving overrides
- terminal-owned background, foreground, cursor, and palette wrappers exist
- blackbox tests cover the translated state transitions and representative
  palette entries

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/color.mbt` is fully covered by blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not change that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the first implementation aliased current and original palette storage; the
  final version clones palette arrays so reset and default-change semantics now
  match upstream behavior
- `default_palette()` is public to keep blackbox tests and future terminal
  configuration code on the same public path
- terminal colors stay wrapper-based and do not expose public mutable fields

## Audit / result notes

- added generated default 256-color palette data to `color.mbt`
- translated `DynamicRGB`, `DynamicPalette`, and `TerminalColors`
- added blackbox coverage for palette layout, dynamic rgb state, dynamic
  palette mutation/reset/default-change, and terminal color wrapper behavior
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
