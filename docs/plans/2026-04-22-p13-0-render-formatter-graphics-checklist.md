# P13.0 Render, Formatter, and Graphics Checklist

## Goal

Record the exact Phase 13 ownership split for the upstream render, formatter,
and kitty-graphics wrappers so implementation can stay faithful to
`src/terminal/c/*.zig` without forcing oversized mixed-surface commits.

## Upstream files

- `upstream/ghostty/src/terminal/c/render.zig`
- `upstream/ghostty/src/terminal/c/formatter.zig`
- `upstream/ghostty/src/terminal/c/kitty_graphics.zig`
- remaining graphics-only fields deferred from
  `upstream/ghostty/src/terminal/c/terminal.zig`

## MoonBit targets

Docs in this task:

- `docs/plan.md`
- `docs/plans/2026-04-22-p13-0-render-formatter-graphics-checklist.md`

Planned implementation targets:

- `src/terminal/render_state.mbt`
- `src/terminal/render_state_test.mbt`
- `src/terminal/render_row_iterator.mbt`
- `src/terminal/render_row_iterator_test.mbt`
- `src/terminal/formatter.mbt`
- `src/terminal/formatter_test.mbt`
- one internal kitty-graphics model/storage surface inside `src/terminal`
- one public kitty-graphics owner surface inside `src/terminal`
- `src/terminal/stream_terminal.mbt` for the remaining graphics-dependent
  terminal queries

## Current translated boundary

- `StreamTerminal` already owns the persistent terminal host object.
- `GridRef` and `Selection[Ref]` already exist and cover the non-render
  terminal pin/query boundary.
- page/row/cell/style/hyperlink snapshots already exist through the translated
  terminal model and `GridRef` helpers.
- APC parsing only carries a lightweight kitty-graphics command placeholder;
  there is no translated image storage, placement model, or render-facing
  graphics state yet.
- `BuildInfo::kitty_graphics()` currently reports `false`, which accurately
  reflects the current translated surface and must not silently drift.

## MoonBit alignment rules for Phase 13

- Do not mirror `Data`, `RowData`, `RowCellsData`, `SetOption`, or
  `get_multi` as public enums just because the C wrapper needed ABI-stable
  dispatch tags.
- Keep public owner surfaces typed and opaque:
  - a render-state owner
  - row/cell iterators or snapshot accessors
  - a formatter owner
  - a kitty-graphics owner
- Preserve explicit invalid/no-value behavior where it affects host semantics,
  but express it through typed results and `Option` rather than output-pointer
  dispatch.
- Keep palette/style/cursor resolution in the render owner, not in ad hoc
  terminal helper methods.
- Formatter output should stay byte-precise and owned by MoonBit. Default to
  `Bytes` rather than recreating the upstream out-buffer API.
- Do not start public kitty-graphics API work until the internal image and
  placement model exists. The current tree only has parser-side recognition,
  not the storage/query substrate the wrapper expects.

## Phase 13 implementation split

### P13.A1 render snapshot owner surface

Scope:

- render-state lifecycle and update from terminal state
- global snapshot getters for:
  - cols and rows
  - dirty-state aggregate
  - resolved colors
  - cursor visual state

Required invariants:

- render snapshots must be owned by the render surface, not by transient
  aliases into terminal state
- dirty-state mutation must stay explicit and typed
- cursor color and visibility semantics must preserve upstream no-value cases

Recommended public shape:

- opaque `RenderState`
- typed getters and setters for global render state only

### P13.A2 render row iteration and row-cell surface

Scope:

- row iteration
- row dirty query/mutation
- row-cell iteration and selection
- resolved foreground/background color access for row cells

Required invariants:

- row and cell snapshots must not expose mutable aliases to terminal/page
  storage
- palette-based color resolution belongs here, matching upstream render
  behavior rather than leaking palette lookup to callers
- this slice starts only after `P13.A1` lands the render owner and global
  snapshot state

Dependency note:

- `P13.A2` depends on `P13.A1`

### P13.B formatter surface

Scope:

- formatter owner lifecycle
- terminal formatting in plain, VT, and HTML modes
- selection-restricted formatting
- exact-size reporting for too-small outputs, adapted to MoonBit-owned buffers

Required invariants:

- formatting must preserve the upstream selection and extra-field semantics
- output sizing behavior must remain reviewable even though MoonBit owns the
  returned buffer
- formatter work should depend on existing `GridRef` and `Selection` surfaces,
  not reintroduce C-style query glue

Recommended public shape:

- opaque formatter owner
- `format() -> Bytes`
- `format_into(Buffer)` only if a real caller needs streaming writes later

### P13.C1 kitty graphics model substrate

Scope:

- translate the internal image/placement model needed by
  `src/terminal/c/kitty_graphics.zig`
- image metadata, stored payload bytes, placement records, and layer filtering
- bridge/application hooks needed so parser-recognized kitty-graphics commands
  can affect model state

Required invariants:

- do not freeze a public graphics API before the internal storage model exists
- image and placement snapshots must stay terminal-owned and queryable without
  exposing mutable internal maps
- when this slice lands, re-evaluate `BuildInfo::kitty_graphics()` and update
  it if the translated surface is now materially present

### P13.C2 kitty graphics host surface

Scope:

- public kitty-graphics owner/query surface
- image lookups
- placement iterator
- placement geometry helpers:
  - rect
  - pixel size
  - grid size
  - viewport position
  - source rect
  - render info
- remaining graphics-dependent `StreamTerminal` query fields

Required invariants:

- `P13.C2` starts only after `P13.C1`
- graphics-only terminal getters should close here, not leak back into Phase
  11 query work
- null/missing-image/missing-placement cases must preserve upstream invalid or
  no-value behavior

## Upstream validation corpus split

### P13.A1 tests from `render.zig`

- `render: new/free`
- `render: free null`
- `render: update invalid value`
- `render: get invalid value`
- `render: get invalid data`
- `render: colors get invalid value`
- `render: get/set dirty invalid value`
- `render: get/set dirty`
- `render: set null value`
- `render: update`
- `render: colors get`
- `render: colors get supports truncated sized struct`

### P13.A2 tests from `render.zig`

- `render: row iterator get invalid value`
- `render: row iterator new/free`
- `render: row iterator free null`
- `render: row iterator next null`
- `render: row get null`
- `render: row get invalid data`
- `render: row set null`
- `render: row set before iteration`
- `render: row get before iteration`
- `render: row get/set dirty`
- `render: row iterator next`
- `render: row cells bg_color no background`
- `render: row cells bg_color from style`
- `render: row cells bg_color from content tag`
- `render: row cells fg_color no foreground`
- `render: row cells fg_color from style`
- `render: row_get_multi success`
- `render: row_get_multi null returns invalid_value`
- `render: row_cells_get_multi success`
- `render: row_cells_get_multi null returns invalid_value`
- `render: get_multi success`
- `render: get_multi null returns invalid_value`

### P13.B tests from `formatter.zig`

- `terminal_new/free`
- `terminal_new invalid_value on null terminal`
- `free null`
- `format plain`
- `format reflects terminal changes`
- `format null returns required size`
- `format buffer too small`
- `format null formatter`
- `format vt`
- `format plain with selection`
- `format html`

### P13.C1 and P13.C2 tests from `kitty_graphics.zig`

Model-first cases for `P13.C1`:

- transmitted image capture
- image lookup by id
- multiple placement storage
- layer-filter bookkeeping

Host-surface cases for `P13.C2`:

- `placement_iterator new/free`
- `placement_iterator free null`
- `placement_iterator next on empty storage`
- `placement_iterator get before next returns invalid`
- `placement_iterator with transmit and display`
- `placement_iterator with multiple placements`
- `placement_iterator_set layer filter`
- `image_get_handle returns null for missing id`
- `image_get_handle and image_get with transmitted image`
- `placement_rect with transmit and display`
- `placement_rect null args return invalid_value`
- `placement_pixel_size with transmit and display`
- `placement_pixel_size null args return invalid_value`
- `placement_grid_size with transmit and display`
- `placement_grid_size null args return invalid_value`
- `placement_viewport_pos with transmit and display`
- `placement_viewport_pos fully off-screen above`
- `placement_viewport_pos top off-screen`
- `placement_viewport_pos bottom off-screen`
- `placement_viewport_pos top and bottom off-screen`
- `placement_viewport_pos null args return invalid_value`
- `placement_source_rect defaults to full image`
- `placement_source_rect with explicit source rect`
- `placement_source_rect clamps to image bounds`
- `placement_source_rect null args return invalid_value`
- `image_get on null returns invalid_value`
- `placement_render_info returns all fields`
- `placement_render_info off-screen sets viewport_visible false`
- `placement_render_info null returns invalid_value`
- `image_get_multi success`
- `image_get_multi error sets out_written`
- `image_get_multi null keys returns invalid_value`
- `placement_get_multi success`
- `placement_get_multi error sets out_written`
- `placement_get_multi null keys returns invalid_value`

## Acceptance criteria

- The Phase 13 write split is explicit and small enough for green atomic
  commits.
- Render, formatter, and graphics work each have a stable owner boundary
  before implementation starts.
- The existing kitty-graphics substrate gap is documented rather than hidden
  inside a wrapper-shaped task.
- Phase ordering is dependency-correct for later implementation tasks.

## Validation

- docs review only

## Audit/result notes

- The old `P13.A` mixed render global state with row iteration and row-cell
  mutation. That is one upstream file, but it is not one reviewable MoonBit
  step.
- `formatter.zig` is a coherent owner surface and can remain one task.
- `kitty_graphics.zig` cannot honestly start as a public wrapper translation:
  the current tree still lacks the internal image and placement substrate it
  expects. Splitting `P13.C` into substrate then host-surface work keeps the
  phase honest.
