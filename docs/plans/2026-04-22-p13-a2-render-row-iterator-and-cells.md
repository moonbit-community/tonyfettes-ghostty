# P13.A2 Render Row Iterator and Cells

## Goal

Translate the row/cell slice of `src/terminal/c/render.zig` into a typed
MoonBit render-snapshot iterator surface on top of the `P13.A1` global owner.

## Upstream files

- `upstream/ghostty/src/terminal/c/render.zig`
- `upstream/ghostty/src/terminal/render.zig` row snapshot and partial-dirty
  logic

## MoonBit targets

- `src/terminal/render_state.mbt`
- `src/terminal/render_row_iterator.mbt`
- `src/terminal/render_row_iterator_test.mbt`
- `src/terminal/render_state_wbtest.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p13-a2-render-row-iterator-and-cells.md`

## Public surface

- `RenderRowIterator`
- `RenderRowCells`

The public owner API stays typed and MoonBit-owned:

- `RenderState::row_iterator()`
- `RenderRowIterator::{next, y, row, dirty, set_dirty, cells}`
- `RenderRowCells::{next, select, x, cell, background_color, foreground_color}`

The C wrapper's `RowData`, `RowCellsData`, `RowOption`, and `get_multi`
dispatch remain intentionally absorbed into typed methods.

## Fidelity notes

- `RenderState` now owns frozen viewport row/cell snapshots in addition to the
  global snapshot from `P13.A1`.
- Global render dirtiness still goes `Full` for screen, dimension, palette,
  cursor, or viewport-origin changes. When only row/cell snapshot content
  changes, `RenderState::update` now produces `Partial`.
- Row dirty bits are renderer-owned acknowledgement state, matching upstream:
  dirty rows are set to `true` on changed snapshots, and unchanged rows keep
  their prior render-side dirty value.
- Foreground/background access follows the upstream render wrapper semantics:
  explicit palette/RGB style colors resolve to `Some(RGB)`, color-only cells
  resolve background from the cell content tag, and missing colors stay `None`.
- Grapheme payload iteration is still limited by the current translated
  terminal model, which does not yet preserve extra grapheme codepoints beyond
  the primary codepoint in the public host surface.

## Validation

Ran:

- `moon check`
- `moon test src/terminal/render_row_iterator_test.mbt`
- `moon test src/terminal/render_state_wbtest.mbt`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage review

Touched-file coverage is complete for the public row/cell surface and all new
helper branches except three invariant-only internal fallbacks in
`render_state.mbt`:

- `src/terminal/render_state.mbt`
- `src/terminal/render_row_iterator.mbt`
- `src/terminal/render_row_iterator_test.mbt`
- `src/terminal/render_state_wbtest.mbt`

`moon coverage analyze` still reports:

- `src/terminal/render_state.mbt:295`
- `src/terminal/render_state.mbt:524`
- `src/terminal/render_state.mbt:536`

These are kept intentionally and documented here:

- `render_state.mbt:295` is the `grid_ref_cell(grid_ref) == None` fallback in
  `resolve_cursor_viewport`. In the translated host surface, a `GridRef`
  produced from the current active cursor point always resolves back to a cell
  in the same snapshot, so the branch is an internal safety fallback.
- `render_state.mbt:524` and `render_state.mbt:536` are the
  `default_background_color/default_foreground_color` fallback arms. The
  translated `StreamTerminal::{background_color,foreground_color}` getters
  already fold defaults into the current value, so those inner `Some(...)`
  branches are unreachable through the current host API even though they stay
  in place to mirror the upstream render helper structure.

Remaining uncovered lines outside this task stay tracked separately in earlier
audits.

## API review

Intentional new public surface:

- `RenderRowIterator`
- `RenderRowCells`

Kept out of the public API on purpose:

- enum-keyed row/cell dispatch tags
- C-style multi-get helpers
- direct access to internal row-id or viewport-origin tracking
- mutable aliases to terminal page storage

## Notes

- The render iterator surface reads only from `RenderState` snapshots; it does
  not query live terminal state after `RenderState::update`.
