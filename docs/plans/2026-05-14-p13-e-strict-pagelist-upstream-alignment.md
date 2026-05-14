# P13.E Strict PageList Upstream Alignment

## Goal

Replace the current MoonBit PageList resize work with a strict translation of
upstream Ghostty's PageList/pin/reflow cursor model.

This is not another local repair pass over the existing row-id/flatten model.
The implementation must first align the internal model with upstream Zig, and
must not reintroduce row-id compatibility unless a concrete downstream consumer
requires it.

## Current Problem

Current checkpoint:

- `08188859 refactor(terminal): checkpoint page list pin resize work`

The checkpoint still uses a local model:

- `PageListRow.row_id`
- `visible_row_ids`
- `flatten_rows`
- `reflow_rows`
- `rebuild_from_rows`
- `renumber_rows_in_display_order`
- row-id backed `PageListTrackedPin`
- local viewport pin over row IDs
- local kitty placement pin IDs

That model is not upstream PageList. It keeps the existing array-backed row-id
translation and adds pin-like APIs on top. The result fixes some symptoms but
does not match upstream's data contracts.

## Hard Rule

Do not add invented PageList concepts during this task.

Disallowed unless explicitly approved in this document before implementation:

- `absolute_row`
- `source_row`
- `row_id_at_absolute`
- `wrapped_rows_for_pin`
- `trim_leading_blank_pinned_rows`
- any new resize helper that has no direct upstream source section

The previous `GridRef.row_id` adapter is explicitly out of scope for the
remaining implementation. `GridRef`, row-id lookup helpers, and incremental
scrollback row-id watermarks must be removed instead of kept as compatibility.

## Source Of Truth

Use these upstream files as the implementation source:

- `upstream/ghostty/src/terminal/PageList.zig`
  - `PageList`
  - `Viewport`
  - `Pin`
  - `trackPin`
  - `untrackPin`
  - `pointFromPin`
  - `resize`
  - `resizeCols`
  - `resizeWithoutReflow`
  - `resizeWithoutReflowGrowCols`
  - `trimTrailingBlankRows`
  - `ReflowCursor`
  - `fixupViewport`
- `upstream/ghostty/src/terminal/Screen.zig`
  - resize cursor handling
  - saved cursor handling
- `upstream/ghostty/src/terminal/kitty/graphics_storage.zig`
  - placement `.pin`
  - placement deinit untracking

## MoonBit Target Files

Primary implementation targets:

- `src/terminal/terminal_screen_state.mbt`
- `src/terminal/terminal_saved_cursor_state.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/kitty_graphics_state.mbt`
- `src/terminal/kitty_graphics.mbt`

Tests and generated API:

- `src/terminal/stream_terminal_resize_wbtest.mbt`
- `src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `src/terminal/terminal_screen_state_wbtest.mbt`
- `src/terminal/kitty_graphics_test.mbt`
- `src/terminal/pkg.generated.mbti`

Workflow/docs:

- `docs/plan.md`
- `docs/plans/2026-05-14-p13-e-strict-pagelist-upstream-alignment.md`

## Required Structural Mapping

### PageList

MoonBit must represent the same internal responsibilities as upstream:

- page list storage
- active row count
- column count
- tracked pins
- viewport state
- viewport pin
- optional viewport pin row offset cache if needed

If MoonBit cannot immediately introduce linked pages, the task must stop and
record the exact blocker. Continuing with `flatten_rows`/`rebuild_from_rows`
without approval is out of scope.

Approved translation boundary:

- `ScreenGridState` currently owns the active rows and cells while `PageList`
  owns scrollback metadata. This cannot represent upstream `Pin.node`, because
  upstream pins point to concrete rows inside PageList storage.
- For this task, PageList becomes the owner of the active rows and cells. The
  existing `ScreenGridState` surface must be reduced to a compatibility view or
  mutation facade over PageList-owned storage.
- This is an approved structural translation of upstream PageList page/node
  ownership. It is not approval to introduce row-index based pin models such as
  `absolute_row` or `source_row`.
- Implementation must preserve the upstream naming and behavior of `Pin`,
  `trackPin`, `untrackPin`, `pointFromPin`, `Viewport`, and `ReflowCursor`
  wherever MoonBit syntax permits.

### Pin

MoonBit needs an internal `Pin` equivalent with the same meaning as upstream:

- points to a concrete row inside PageList storage
- has `y`
- has `x`
- has `garbage`

The pin must not be backed by `GridRef.row_id`.

Tracked pins must be updated at every mutating PageList operation where
upstream updates `tracked_pins`.

### Viewport

MoonBit must mirror upstream `Viewport`:

- `active`
- `top`
- `pin`

The current mixed `viewport_offset` plus local `viewport_pin` model must be
removed or reduced to a public/query cache behind the upstream-equivalent
viewport state.

### Resize

MoonBit resize dispatch must follow upstream order:

- no reflow: `resizeWithoutReflow`
- same columns: `resizeWithoutReflow`
- grow columns: `resizeCols`, then `resizeWithoutReflow`
- shrink columns: `resizeWithoutReflow` with old columns, then `resizeCols`

Do not implement resize by flattening all rows into an array, reflowing them,
then rebuilding history and active grid.

### ReflowCursor

MoonBit must translate upstream `ReflowCursor` as a first-class internal state
machine:

- `x`
- `y`
- `pending_wrap`
- current destination page/row/cell equivalent
- deferred blank row count
- total row count

The implementation must preserve upstream behavior in:

- deferred blank rows
- tracked pin movement when a source cell is written
- tracked pin movement when a wide cell skips the next source cell
- spacer head behavior
- 1-column wide character behavior
- row metadata copy
- prompt continuation update
- grow/new-page behavior or the exact MoonBit equivalent approved in advance

### Preserved Cursor

Translate upstream `resizeCols` preserved cursor logic directly:

- tracked pin for cursor
- `remaining_rows`
- `wrapped_rows`
- post-reflow active point lookup through `pointFromPin`
- subtract newly introduced wraps before growing active rows

Do not introduce a standalone helper named `wrapped_rows_for_pin` unless it is
documented as a direct translation of the local `wrapped` block in
`PageList.zig::resizeCols`.

### Saved Cursor

Saved cursor ownership must follow upstream screen ownership semantics.

For `?1049h`, the saved cursor belongs to primary before the screen switches to
alternate. A resize while alternate is active must not remap that saved primary
cursor through alternate contents.

### Kitty Graphics Placement

Kitty placements that are grid-backed must own tracked PageList pins like
upstream `.pin: *PageList.Pin`.

Untracking must happen at placement removal/deinit boundaries, not through
ad-hoc bridge-level cleanup that can miss ownership paths.

## Public Compatibility Boundary

MoonBit currently exposes `GridRef` with a `row_id`. That surface can remain
only as a compatibility boundary.

Rules:

- `GridRef.row_id` may be produced from internal pins for public callers.
- `GridRef.row_id` may be resolved for public lookup.
- `GridRef.row_id` must not drive internal resize, reflow, cursor, viewport, or
  kitty placement tracking.
- If existing public APIs require row IDs to survive across resize, the plan
  must be updated with an explicit compatibility design before code changes.

## RED Checks

Before implementation, run or add focused tests that fail against the current
checkpoint:

- row shrink keeps tracked cursor row visible
- narrow reflow keeps incremental scrollback watermark monotonic
- blank trailing cursor row survives column resize
- alternate-screen resize preserves the `?1049h` saved primary cursor
- upstream wrapped-cursor cases:
  - cursor in wrapped row after growing columns
  - cursor in non-wrapped row after growing columns
  - cursor in wrapped row that does not fully unwrap
- kitty placement survives resize through a tracked placement pin or is removed
  by the same ownership rule as upstream

## Implementation Phases

### Phase 0: Restore Canonical Workflow

1. Treat `~/Workspace/moonbit/feihaoxiang/ghostty` as canonical.
2. Sync docs/workflow files from canonical into `./vendor/ghostty`.
3. Apply the implementation in canonical first.
4. Validate in canonical.
5. Sync canonical `src/terminal`, tests, docs, and generated interface back to
   `./vendor/ghostty`.
6. Verify `diff -qr vendor/ghostty ~/Workspace/moonbit/feihaoxiang/ghostty`
   excluding `.git`, `.mooncakes`, `_build`, `.envrc`, and `upstream`.

### Phase 1: Remove The Local Resize Model

Remove or replace:

- `flatten_rows`
- `reflow_rows`
- `rebuild_from_rows`
- `renumber_rows_in_display_order`
- row-id backed tracked pins
- local viewport pin over row IDs
- local kitty pin IDs

Keep row-id helpers only if they are required by public `GridRef` compatibility.

### Phase 2: Port PageList Storage And Pins

Introduce the MoonBit equivalent of upstream:

- internal page/list nodes or an explicitly approved equivalent
- `Pin`
- tracked pin set/list
- `trackPin`
- `untrackPin`
- `pointFromPin`
- pin validity and garbage semantics

### Phase 3: Port Resize Without Reflow

Translate:

- `resizeWithoutReflow`
- `resizeWithoutReflowGrowCols`
- `trimTrailingBlankRows`

Pin updates must follow upstream update points.

### Phase 4: Port Reflow Cursor

Translate:

- `resizeCols`
- `ReflowCursor`
- `writeCell`
- cursor movement helpers
- row metadata copying
- tracked pin remapping during write/skip/move

### Phase 5: Port Viewport Fixup

Translate:

- `Viewport`
- viewport pin behavior
- `fixupViewport`
- scroll-to-active/top/pin behavior

### Phase 6: Port Saved Cursor And Kitty Ownership

Translate:

- saved cursor screen ownership
- kitty placement pin ownership
- placement removal untracking

### Phase 7: Remove Row-ID Compatibility

Remove the MoonBit-only row-id compatibility surface:

- `GridRef`
- `StreamTerminal::grid_ref`
- `StreamTerminal::point_from_grid_ref`
- row-id-backed `grid_ref_*` lookup helpers
- `StreamTerminal::format_scrollback_rows_since`
- `PageListCompatRows`

Formatter and kitty placement rectangle APIs must use screen coordinates or
pin-derived coordinates directly. Review `pkg.generated.mbti` and keep new
public surface out of the package unless there is an explicit external
consumer.

## Validation Commands

Run in canonical first:

- `moon check`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt`
- `moon test src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `moon test src/terminal/terminal_screen_state_wbtest.mbt`
- `moon test src/terminal/kitty_graphics_test.mbt`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

Then run the same focused checks in `./vendor/ghostty` after sync.

## Commit Plan

Use separate conventional commits:

1. `docs(terminal): plan strict pagelist upstream alignment`
2. `refactor(terminal): port pagelist pin storage`
3. `refactor(terminal): port pagelist resize without reflow`
4. `refactor(terminal): port pagelist reflow cursor`
5. `refactor(terminal): port pagelist viewport state`
6. `fix(terminal): align saved cursor and kitty placement pins`
7. `test(terminal): cover upstream pagelist resize regressions`

Each implementation commit must include tests and validation for that completed
step. Do not leave a red intermediate commit.

## Progress Log

### 2026-05-14: PageList Storage/Pin Checkpoint

Implemented in canonical first:

- Added upstream-shaped `PageListPage`, `PageListNode`, and `PageListPin`.
- Moved tracked pins from row-id backing to `node/y/x/garbage`.
- Made `TerminalScreenStorage::new` create the active `ScreenGridState` as a
  view over PageList-owned active storage.
- Rebuilt `track_pin`, `untrack_pin`, `point_from_pin`, `grid_ref_from_pin`,
  and `pin_x` on top of internal pins.
- Moved resize cursor/saved-cursor pins and kitty placement pins through
  node/y identity instead of row IDs.
- Removed the disallowed local helpers/symbols from implementation:
  `trim_leading_blank_pinned_rows`, `row_id_at_absolute`,
  `absolute_index_of_row_id`, `PageListTrackedPin`, `track_pin_at_row_id`,
  `source_row`, and `absolute_row`.

Not complete yet:

- `flatten_rows`, `reflow_rows`, and `rebuild_from_rows` still exist as the
  remaining local resize path. Phase 1 is therefore not complete.
- `resizeWithoutReflow`, `resizeCols`, `ReflowCursor`, `Viewport`, saved cursor
  screen ownership, and kitty placement ownership still need to be ported in
  the later phases below.

Validation run in canonical:

- `moon check`
- `moon test src/terminal/terminal_screen_state_wbtest.mbt`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt`
- `moon test src/terminal/formatter_wbtest.mbt`
- `moon test src/terminal/kitty_graphics_wbtest.mbt`
- `moon test src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `moon test src/terminal`

Result: all checks passed. `moon check` still reports warnings for upstream
shape fields that are introduced before their later-phase use
(`PageListNode.prev`, `PageListNode.next`, `PageList.cols`,
`PageList.first`, `PageList.last`).

### 2026-05-14: Resize Without Reflow Row-Count Checkpoint

Implemented in canonical first:

- Added `PageList::resize_without_reflow` for the same-column/no-reflow resize
  path.
- Added `PageList::trim_trailing_blank_rows`, mirroring upstream
  `trimTrailingBlankRows`: it trims trailing active rows with no text and stops
  at tracked pins.
- Same-column row shrink no longer goes through `flatten_rows` and
  `rebuild_from_rows`.
- Same-column row grow now mirrors upstream active-area behavior:
  - if the cursor is at the bottom, resize pulls available scrollback rows into
    the active area;
  - if the cursor is above the bottom, resize grows the active area without
    pulling down scrollback.
- Added focused tests for both row-grow branches.

Not complete yet:

- Column resize still uses the existing `reflow_rows`/`rebuild_from_rows` path
  until Phase 4 ports `resizeCols` and `ReflowCursor`.
- The PageList node/page fields introduced for upstream shape still become
  fully used in later phases.

Validation run in canonical:

- `moon check`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt`
- `moon test src/terminal/terminal_screen_state_wbtest.mbt`
- `moon test src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `moon test src/terminal/formatter_wbtest.mbt`
- `moon test src/terminal`

Result: all checks passed.

### 2026-05-14: Reflow Cursor Checkpoint

Implemented in canonical first:

- Replaced the column-resize dispatch with upstream ordering from
  `PageList.zig::resize`:
  - same columns use `resize_without_reflow`;
  - growing columns runs `resize_cols` before row resize;
  - shrinking columns runs row resize before `resize_cols`.
- Added `PageList::resize_cols` backed by a `PageListReflowCursor`
  translation of upstream `ReflowCursor`.
- Ported the reflow cursor behaviors that move pins while cells are rewritten:
  pending wrap handling, spacer-head retry for wide cells at the right edge,
  one-column wide-cell skip-next handling, deferred blank rows, semantic prompt
  metadata copying, and total row padding.
- Added preserved-cursor accounting for active row selection during column
  reflow.
- Removed the remaining local column-reflow path and its helpers:
  `PageListReflowCell`, `flatten_rows`, `reflow_rows`, `emit_reflow_line`,
  `rebuild_from_rows`, `active_start_for_resize`,
  `trim_trailing_blank_pinned_rows`, `renumber_rows_in_display_order`, and
  `reflow_content_len`.
- Made `PageListRow.row_id` immutable after removing the old renumbering path.

Not complete yet:

- The remaining phases still need to finish saved-cursor screen ownership,
  kitty placement pin ownership, viewport alignment, and additional upstream
  regression coverage.

Validation run in canonical:

- `moon check`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt`
- `moon test src/terminal/terminal_screen_state_wbtest.mbt`
- `moon test src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `moon test src/terminal/formatter_wbtest.mbt`
- `moon test src/terminal`
- `moon fmt`
- `moon info`
- `rg -n "\\b(flatten_rows|reflow_rows|rebuild_from_rows|emit_reflow_line|PageListReflowCell|trim_leading_blank_pinned_rows|trim_trailing_blank_pinned_rows|wrapped_rows_for_pin|row_id_at_absolute|absolute_index_of_row_id|renumber_rows_in_display_order|reflow_content_len|PageListTrackedPin|track_pin_at_row_id|mark_pins_for_row_id_garbage|update_pins_for_row_id)\\b|\\bsource_row\\b|\\babsolute_row\\b" src/terminal`

Result: all checks passed. The strict forbidden-symbol grep returned no
matches. `moon info` did not change generated interfaces.

### 2026-05-14: Viewport And Kitty Ownership Checkpoint

Implemented in canonical first:

- Ported upstream-shaped viewport state with `Active`, `Top`, and `Pin`.
- Made the viewport pin permanent and used `PageList::pin_row_offset` to
  derive top offsets by walking `PageListNode.prev` / `PageListNode.next`
  through `first` and `last`.
- Added `PageList::relink_nodes` so history rows, the active node, and
  viewport offset calculation share the same linked-node ordering.
- Added a RED viewport test covering `scroll_top` surviving future scrollback
  capture, then kept it green under the linked-node viewport implementation.
- Verified upstream Ghostty's `?1049h` saved-primary-cursor behavior with a
  temporary Zig test and updated the MoonBit expectation to match upstream:
  after alternate-screen column shrink in that blank-row case, the restored
  primary x coordinate is `1`.
- Moved Kitty graphics placement pin untracking to placement removal
  ownership:
  - `KittyGraphicsPlacement::deinit` untracks grid-backed placement pins.
  - `KittyGraphicsState::add_placement` deinitializes replaced external
    placements.
  - `delete_all`, `delete_by_id`, `delete_newest`, and `full_reset` now
    deinitialize placements instead of relying on bridge-side pre-scans.
  - `StreamTerminalBridgeState` no longer contains separate
    `untrack_kitty_*` helpers.

Not complete yet:

- `PageListRow.row_id`, `PageList.history`, and `PageList.visible_row_ids`
  still exist as compatibility/internal indexing surfaces. They must be
  isolated behind Phase 7 public `GridRef` compatibility before this plan can
  be called fully upstream-aligned.

Validation run in canonical:

- `moon check`
- `moon test src/terminal/kitty_graphics_state_wbtest.mbt`
- `moon test src/terminal/kitty_graphics_test.mbt`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt`
- `moon test src/terminal/terminal_screen_state_wbtest.mbt`

Result: all checks passed. Existing warnings remain the deprecated `assert_eq`
test warnings and the current `PageList.cols` unused-field warning.

### 2026-05-14: Public Compatibility Boundary Checkpoint

Implemented in canonical first:

- Removed `row_id` from `PageListRow`; row snapshots and reflow rows now carry
  only row state, cells, node, and row offset.
- Removed `PageList.visible_row_ids` and moved public row-id compatibility into
  a named `PageListCompatRows` adapter.
- Kept row IDs only at the public compatibility boundary:
  - `GridRef.row_id` production and lookup;
  - `point_from_row_id`, `row_by_id`, and `cell_by_id`;
  - `format_scrollback_rows_since` incremental history watermarks.
- Reflow now assigns fresh compatibility row IDs in display order after
  `PageListReflowCursor` finishes. This keeps the incremental scrollback
  watermark monotonic without making row IDs part of cursor, saved cursor,
  viewport, or kitty placement tracking.
- Updated the white-box impossible-state kitty test to manipulate the named
  compatibility adapter instead of the removed `visible_row_ids` field.

Validation run in canonical:

- `moon check`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt`
- `moon test src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `moon test src/terminal/formatter_wbtest.mbt`
- `moon test src/terminal/terminal_screen_state_wbtest.mbt`
- `moon test src/terminal/kitty_graphics_wbtest.mbt`
- `moon test src/terminal`
- `moon test`
- `moon coverage analyze`
- `rg -n "\\b(flatten_rows|reflow_rows|rebuild_from_rows|emit_reflow_line|PageListReflowCell|trim_leading_blank_pinned_rows|trim_trailing_blank_pinned_rows|wrapped_rows_for_pin|row_id_at_absolute|absolute_index_of_row_id|renumber_rows_in_display_order|reflow_content_len|PageListTrackedPin|track_pin_at_row_id|mark_pins_for_row_id_garbage|update_pins_for_row_id)\\b|\\bsource_row\\b|\\babsolute_row\\b" src/terminal`

Result: checks passed. `moon coverage analyze` completed and reported existing
uncovered lines; it did not fail. The strict forbidden-symbol grep returned no
matches.

### 2026-05-14: Row-ID Compatibility Removal Decision

Local investigation found no tun-poc server usage of Ghostty row IDs:

- no source references to `row_id`, `GridRef`, `grid_ref`, or
  `format_scrollback_rows_since` outside `vendor/ghostty`;
- server rendering uses `StreamTerminal`, `RenderState`, complete framebuffer
  formatting, and scrollback row counts instead of row-id watermarks.

User decision: delete row-id compatibility instead of preserving it as a public
adapter. Phase 7 is changed from rebuilding `GridRef` compatibility to removing
that surface and updating tests/tools to use coordinates directly.

### 2026-05-14: Row-ID Compatibility Removal Checkpoint

Implemented in canonical first:

- Deleted `GridRef` and removed all public `StreamTerminal::grid_ref*`,
  `StreamTerminal::point_from_grid_ref`, and
  `StreamTerminal::format_scrollback_rows_since` APIs.
- Removed `PageListCompatRows` and all row-id production/lookup paths from
  `PageList`.
- Replaced formatter selection and kitty placement rectangles with
  `Selection[Coordinate]`.
- Kept render viewport dirty detection row-id-free by tracking the screen
  coordinate of the viewport origin.
- Updated the playground, Rabbita demo, surface registry, tests, and generated
  package interface for the coordinate API.
- Deleted the obsolete `stream_terminal_grid_ref_test.mbt`.

Validation run in canonical:

- `moon check`
- `moon test src/terminal/formatter_test.mbt`
- `moon test src/terminal/formatter_wbtest.mbt`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt`
- `moon test src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `moon test src/terminal/terminal_screen_state_wbtest.mbt`
- `moon test src/terminal/kitty_graphics_test.mbt`
- `moon test src/terminal/kitty_graphics_wbtest.mbt`
- `moon test src/terminal/render_state_test.mbt`
- `moon test src/terminal/terminal_package_smoke_test.mbt`
- `moon test src/terminal/terminal_surface_registry_test.mbt`
- `moon test src/terminal`
- `moon test`
- `moon fmt`
- `moon info`
- `rg -n "GridRef|grid_ref|point_from_grid_ref|format_scrollback_rows_since|compat_rows|compat_|row_id_value|\\brow_id\\b" src/terminal tools/terminal_playground_core demo/rabbita_asciinema -g '*.mbt' -g '*.mbti'`

Result: checks passed. `moon check` still reports existing deprecated
`assert_eq` warnings in unrelated tests. The row-id compatibility grep returned
no matches in source and generated terminal interfaces.

## Stop Conditions

Stop and ask before implementation if any of these happens:

- MoonBit storage cannot represent upstream page/node pin identity directly.
- A new external consumer for public row-id semantics is found.
- A proposed helper or data field has no upstream equivalent.
- A step requires keeping `flatten_rows`/`rebuild_from_rows`.
- A test expectation requires product behavior not present in upstream.

## Acceptance Criteria

- Internal cursor, saved cursor, viewport, and kitty placement tracking use
  PageList pins, not row IDs.
- Public row-id compatibility APIs and `GridRef` are removed.
- `trim_leading_blank_pinned_rows` and equivalent local-only trim helpers are
  gone.
- Reflow is driven by a `ReflowCursor` equivalent, not post-hoc array splitting.
- Resize dispatch follows upstream ordering.
- Full scrollback/render formatting remains correct after column reflow.
- Cursor and saved cursor survive row shrink, column resize, blank tracked rows,
  and alternate-screen resize according to upstream semantics.
- `vendor/ghostty` and canonical `~/Workspace/moonbit/feihaoxiang/ghostty`
  are synced after the canonical implementation lands.
