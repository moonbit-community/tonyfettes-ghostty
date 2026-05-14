# P13.D PageList Resize Alignment

## Goal

Replace the partial MoonBit resize/reflow port with a faithful semantic
alignment to upstream Ghostty's `PageList.zig` pin and `ReflowCursor` model.
The task closes the resize review findings around scrollback watermarks,
tracked blank rows, and alternate-screen saved cursor ownership without merging
a local-only resize model.

## Upstream files

- `upstream/ghostty/src/terminal/PageList.zig`
  - `resize`
  - `resizeCols`
  - `ReflowCursor`
  - `resizeWithoutReflow`
- `upstream/ghostty/src/terminal/Screen.zig`
  - `Screen.resize`
  - saved-cursor pin tracking before and after resize
- `upstream/ghostty/src/terminal/page.zig`
  - row metadata and cell wide/spacer semantics used by reflow

## MoonBit target files

- `src/terminal/terminal_screen_state.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/formatter.mbt`
- `src/terminal/terminal_cursor_state.mbt`
- `src/terminal/stream_terminal_resize_wbtest.mbt`
- `src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `src/terminal/terminal_screen_state_wbtest.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plans/2026-05-14-p13-d-pagelist-resize-alignment.md`

## Dependencies and invariants

- MoonBit still stores rows in arrays rather than upstream linked pages. The
  implementation must therefore encode the upstream pin contract explicitly:
  tracked positions are source-row/source-cell pins that move as the reflow
  cursor writes output rows.
- Reflow must be driven by a cursor that owns destination `x`, pending-wrap
  state, deferred blank rows, and row metadata copying. It must not be a
  post-hoc line splitter that assigns identity independently of pin movement.
- Blank source rows are deferred the same way upstream does: trailing blank rows
  are not written, but blank rows containing tracked pins are materialized so
  the pin can remap before any active-area trimming.
- Row identities used by incremental scrollback must be monotonic in final
  display/history order after reflow. Continuation rows cannot receive high IDs
  between older source row IDs.
- Cursor and saved-cursor remapping must use tracked pins first, then convert
  the tracked pin back to active coordinates after the resized active area is
  selected.
- Saved cursors belong to the screen that created them. `?1049h` saves a
  primary-screen cursor before the active screen switches to alternate, so a
  resize while alternate is active must remap that saved cursor through primary
  storage, not alternate storage.
- Existing `GridRef` consumers must be audited. Any stored reference that must
  survive resize needs an explicit tracking path; untracked row IDs are only
  stable for lookup against the current page list snapshot.

## RED checks

Run or add the smallest failing tests before the implementation:

- `moon test src/terminal/stream_terminal_resize_wbtest.mbt --filter "resize reflow narrow scrollback keeps row id watermark monotonic"`
  - create scrollback containing a long logical line
  - resize narrower so the history line splits
  - call `format_scrollback_rows_since` twice and assert the second call emits
    no duplicate continuation rows
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt --filter "resize preserves cursor on tracked blank trailing row"`
  - place the cursor on an empty trailing active row
  - resize columns
  - assert the cursor remains on the corresponding active row instead of
    falling back to `(0,0)`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt --filter "resize alternate screen keeps 1049 saved primary cursor"`
  - save the primary cursor through `?1049h`
  - switch to alternate, write alternate content, resize, then `?1049l`
  - assert restored primary cursor coordinates and pending-wrap state are the
    primary-screen values

## Implementation plan

1. Introduce an internal pin representation in `terminal_screen_state.mbt`:
   source absolute row index, source x, target absolute row index, target x, and
   a tracked kind for cursor/saved cursor.
2. Replace `PageListTrackedPoint` row-id tracking with pin tracking. Build pins
   from the pre-resize flattened display order before any row mutation.
3. Rework resize dispatch to match upstream order:
   - same columns: rows-only resize without reflow
   - growing columns: reflow columns, then rows-only resize
   - shrinking columns: rows-only resize, then reflow columns
4. Implement a MoonBit `PageListReflowCursor` over arrays:
   - `x`, `pending_wrap`, `new_rows`, target columns, output rows
   - deferred blank row emission
   - row metadata copy and prompt-continuation adjustment
   - wide/spacer behavior matching upstream `writeCell`
   - tracked pin moves when a source cell is written or skipped
5. Assign final `row_id` values in display order after reflow/rebuild so
   history remains sorted for `format_scrollback_rows_since`.
6. Preserve active-area geometry around the cursor using upstream's
   `remaining_rows` and `wrapped_rows` rule so resize does not pull scrollback
   down when the cursor is above the bottom.
7. Add saved-cursor ownership to the bridge-level saved cursor state or an
   equivalent internal owner field, then pass the saved cursor only to the
   owning `TerminalScreenStorage::resize`.
8. Audit `GridRef` and kitty graphics placement paths after row-id assignment.
   If a stored owner must survive resize, add an explicit tracked-pin remap for
   that owner in the same task; otherwise record the non-survival behavior here.
9. Keep public API unchanged unless the owner tracking requires a new private
   field. Review `pkg.generated.mbti` after `moon info`.

## Acceptance criteria

- Existing resize tests continue to pass.
- New RED tests fail before the implementation and pass after it.
- `format_scrollback_rows_since` never observes non-monotonic history row IDs
  after column reflow.
- Cursor and saved cursor remap through tracked pins, including tracked blank
  trailing rows.
- `?1049h`/`?1049l` saved cursor restoration remains associated with primary
  storage across alternate-screen resizes.
- Any touched public API change is justified here; otherwise `.mbti` remains
  unchanged except for generated ordering/format churn.
- `./vendor/ghostty` and `~/Workspace/moonbit/feihaoxiang/ghostty` are synced
  again after the canonical repo fix lands.

## Validation commands

- `moon check`
- `moon test src/terminal/stream_terminal_resize_wbtest.mbt`
- `moon test src/terminal/stream_terminal_scrollback_wbtest.mbt`
- `moon test src/terminal/terminal_screen_state_wbtest.mbt`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze -- -f summary` exits 0 with `Total:
  10693/11027`.
- Touched core files:
  - `src/terminal/terminal_screen_state.mbt`: `565/586`. Remaining
    uncovered lines are defensive saved-cursor fallback paths, cursor/saved
    cursor out-of-bounds tracking paths, uncommon wide/spacer reflow branches,
    prompt-continuation metadata, grapheme/style/hyperlink row-flag copying,
    leading blank trim, and no-target helper fallbacks.
  - `src/terminal/stream_terminal_bridge.mbt`: `1473/1520`. The resize-owned
    saved cursor path is covered for primary ownership through `?1049h`/`?1049l`.
    The alternate-owned saved cursor branch remains uncovered; the other gaps
    are unrelated scrollback-cleared, reverse-index, dynamic-color query, and
    OSC terminator paths.
  - `src/terminal/formatter.mbt`: `684/753`. The incremental scrollback
    formatter path is covered by the row-id watermark regression. Remaining
    uncovered lines are empty-history, VT framebuffer formatting,
    missing-cell/range clamp fallbacks, spacer/blank compression branches, and
    charset escape helpers.
  - `src/terminal/terminal_saved_cursor_state.mbt`: no uncovered lines reported
    by caret coverage.
- The newly added resize tests cover the three review regressions directly:
  monotonic row-id watermarking after narrow reflow, tracked blank trailing row
  preservation, and `?1049` saved primary cursor ownership across alternate
  screen resize.

## Commit scope

- `fix(terminal)`

## Review findings

- `PageListRow.row_id` is now mutable only inside the package so resized rows
  can be reassigned in final display order after column reflow.
- Tracked points keep mutable target row/x coordinates and are updated while
  rows are materialized, trimmed, padded, and renumbered.
- Blank pinned rows targeted by cursor or saved cursor are excluded from the
  leading/trailing blank trim so active-coordinate remap can still find them.
- Saved cursor state records the owning `TerminalScreen`, and bridge resize
  passes the saved cursor only to the storage that created it.
- The implementation remains array-backed rather than a direct linked-page
  port, but the resize invariants now match the upstream pin model where the
  MoonBit storage representation differs.

## Audit / result notes

Initial audit:

- The current partial port allocates continuation row IDs during line split and
  then keeps later source row IDs, which violates the incremental formatter's
  sorted-history contract.
- The current reflow path materializes tracked blank cells and then trims the
  trailing blank row before active-coordinate remap.
- The current bridge chooses the saved cursor resize target from the active
  screen, but `?1049h` creates the saved cursor on primary before alternate is
  active.

Final validation:

- RED before the implementation:
  - `moon test src/terminal/stream_terminal_resize_wbtest.mbt` failed the
    row-id watermark regression by re-emitting `efgh\r\nzz\r\n` on the second
    incremental formatter poll.
  - The tracked blank-row resize regression restored the cursor to row `0`
    instead of row `1`.
  - The `?1049` alternate-screen resize regression restored the primary cursor
    to row `1` instead of row `2`.
- GREEN/VERIFY after the implementation:
  - `moon check`: passed with existing deprecated `assert_eq` warnings.
  - `moon test src/terminal/stream_terminal_resize_wbtest.mbt`: `12/12`.
  - `moon test src/terminal/stream_terminal_scrollback_wbtest.mbt`: `2/2`.
  - `moon test src/terminal/terminal_screen_state_wbtest.mbt`: `3/3`.
  - `moon test`: `507/507 [wasm-gc]`, `22/22 [js]`.
  - `moon coverage analyze -- -f summary`: passed, `10693/11027`.
  - `moon fmt`: ran successfully.
  - `moon info`: ran successfully.
  - `diff -qr vendor/ghostty ~/Workspace/moonbit/feihaoxiang/ghostty --exclude
    .git --exclude .mooncakes --exclude _build --exclude .envrc --exclude
    upstream`: no output.

## Public API visibility findings

- `moon info` does not expose the new pin helpers, reflow tracking helpers, or
  saved-cursor owner field as public API.
- `pkg.generated.mbti` changes from the canonical sync are reviewed as
  deliberate host-facing surface updates:
  - removed deprecated `CursorMovement::inner` and
    `KittyKeyboardFlags::inner`;
  - added `RenderState::format_vt_framebuffer`;
  - added terminal margin accessors,
    `StreamTerminal::format_scrollback_rows_since`, and
    `StreamTerminal::take_scrollback_cleared`.
- No public mutable fields were added for the resize fix.
