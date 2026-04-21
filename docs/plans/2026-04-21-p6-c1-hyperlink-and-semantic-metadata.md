# P6.C1 Hyperlink And Semantic Metadata

## Goal

Translate the smallest screen-owned metadata carriers needed before page
 editing work: active cursor hyperlink state and semantic-prompt metadata.

## Upstream files

- `upstream/ghostty/src/terminal/Screen.zig`
- `upstream/ghostty/src/terminal/page.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`

## MoonBit target files

- `src/terminal/screen_hyperlink_state.mbt`
- `src/terminal/screen_hyperlink_state_test.mbt`
- `src/terminal/screen_semantic_state.mbt`
- `src/terminal/screen_semantic_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-21-p6-c-roadmap.md`
- `docs/plans/2026-04-21-p6-c1-hyperlink-and-semantic-metadata.md`

## Dependency notes

- this slice deliberately avoids any page allocator, row buffer, or cell
  backing storage
- hyperlink handling here is limited to the cursor-owned active hyperlink and
  implicit-id counter, not the page hyperlink map/set machinery
- semantic prompt handling here covers the cursor-owned semantic content and
  prompt metadata that later printing/newline logic will consume

## Acceptance criteria

- an opaque hyperlink carrier exists for active cursor hyperlink metadata
- an opaque semantic carrier exists for semantic prompt metadata
- blackbox tests cover defaults, explicit/implicit hyperlink behavior,
  semantic prompt click handling, prompt kind mapping, input/output state, and
  reset behavior
- public API review confirms there are no public mutable fields or raw storage
  leaks

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/screen_hyperlink_state.mbt` is fully covered by the added
  blackbox tests
- `src/terminal/screen_semantic_state.mbt` is fully covered by the added
  blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not touch that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the public surface is limited to two opaque state carriers plus small enums
  returned by their observation methods; there are no public mutable fields or
  raw storage leaks in `.mbti`
- semantic-prompt tests stay blackbox by parsing public OSC 133 sequences
  through `Stream` and asserting on `StreamSemanticPrompt`, rather than
  widening parser internals for test fixtures
- hyperlink state preserves the upstream explicit-vs-implicit id split and
  implicit counter semantics while keeping the MoonBit carrier abort-free

## Audit / result notes

- added `ScreenHyperlinkState` with active-uri tracking, explicit or implicit
  hyperlink identity, monotonically increasing implicit ids, and full-reset
  behavior that restores the counter to zero
- added `ScreenSemanticState` for semantic prompt metadata including
  `seen`, click mode, cursor semantic content, clear-to-EOL state, and row
  prompt markers derived from upstream prompt kinds
- added blackbox tests for explicit and implicit hyperlink behavior, semantic
  prompt click precedence, prompt kind mapping, input/output transitions, and
  reset behavior
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
