# Grid row storage: `Array` → `FixedArray` for the fixed-size row arrays

Post-translation performance work on the grid's parallel row arrays. No behavior
change; every test (550, on all four backends) passes. Follow-on to the
`descs`/`cells` split (`docs/plans/2026-06-18-gridline-parallel-arrays.md`).

## Goal

Drop the growable `Array` wrapper from the per-row arrays. A grid's row count is
fixed for the life of the grid — it is never grown or shrunk in place; a resize
allocates a whole new grid (`ScreenGridState::new` / `PageListPage::new`). So the
`Array`'s length/capacity bookkeeping and its extra indirection are pure overhead
on every row access (`descs[i]`, `cells[i]`), which happens on essentially every
print, scroll, and read.

```moonbit
descs : Array[PageRowState]               // → FixedArray[PageRowState]
cells : Array[FixedArray[PageCellState]]  // → FixedArray[FixedArray[PageCellState]]
```

`FixedArray` is the bare buffer: one allocation, indexed directly, no growable
wrapper object between the grid and its rows.

## Upstream reference

- `upstream/ghostty/src/terminal/page.zig` — a `Page`'s `rows` and `cells` live
  in a fixed memory pool sized once at page creation (`Offset` slices into that
  pool), never a growable container. A fixed-capacity buffer is the closer
  translation of that shape than a growable `Array`.

## Change (`terminal/screen_grid_state.mbt`, `terminal/terminal_screen_state.mbt`)

- `descs`/`cells` fields on `ScreenGridState` and `PageListPage` become
  `FixedArray`.
- `ScreenGridState::new` / `PageListPage::new` build them with
  `FixedArray::makei(rows, ...)` — one sized allocation each, versus the old
  empty-`Array` + `push` loop (which reallocs and ref-blits the growing buffer
  ~log2(rows) times).
- The two scroll slides (`shift_full_width_up`/`shift_full_width_down`) move from
  `ArrayView::blit_to(dst, dst_offset=)` to `FixedArray::unsafe_blit(dst,
  dst_offset, src, src_offset, len)`. The index math is identical; see the
  overlap note below.
- `cell_pool` stays an `Array` — it is a genuine free list that grows and shrinks
  via `push`/`pop`, so the growable wrapper is the right type there.

### `unsafe_blit` is overlap-safe (the scroll slides overlap in place)

Both scroll slides are same-array overlapping moves, so the copy direction must
be chosen to not clobber source cells before they are read. `FixedArray::
unsafe_blit` does exactly that — its reference implementation copies forward when
`physical_equal(dst, src) && dst_offset < src_offset` and backward otherwise,
i.e. memmove semantics. Its documented undefined cases are only the
out-of-bounds ones (`len < 0`, negative offsets, `offset + len > length`);
overlap is well-defined. The "unsafe" refers to the absence of bounds checking,
not to overlap. The index arithmetic matches the previous `blit_to` exactly:

- down (`dst_offset = start_y + count > src_offset = start_y`): backward copy.
- up (`dst_offset = start_y < src_offset = start_y + count`): forward copy.

Verified by the scroll tests passing on all four backends (the intrinsic
`%fixedarray.copy` honoring memmove semantics on each).

## Why no `.mbti` change

`ScreenGridState` and `PageListPage` are `priv`; their field types never appear
in the package interface. `moon info` regenerates no delta.

## Acceptance criteria

- No growable wrapper on the fixed-size row arrays; row access indexes the bare
  buffer. Met.
- Terminal state identical; no public API change. Met — 550 tests pass on
  wasm/wasm-gc/js/native; no `.mbti` delta.
- No workload regresses. Met (see results).

## Validation commands

- `moon check && moon test --target all && moon fmt && moon info`
- `moon bench -p bench/workloads --release --target native`

## Audit/result notes

- `moon bench` (native release), `Array` (main, post-`#34`) → `FixedArray`,
  median of 4 alternating-order rounds (order flipped each round to cancel
  thermal drift):
  - `scroll_storm` 1.39 ms → 1.22 ms (−12.2%); `scroll_full` 8.91 ms → 7.95 ms
    (−10.8%); `osc_titles` 517 µs → 476 µs (−7.8%); `mixed_realistic` 838 µs →
    775 µs (−7.5%); `cjk_text` 777 µs → 719 µs (−7.4%); `plain_lines` 499 µs →
    470 µs (−5.8%); `sgr_storm` 9.16 ms → 8.79 ms (−4.0%); `colored_log` 464 µs →
    449 µs (−3.2%); `wrapped_blob` 457 µs → 446 µs (−2.5%).
  - Neutral: `color_storm` (−0.9%), `tui_redraw` (0.0%), `query_storm` (+0.2%).
- `scroll_storm` paired across all four rounds: 1.35→1.22, 1.36→1.25, 1.39→1.21,
  1.39→1.22 ms; `plain_lines`: 484→471, 500→469, 488→465, 498→469 µs — both
  rock-solid. The win is broad because dropping the wrapper indirection helps
  every row access, and `scroll_*` additionally gets a direct `unsafe_blit`
  memmove in place of the `ArrayView::blit_to` slice path.

## Commit scope

- `perf(grid)` (internal storage refactor; no public `.mbti` change).
