# Phase 1.A ANSI, Charsets, and Modes

## Goal

Translate the foundational parser support files:

- `ansi.zig`
- `charsets.zig`
- `modes.zig`

This lane must stay green on its own and avoid dragging in Zig helper
machinery such as `lib.Enum`.

## Upstream files

- `upstream/ghostty/src/terminal/ansi.zig`
- `upstream/ghostty/src/terminal/charsets.zig`
- `upstream/ghostty/src/terminal/modes.zig`

## MoonBit target files

- `src/terminal/ansi.mbt`
- `src/terminal/charsets.mbt`
- `src/terminal/modes.mbt`
- `src/terminal/ansi_wbtest.mbt`
- `src/terminal/charsets_wbtest.mbt`
- `src/terminal/modes_wbtest.mbt`
- `docs/plans/2026-04-18-p1-a-ansi-charsets-modes.md`

## Dependencies and invariants

- Keep the lane self-contained inside `src/terminal`.
- Replace Zig helper generation (`lib.Enum`, comptime table generation) with
  direct MoonBit enums, records, and lookup helpers.
- Preserve the exact mode inventory, default-true modes, charset mappings, and
  DECRPM encoding behavior.
- Do not add parser, stream, or terminal-model files here.

## Acceptance criteria

- `ansi`, `charsets`, and `modes` public types exist with the expected
  parser-facing contracts.
- Charset tables preserve the upstream ASCII, British, and DEC special
  mappings.
- Mode lookup, mode state mutation, report lookup, and report encoding behave
  like upstream in the covered tests.
- `moon check`, `moon test`, `moon fmt`, and `moon info` pass.

## Validation commands

- `moon check`
- `moon test`
- `moon fmt`
- `moon info`

## Commit scope

- `feat(parser-foundation)`: add ansi, charset, and mode foundations

## Review findings

- Main-agent review: checked the MoonBit modules against the upstream Zig
  files and kept the lane scoped to `ansi`, `charsets`, and `modes` only.
- Local adaptations are limited to replacing Zig comptime/meta helpers with
  explicit MoonBit enums, records, and lookup functions.
- Reviewer subagent found three concrete issues before commit:
  - charset tables were exposed as mutable shared `FixedArray` values
  - mode storage and tag layout needed a closer packed representation story
  - transcription-heavy tests were too sparse
- Follow-up fixes landed in the same task:
  - `CharsetTable` now exposes `ReadOnlyArray[UInt16]`
  - `ModePacked` now stores a packed `UInt64` bitset and `ModeTag` has raw
    layout helpers
  - tests now cover all translated mode tags and the full DEC special mapping
- Final reviewer pass after the fixes found no remaining correctness issues in
  this lane. Residual risk is limited to future transcription drift.

## Audit/result notes

- Added `src/terminal/ansi.mbt` with direct enum/value translations for C0,
  rendition aspects, cursor styles, status-line/status-display modes, modify
  key format, and protected mode.
- Added `src/terminal/charsets.mbt` with ASCII, British, and DEC special
  charset tables using fixed arrays and direct codepoint mappings.
- Added `src/terminal/modes.mbt` with mode inventory, tag conversion, state
  packing, save/restore behavior, DECRPM report state, and report encoding.
- Added whitebox tests in `src/terminal/ansi_wbtest.mbt`,
  `src/terminal/charsets_wbtest.mbt`, and `src/terminal/modes_wbtest.mbt`.
- Validation:
  - `moon check` passed
  - `moon test` passed: 20 passed, 0 failed
  - `moon fmt` ran clean
  - `moon info` ran clean
- Current warnings are non-fatal unused-constructor / never-constructed
  warnings on newly translated foundation types that are not wired into the
  parser yet. They are expected at this phase boundary.
