# P6.C3 Page Row And Cell Values

## Goal

Translate the row and cell value carriers from `page.zig` into MoonBit so the
 next screen-mutation slice can operate on explicit row flags and cell
 markers without pulling in page allocation or edit loops yet.

## Upstream files

- `upstream/ghostty/src/terminal/page.zig`
- `upstream/ghostty/src/terminal/Screen.zig`

## MoonBit target files

- `src/terminal/page_state.mbt`
- `src/terminal/page_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-21-p6-c-roadmap.md`
- `docs/plans/2026-04-21-p6-c3-page-row-and-cell-values.md`

## Dependency notes

- this slice is value-only: it does not add page allocators, row arrays,
  edit loops, scroll-region logic, or style/hyperlink interning tables
- cell style is stored as a direct `CellStyle` value rather than upstream
  style ids so later mutation code can stay functional before page-level
  interning exists
- cell hyperlink state is stored as an explicit value snapshot rather than the
  upstream hyperlink-set/map indirection for the same reason
- row flags include `grapheme`, `styled`, `hyperlink`, and
  `kitty_virtual_placeholder` so later mutation logic has the same fast-path
  signals available even before page storage is implemented

## Acceptance criteria

- opaque row and cell carriers exist with the row flags and cell markers
  needed by later screen mutation work
- cell helpers cover content-tag semantics, grapheme detection, grid width,
  styling detection, and empty-cell behavior
- row helpers cover wrap flags, semantic prompt markers, dirty state, and
  managed-memory detection
- blackbox tests cover defaults, mutation helpers, defensive style copying,
  hyperlink snapshots, and full reset behavior
- public API review confirms there are no public mutable fields or storage
  leaks

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/page_state.mbt` is fully covered by the added blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not touch that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the public surface is limited to opaque row and cell carriers plus small
  enums and hyperlink snapshots; there are no public mutable fields in the
  generated interface
- `PageCellState::style()` returns a defensive copy so callers cannot mutate
  internal cell style through the public API
- storing direct `CellStyle` and `CellHyperlink` values is a deliberate
  adaptation from upstream ids/maps so `P6.C4` can land before page-level
  interning and allocation machinery exists

## Audit / result notes

- added `PageRowState` with wrap flags, semantic prompt marker, dirty bit,
  managed-memory helper, and auxiliary row flags from upstream `Row`
- added `PageCellState` with content tag helpers, background payload support,
  wide/spacer markers, protection flag, semantic content, hyperlink snapshot,
  style copy-in/copy-out, and full reset behavior
- added `CellHyperlink` explicit and implicit constructors so later screen
  mutation code can stamp hyperlink value snapshots onto cells
- added blackbox tests for row defaults and reset, codepoint and background
  cell behavior, grapheme/wide helpers, style copy isolation, hyperlink
  payloads, and cell reset behavior
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
