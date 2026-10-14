# Grid local ARC cleanup

Post-translation performance follow-up for the full-width scroll path. This is
a behavior-preserving extension of completed plan step `P7.3` (`hot path
behavior`): the translation phases stay closed, and the final change only
removes repeated work and receiver ARC while refilling a recycled row.

## Goal

Compute one blank `PageCellState` when refilling a pooled row buffer, then store
that immutable scalar across the row. This removes one `blank_cell` call and
its possible `StyleTable` receiver ARC per column without changing storage or
terminal semantics.

This slice does not add helper functions or types and does not change
benchmarks, the terminal bridge, grid storage, pagelist storage, equality
dispatch, ring behavior, or handler batching.

## Upstream sources

- `upstream/ghostty/src/terminal/page.zig`
  - `Page.rows` and `Page.cells` keep row descriptors and cell storage
    separate.
  - `Row` is a `packed struct(u64)`: wrap, continuation, styled, hyperlink,
    placeholder, and dirty updates are scalar value updates rather than
    reference-bearing row mutations.
- `upstream/ghostty/src/terminal/Screen.zig`
  - `Screen.cursorScrollAbove` and `cursorScrollAboveRotate` rotate row values,
    mark moved page contents dirty, clear the new row, and use one
    `@memset`-style fill for a non-default background.
  - default style skips background-cell construction; non-default background
    keeps the normal style lookup/interning behavior.

## MoonBit targets

- `terminal/grid/grid.mbt`
  - `ScreenGridState::set_blank_row`.

The generated native release C for `bench/plain_lines` and `bench/scroll_full`
is inspection evidence only and is not committed.

## Must-preserve invariants

- `descs[row]` remains the descriptor paired with `cells[row]`; the full-width
  scroll moves descriptor, cell, and hyperlink arrays in lockstep and dirties
  the complete affected region.
- A blank cell preserves only the erase background. Default erase still uses
  `@page.default_page_cell_state`; colored erase still interns the same
  background-only style. A pooled row and a newly allocated row remain
  behaviorally identical, and `blank_row_is_styled` remains consistent with
  their cells.
- There is no public API, generated `.mbti`, storage-model, bridge, pagelist, or
  benchmark-source change.

## Implementation shape

1. In `set_blank_row`'s pooled-buffer branch, calculate `blank_cell` once before
   the refill loop and reuse that immutable value for every indexed store.

## Acceptance criteria

- A pooled row refill computes the blank cell once outside the per-cell loop.
- `scroll_full`, which reaches row-pool reuse after overflowing scrollback,
  improves without a repeatable regression in control workloads.
- Grid/page targeted tests and the full all-target test suite pass.
- Coverage for touched executable lines is reviewed; any uncovered line is
  recorded below.
- `moon fmt`, `moon info`, `git diff --check`, and the public API audit are
  clean. No `.mbti` change is expected.

## Validation commands

- `moon check --target all`
- `moon test -p tonyfettes/ghostty/terminal/grid --target all`
- `moon build --release --target native bench/scroll_full`
- inspect generated `scroll_full.c` for the `set_blank_row` loop shape
- `moon test --target all`
- `moon test --target native --enable-coverage`
- `moon coverage analyze`
- four paired native-release rounds of `plain_lines`, `scroll_storm`,
  `scroll_full`, and `colored_log`, clean `main` immediately followed by this
  worktree in each round
- `moon fmt`
- `moon info`
- `git diff --check`
- `git diff -- terminal/grid/pkg.generated.mbti`
- `git status --short`

## Audit notes

- The accepted grid change computes one packed blank cell before a pooled row's
  refill loop and stores that immutable value across the row.
- Evaluated and rejected `#inline` on the cross-package `PageRowState` methods.
  It removed survivor-wrap and dirty-pass array ARC, but a four-run ablation
  moved the `scroll_storm` median about 2.3% in the wrong direction. The final
  diff therefore leaves `terminal/page/cell.mbt` unchanged.
- Evaluated and rejected keeping only a scalar descriptor live across
  `record_cell_write`. Generated C removed that array ARC, but the final paired
  `scroll_storm` ablation moved the median about 1.0% in the wrong direction,
  so the source-shape change is not retained.
- Evaluated and rejected a default-style guard duplicated directly in
  `write_cell_and_update_row_flags`. Four paired runs showed a useful
  `plain_lines` median improvement (about 2.6%), but `colored_log` regressed
  about 2% because non-default cells paid `CellStyle::is_default` in the grid
  and then repeated it inside `StyleTable::intern`. Removing the duplicate
  guard made colored output flat but also lost the plain-text gain.
- Attempted the `StyleTable::intern` wrapper / `intern_non_default` split and
  rejected it at the generated-C gate. The private method correctly contains
  no second default check, but the native cross-package inliner leaves the
  public wrapper as a call from grid: `write_cell_and_update_row_flags` still
  loads `self.style_table` before calling it. Since this fails the default-path
  acceptance criterion, no benchmark or broader reshaping was attempted. The
  experiment was fully reverted, leaving `terminal/style/style_table.mbt`
  unchanged.
- Targeted validation passed:
  - `moon check --target all`;
  - page tests: 10/10 on wasm, wasm-gc, js, and native;
  - grid tests: 16/16 on wasm, wasm-gc, js, and native.
- Native release C inspection passed for the final grid-only state in both
  `plain_lines.c` and `scroll_full.c`: the pooled branch calls `blank_cell`
  once before its indexed loop.
- Survivor wrap/continuation, the dirty pass, and the `descs` in-place blit
  retain their existing ARC. The inline ablation shows that removing those
  operations in isolation is not a net win for `scroll_storm`; the future ring
  storage change must address the whole row-move path instead.
- Full validation passed:
  - `moon test --target all`: 660/660 on wasm, wasm-gc, and native; 682/682 on
    js;
  - `moon test --target native --enable-coverage`: 660/660;
  - `moon fmt`, `moon info`, and `git diff --check`.
- Coverage review:
  - `terminal/grid/grid.mbt` reports seventeen uncovered entries. Four are in
    the touched pooled `Some(cells)` branch at lines 207 and 212-214. The
    branch, loop, and store were already uncovered; the only new executable
    statement is the line-212 blank-cell calculation moved out of that loop.
    The approved write boundary excludes tests, and native generated C directly
    confirms the one-call loop shape. This uncovered branch is accepted for
    this slice and should receive a focused pooled-row regression test when
    test-file scope is opened.
- Public API audit passed: `moon info` produced no
  `terminal/grid/pkg.generated.mbti` diff. Final status contains only the task
  plan and `terminal/grid/grid.mbt`.
- Final four-round paired native medians (`main` immediately followed by this
  worktree each round) are robust to the observed scheduler outliers:
  - `scroll_full`: 5.39 ms -> 5.06 ms (-6.1%);
  - `plain_lines`, `scroll_storm`, and `colored_log` do not exercise pooled-row
    refill in these payloads and remained noise-level controls. Their run means
    include scheduler outliers in both directions, with no repeatable
    change-shaped regression.
- Fresh `scroll_full` profiles agree with that result: `set_blank_row` plus
  `blank_cell` fell from 52 self samples in the 518-sample baseline to 17
  `set_blank_row` samples in the 464-sample final profile, with `blank_cell`
  leaving the top-self list. The next remaining storage cost is still
  reference-array blit (11.6% attributed to `shift_full_width_up`).
- Release benchmark/profile commands still emit the pre-existing Warning
  [0073] in `terminal/build_info_optimize_release.mbt`; this slice neither
  introduced nor modified that file.
