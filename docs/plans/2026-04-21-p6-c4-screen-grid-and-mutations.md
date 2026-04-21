# P6.C4 Screen Grid And Mutations

## Goal

Translate the remaining internal screen/page mutation model from
`Screen.zig` and `page.zig` into MoonBit so printable writes, erases,
insert/delete operations, scrolling, `DECALN`, and model-side full reset can
land in one green commit before `P6.1.C` wires those actions through the
bridge.

## Upstream files

- `upstream/ghostty/src/terminal/Screen.zig`
- `upstream/ghostty/src/terminal/page.zig`

## MoonBit target files

- `src/terminal/screen_grid_state.mbt`
- `src/terminal/screen_grid_state_wbtest.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-21-p6-c-roadmap.md`
- `docs/plans/2026-04-21-p6-c4-screen-grid-and-mutations.md`

## Dependency notes

- this slice consumes the value carriers from `P6.C1` through `P6.C3` and
  stays internal so the public API does not expose raw screen storage before
  a deliberate facade exists
- row storage is modeled as direct MoonBit arrays of `PageRowState` and
  `PageCellState`, with deep-copy helpers where reference semantics would
  otherwise alias shifted rows or reset snapshots
- the implementation keeps upstream behavior grouped together because printable
  writes, protected-cell erasure, wide-cell cleanup, and scroll-region shifts
  all mutate the same grid storage and are easier to audit in one file than
  across placeholder layers

## Acceptance criteria

- an internal screen grid carrier exists with safe row/cell access and clamped
  dimensions
- printable writes cover pending wrap, wraparound, wide-cell stamping,
  insert mode, row dirtying, row prompt markers, and hyperlink/style payloads
- erase, insert, delete, and scroll helpers preserve protected-cell and
  wide-cell invariants
- `DECALN` and full reset are modeled on the grid side and covered by tests
- whitebox tests fully cover the touched executable lines
- `moon info` confirms the new grid carrier and erase-mode enums remain
  internal

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/screen_grid_state.mbt` is fully covered by the added whitebox
  tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not modify that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the grid model stays package-internal; `moon info` no longer exposes
  `ScreenGridState`, `ScreenEraseLineMode`, or `ScreenEraseDisplayMode` in
  `pkg.generated.mbti`
- a whitebox test file is used intentionally here because this area is still
  internal model scaffolding rather than a reviewed public facade
- `full_reset` clears cell/row state and then restores row dirty flags to
  `false`, which matches the expected reset semantics exercised by the tests

## Audit / result notes

- added `ScreenGridState` with row storage, cell storage, safe indexing,
  printable writes, erase/insert/delete operations, scroll-region mutation,
  `DECALN`, and model-side full reset
- added helpers for row dirtying, prompt propagation, wide-cell boundary
  cleanup, row-flag recomputation, and row/cell deep-copy during shifts
- added whitebox tests covering zero-dimension clamping, narrow and wide
  printable writes, insert mode, protected erasure, scroll/shift helpers,
  row-flag recomputation, `DECALN`, and full reset
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
