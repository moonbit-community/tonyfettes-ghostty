# Grid circular row origin

Post-translation performance follow-up for full-screen row relocation. This is
a behavior-preserving extension of completed plan step `P7.3.1`: it removes the
three overlapping row-array blits left in the full-screen scroll path while
preserving the logical screen, scrollback, resize, pin, and screen-switch
contracts.

## Goal

Keep one persistent active `ScreenGridState` per `PageList` and represent the
logical top row with a private circular origin. A full-screen scroll changes
that origin and blanks the newly exposed slots instead of blitting descriptor,
cell-buffer, and hyperlink-array storage.

Only row relocation becomes constant time. Survivor cleanup, blank-row refill,
dirty marking, scrollback capture, and pin maintenance retain their existing
costs, so this task does not describe the complete scroll operation as O(1).

## Upstream sources

- `upstream/ghostty/src/terminal/page.zig`
  - `Page.rows` is the logical row-order array.
  - each scalar `Row` points at its cell storage; the cell allocation itself is
    not required to be in row order.
- `upstream/ghostty/src/terminal/Screen.zig`
  - `Screen.cursorScrollAbove` selects a local row-rotation fast path when the
    affected rows remain in one page.
  - `Screen.cursorScrollAboveRotate` rotates `Row` values, clears the exposed
    row, dirties the affected page, and then refreshes cached cursor pointers.

## Approved MoonBit compatibility adapter

MoonBit stores the translated rows as three parallel arrays:
`FixedArray[PageRowState]`, `FixedArray[FixedArray[PageCellState]]`, and
`FixedArray[FixedArray[HyperlinkId]?]`. The last two arrays contain references,
so rotating them performs ARC work that upstream avoids by rotating scalar
`Row` records.

The approved adapter has this exact shape:

- `ScreenGridState` becomes a readonly public struct with
  `priv mut row_origin : Int`; callers can read the existing storage handles but
  cannot construct or mutate the origin.
- `ScreenGridState::from_shared_storage` is the sole cross-package constructor
  for a `PageList` page's arrays and intern tables.
- logical row access is owned by `ScreenGridState` methods; PageList uses those
  methods instead of assuming physical index zero is the logical top.
- `PageList` stores `mut grid : ScreenGridState`, and `active_grid` returns that
  persistent object. Resize/reflow and full reset replace it together with the
  active page and table identities.

This adapter is required because MoonBit has no translated scalar `Row` record
that can carry offsets to the three storage arrays without reintroducing the
reference-bearing row object removed by the parallel-array work.

## MoonBit targets

- `terminal/grid/grid.mbt`
  - `ScreenGridState` storage visibility and construction;
  - logical-to-physical row access;
  - full-screen up/down origin rotation;
  - mapped non-full-screen row movement;
  - reset normalization.
- `terminal/pagelist/pagelist.mbt`
  - persistent active-grid ownership;
  - logical row capture/query;
  - resize/reflow and full-reset replacement.
- `terminal/stream_terminal_bridge.mbt`
  - reset comments and reacquisition contract, only if the ownership change
    makes the existing explanation stale.
- existing focused tests under `terminal/grid`, `terminal/pagelist`, and
  terminal end-to-end screen/scrollback suites.

The generated native release C and benchmark/profile outputs are inspection
evidence only and are not committed.

## Must-preserve invariants

- Logical row zero is always the visible top row. The private origin never
  escapes and stays in `[0, rows)`.
- `descs`, `cells`, and `link_ids` map every logical row through the same
  physical index and therefore remain paired.
- A full-screen upward scroll first exposes the logical top rows to scrollback
  capture, then advances the origin, then replaces the freed physical slots
  with distinct blank row buffers.
- Partial-height and margin-constrained shifts preserve rows outside the
  affected region and do not rotate the whole screen.
- `active_grid()` returns the persistent current grid, including its origin,
  cell pool, and intern-table identities.
- Resize/reflow reads logical rows, builds a normalized replacement grid, and
  installs that same grid in both `PageList` and terminal screen storage.
- Full reset blanks all rows, normalizes the origin, mints fresh intern tables,
  and installs a persistent grid sharing the active page arrays with those
  tables.
- Pins continue to use logical active-screen row numbers. Scrollback history
  preserves descriptors, styles, hyperlinks, graphemes, and cell-buffer
  ownership.
- Primary and alternate `PageList`s keep independent grid objects and origins.

## Test matrix

- full-screen scroll up and down by one and by multiple rows;
- repeated full-screen scrolling past origin wrap;
- reacquiring `active_grid()` after wrap preserves logical contents and returns
  the persistent grid object;
- full-width partial-height and left/right-margin shifts leave outside rows
  unchanged;
- scrollback capture preserves text, row flags, style, hyperlink, and grapheme
  data after origin wrap;
- active-screen and viewport pins move to the same logical rows as before;
- resize without reflow and column reflow after origin wrap;
- full reset after origin wrap, including fresh intern-table identity;
- primary/alternate screen switching with independent wrapped origins.

## Performance acceptance

- Generated native release C for `scroll_full` contains no reference-array blit
  in the full-screen row-relocation branch.
- Four paired native-release rounds compare current `origin/main` immediately
  followed by this branch for `scroll_full`, `scroll_storm`, `plain_lines`,
  `wrapped_blob`, `tui_redraw`, and `colored_log`.
- The intended result is at least an 8% median improvement in the full-screen
  scroll workloads with no repeatable regression above 2% in control workloads.
  The audit records the measured result even if it misses that target.
- A fresh `scroll_full` profile verifies that reference-array blit attribution
  leaves the hot path and identifies the next remaining bottleneck.

## Validation commands

- `moon check --target all`
- focused grid, PageList, scrollback, resize, formatter/render, and screen-switch
  tests on all targets
- `moon test --target all`
- `moon test --target native --enable-coverage`
- `moon coverage analyze`
- `moon coverage analyze -- -f caret -F terminal/grid/grid.mbt`
- `moon coverage analyze -- -f caret -F terminal/pagelist/pagelist.mbt`
- `moon build --release --target native bench/scroll_full`
- generated native C inspection for full-screen relocation
- four paired native-release benchmark rounds listed above
- fresh native `scroll_full` profile
- `moon fmt`
- `moon info`
- `git diff --check`
- generated `.mbti` diff and public API audit
- `git status --short`

## Audit notes

- Implemented one persistent active `ScreenGridState` per `PageList` with a
  private circular row origin. Full-screen up/down shifts rotate that scalar;
  partial-height full-width shifts still move only the requested logical rows.
  Resize/reflow and full reset install the same normalized replacement grid in
  both terminal storage and `PageList`.
- Added focused regression coverage for origin wrap in both directions,
  partial-height moves at a non-zero origin, persistent-grid reacquisition,
  scrollback row metadata and cell ownership, active/history pins, row resize,
  column reflow, reset table identity, and independent primary/alternate
  origins.
- The first implementation routed the per-character print path through the
  public `row_cells` accessor. Early paired runs showed a plain/wrapped control
  regression, and generated C showed one returned array reference being
  incremented and decremented per cell. The final print path carries one
  physical-row scalar through its fused cell/descriptor update; the final
  control results below no longer reproduce that regression.
- Four paired rounds ran current `origin/main` immediately before this branch.
  Values are medians of the four per-round benchmark means; negative change is
  faster:

  | workload | `origin/main` | branch | change |
  | --- | ---: | ---: | ---: |
  | `plain_lines` | 255.06 us | 249.79 us | -2.07% |
  | `wrapped_blob` | 238.81 us | 238.94 us | +0.05% |
  | `scroll_storm` | 867.60 us | 766.44 us | -11.66% |
  | `scroll_full` | 5.170 ms | 4.715 ms | -8.80% |
  | `colored_log` | 273.46 us | 268.33 us | -1.88% |
  | `tui_redraw` | 791.26 us | 795.62 us | +0.55% |

  Both scroll workloads clear the 8% acceptance threshold; no control workload
  has a repeatable regression above 2%.
- Native release C inspection found no `moonbit_unsafe_ref_array_blit` call in
  `ScreenGridState::shift_full_width_up`. The final `print_cell` body indexes
  `cells` and `descs` with the carried physical-row scalar and does not call the
  public row-buffer accessor.
- A fresh native `scroll_full` profile collected 336 one-millisecond samples.
  Reference-array blit attribution is gone. The next costs are local ARC and
  logical-row access: `moonbit_drop_object` is 16.1% self time,
  `row_state` 8.0%, `moonbit_decref_inlined` 7.4%, and `row_cells` 7.1%.
  Caller attribution places 9.2% of samples in
  `StreamTerminalBridgeState::index <- moonbit_drop_object`; the remaining
  `shift_full_width_up` ARC attribution is 3.9% incref plus 3.3% decref.
- Final validation passed:
  - `moon check --target all`;
  - `moon test --target all`: 664 wasm, 664 wasm-gc, 686 JS, and 664 native
    tests passed;
  - `moon test --target native --enable-coverage`: 664 tests passed;
  - `moon coverage analyze -- -f summary`: 13,360/14,903 executable lines,
    including 627/650 in `terminal/grid/grid.mbt` and 820/969 in
    `terminal/pagelist/pagelist.mbt`;
  - caret review confirms the new origin, persistence, reset, resize, and pin
    paths are covered; remaining touched-file gaps are pre-existing pool,
    exceptional-bound, pin, and reflow branches;
  - `moon build --release --target native bench/scroll_full`;
  - `moon fmt`, `moon info`, `git diff --check`, generated API diff, and public
    API audit.
- The generated API intentionally changes `ScreenGridState` from `pub(all)` to
  readonly `pub`, adds the shared-storage constructor and logical-row methods,
  and keeps `row_origin` private. Every added public method has a `PageList`
  consumer; no public mutable field was introduced.
- The native release build and profile emit the pre-existing warning [0073] for
  the unnecessary `OptimizeMode::` annotation in
  `terminal/build_info_optimize_release.mbt`; this task does not change that
  file.
