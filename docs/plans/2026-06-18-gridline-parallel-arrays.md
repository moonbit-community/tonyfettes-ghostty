# Grid row storage: `Array[GridLine]` → parallel `descs`/`cells` arrays

Post-translation performance work on the grid's row storage. No behavior change;
every test (550, on all four backends) passes. This is a fidelity-improving
deviation: it splits a row into a value descriptor and a cell buffer the way
upstream Ghostty's page does, instead of bundling them in a per-row heap object.

## Goal

Stop allocating and dropping a per-row heap object (`GridLine`) on every scroll,
and make the row descriptor a flat scalar so sliding rows is a plain memmove.

The grid stored its rows as `Array[GridLine]`, where

```moonbit
priv struct GridLine {
  mut desc : PageRowState              // row flag bits (an unboxed Int newtype)
  cells : FixedArray[PageCellState]    // the row's cols-wide cell buffer
}
```

is a *heap object*. A full-width scroll slides the survivor rows with a single
`blit_to` over the `Array[GridLine]`; because each element is a reference, that
blit increfs/decrefs every moved row and drops the scrolled-off boxes. The
profile (`plain_lines`) flagged `unsafe_blit[GridLine] <- moonbit_drop_object` as
the top `drop_object` source after the print fast lane landed
(`docs/plans/2026-06-18-print-fastpath.md:103`).

## Upstream reference

- `upstream/ghostty/src/terminal/page.zig` — a `Page` stores `rows: Offset(Row)`
  (an array of `Row` *values*, each a `packed struct(u64)` of flag bits plus a
  `cells: Offset(Cell)` offset) and `cells: Offset(Cell)` (one flat `Cell`
  buffer). A row is a value, not a heap object; scrolling slides row values /
  rotates offsets, with no per-row allocation or refcount.

MoonBit has no `packed struct` to fuse the flag bits and an integer cell offset
into one word, and — unlike Zig's integer `Offset(Cell)` — our cells are a heap
`FixedArray` reference, not an offset into a shared buffer. So we mirror the same
*split* with two parallel arrays instead of one array of fused row values.

## Change (`terminal/screen_grid_state.mbt`, `terminal/terminal_screen_state.mbt`)

- `GridLine` is removed. `ScreenGridState` and `PageListPage` now hold two
  parallel per-row arrays:
  ```moonbit
  descs : Array[PageRowState]              // row i's descriptor
  cells : Array[FixedArray[PageCellState]] // row i's cell buffer
  ```
  `descs[i]`/`cells[i]` together are what `lines[i].desc`/`lines[i].cells` were.
  The active page shares both arrays with the grid by reference, exactly as it
  shared the single `lines` array before.
- A row descriptor is rewritten on nearly every printed cell (`mark_dirty`, flag
  maintenance). Keeping `descs` a flat scalar array (`PageRowState` is an
  `Int` newtype) makes that a plain int store, and makes a scroll's descriptor
  slide a scalar memmove with zero refcount traffic — the part the old
  `GridLine`-reference blit paid incref/decref for.
- A scroll now blits the two arrays in lockstep
  (`shift_full_width_up`/`shift_full_width_down`): one scalar `descs` blit and
  one by-reference `cells` blit, replacing the single `Array[GridLine]` blit. The
  per-row heap box is gone, so the scrolled-off slots no longer drop a `GridLine`.
- The scrolled-in blank row is written directly into the `descs[i]`/`cells[i]`
  slots (`set_blank_row`) instead of building a `GridLine` value — no
  intermediate row object or tuple is allocated.
- Cells stay per-row `FixedArray`s (not one flat buffer): a row scrolled into
  history is handed off by reference, zero-copy (`harvest_scrollback_row`), which
  a contiguous flat buffer could not do without a per-row copy. Fusing
  `descs`/`cells` into one flat *value* grid is the follow-on `#valtype
  PageCellState` change.

### Hoist the row buffer out of per-cell loops

Splitting cells into `Array[FixedArray]` means a per-cell `self.cells[row][col]`
reloads — and refcounts — the row's `FixedArray` reference out of the outer array
on every column. The bundled `GridLine.cells` field projection did not pay that.
Left unaddressed this regressed cell-rewrite-heavy workloads (`tui_redraw` +10%).

Fix: the hot per-cell loops hoist the row buffer once
(`let row_cells = self.cells[row_idx]`) and index it directly —
`clear_full_row`, `clear_row_range`, `copy_row_region`, `recompute_row_flags`.
This loads the reference once per row instead of once per cell, and is what Zig
effectively does by holding a single row/cell pointer for the row. With the hoist
`tui_redraw` returns to baseline and every other workload keeps its win.

## Why no `.mbti` change

`GridLine`, `ScreenGridState`, and `PageListPage` are all `priv`; their fields
never appear in the package interface. `moon info` regenerates no delta.

## Acceptance criteria

- No per-row heap object allocated/dropped on a scroll; descriptor slide is a
  scalar memmove. Met — `GridLine` is gone; `unsafe_blit[GridLine] <-
  drop_object` no longer appears in the `plain_lines` profile.
- Terminal state identical; no public API change. Met — 550 tests pass on
  wasm/wasm-gc/js/native; no `.mbti` delta.
- No workload regresses. Met (see results).

## Validation commands

- `moon check && moon test --target all && moon fmt && moon info`
- `moon bench -p bench/workloads --release --target native`
- `moon run bench/tui_redraw --release --target native --profile` (regression
  diagnosis: `clear_rows` refcount traffic before/after the hoist)

## Audit/result notes

- `moon bench` (native release), main baseline → after (median of repeated runs):
  - `scroll_storm` 1.46 ms → 1.37 ms (−6.2%); `colored_log` 482 µs → 461 µs
    (−4.4%); `sgr_storm` 9.41 ms → 9.00 ms (−4.4%); `mixed_realistic` 882 µs →
    847 µs (−4.0%); `wrapped_blob` 474 µs → 457 µs (−3.6%); `plain_lines` 511 µs
    → 494 µs (−3.2%); `query_storm` 8.76 ms → 8.56 ms (−2.3%); `cjk_text` 803 µs
    → 787 µs (−2.0%); `tui_redraw` 1.44 ms → 1.46 ms (+1.4%, neutral).
- The win is real but modest: the `GridLine`-box churn was prominent in
  `drop_object` *counts* but not dominant in wall-clock. The larger lever is the
  follow-on `#valtype PageCellState` (a flat value cell buffer), which removes
  the per-cell refcount this change leaves in place. This change is the faithful
  intermediate step (Zig's row/cell split) and the prerequisite shape for it.

## Commit scope

- `perf(grid)` (internal storage refactor; no public `.mbti` change).
