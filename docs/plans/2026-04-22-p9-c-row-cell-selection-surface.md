# P9.C Row/Cell/Selection Surface

## Goal

Close the row/cell/selection helper slice for the pure-MoonBit `src/terminal/c`
 translation by:

- auditing the existing row/cell owner surfaces against `row.zig` and
  `cell.zig`
- adding the missing selection carrier in a MoonBit-aligned form that can be
  instantiated with future grid references in `P11.B`

## Upstream files

- `upstream/ghostty/src/terminal/c/selection.zig`
- `upstream/ghostty/src/terminal/c/row.zig`
- `upstream/ghostty/src/terminal/c/cell.zig`
- `upstream/ghostty/src/terminal/Selection.zig`

## MoonBit target files

- `src/terminal/selection.mbt`
- `src/terminal/selection_test.mbt`
- `src/terminal/page_state.mbt`
- `src/terminal/page_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-22-p9-c-row-cell-selection-surface.md`

## Dependency notes

- `row.zig` and `cell.zig` are read-only projection wrappers over page state.
  The existing MoonBit owner module [page_state.mbt](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/src/terminal/page_state.mbt)
  already carries those semantics directly.
- `selection.zig` is only the data carrier form of a selection. The upstream
  C wrapper uses `CGridRef` because it must carry page pins through an FFI
  boundary; pure MoonBit does not need that ABI shape.
- `grid_ref.zig` is still planned for `P11.B`, so `P9.C` should land the
  selection shape without inventing a premature terminal-owned grid ref type.

## Acceptance criteria

- A public MoonBit selection carrier exists and preserves `start`, `end`, and
  `rectangle` semantics.
- The selection carrier stays representation-neutral so later work can use it
  with `GridRef` without changing the selection API shape.
- `row.zig` and `cell.zig` are explicitly audited against the existing
  `PageRowState` and `PageCellState` surfaces.
- Blackbox tests cover the new public selection behavior.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/selection.mbt` is fully covered by
  `src/terminal/selection_test.mbt`.
- `src/terminal/page_state.mbt` was not changed in this slice; its existing
  public row/cell coverage in `src/terminal/page_state_test.mbt` remains the
  supporting evidence for the `row.zig` / `cell.zig` audit.
- Pre-existing uncovered lines outside this slice remain in:
  - `src/terminal/stream.mbt:222`
  - documented invariant-only branches in `src/terminal/stream_terminal_bridge.mbt`
  - `tools/stream_terminal_perf/main.mbt`

## Commit scope

- `feat(c-surface-foundation): add row cell selection surface`

## Review findings

- `Selection[Ref]` is justified public surface because later terminal/grid
  query layers need to exchange selection ranges, and the upstream C helper is
  also a plain selection carrier.
- The selection type is intentionally generic rather than tied to `Point`:
  blackbox tests use `Point`, but the long-term consumer is `GridRef` in
  `P11.B`.
- No new row/cell wrapper module was added because the existing public owner
  types already expose the upstream semantics more directly than a C-keyed
  `get/get_multi` API would.
- `cell.zig`'s `style_id` is intentionally absorbed into
  `PageCellState::style()`. Our MoonBit model stores concrete style values, not
  style IDs, so exposing a synthetic numeric style handle here would be less
  faithful to the translated representation.

## Audit/result notes after implementation

- Added generic `Selection[Ref]` with `new`, `start`, `end`, and `rectangle`.
- Audited `row.zig` against the existing `PageRowState` API:
  - `wrap`
  - `wrap_continuation`
  - `grapheme`
  - `styled`
  - `hyperlink`
  - `semantic_prompt`
  - `kitty_virtual_placeholder`
  - `dirty`
- Audited `cell.zig` against the existing `PageCellState` API:
  - `codepoint`
  - `content_tag`
  - `wide`
  - `has_text`
  - `has_styling`
  - `hyperlink`
  - `protected`
  - `semantic_content`
  - background palette / RGB payloads
  - concrete style access via `style()`
