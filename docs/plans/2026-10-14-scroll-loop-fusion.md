# P7.3.5: fuse full-width scroll passes

Status: done. User approved after independently committed P7.3.4.

## Goal, upstream and dependencies

Reduce repeated row mapping and descriptor updates by fusing existing survivor
cleanup with dirty marking in full-width up/down scroll. Depends on d2c1a12f
(P7.3.4), current baseline. Read upstream `src/terminal/Screen.zig`
`cursorScrollAbove`, `cursorScrollAboveRotate`, `cursorDownScroll`;
`Terminal.zig` `index`; `page.zig` `Row`/`Cell`. Upstream marks rotated rows or
pages dirty; retain the existing MoonBit row-level dirty adapter and existing
cleanup semantics. This does not resolve the documented upstream wrap-cleanup
parity question.

## Ownership and exact change

Worker owns grid.mbt `shift_full_width_up`, `shift_full_width_down` and existing
private `set_blank_row` (only those two callers), existing grid_wbtest.mbt, this
subplan and docs/plan.md. Main reviews and integrates an independent commit.
Add dirty to the descriptor already updated after survivor SpacerHead/wrap
cleanup, and to the descriptor of each fresh or pooled blank. Remove both final
region-wide dirty-only loops. No new helpers/models, no print/CSI/history
eviction changes, no API/storage change. Whole scroll remains O(rows + blank
cells); only an extra row pass is removed.

## Acceptance and invariants

Keep cleanup-before-move, source/destination copy direction, origin wrapping,
blank storage ownership and style/link/grapheme/semantic metadata behavior.
Survivors and new blanks are dirty; rows outside a partial-height region remain
unchanged. Tests cover both directions, count one/multiple/full-height,
full/partial regions, wrapped origin, pooled blanks and metadata after cleanup.

## Validation and measurement

Run `moon check --target all`, `moon test --target all`,
`moon test --target native --enable-coverage`, `moon coverage analyze`, caret
review of grid.mbt, `moon fmt`, default-target `moon info`, `git diff --check`.
No touched executable gap may remain unexplained; no mbti change expected.
Inspect generated native C and ARM64 disassembly for removal of dirty-only pass.

Benchmark baseline d2c1a12f in main checkout vs candidate in worker serially.
Four alternating paired rounds select scroll_storm, scroll_full, plain_lines,
wrapped_blob, colored_log, tui_redraw and CJK individually to reduce drift.
Use exact prior primary/alternate lines and printable inputs at 120x80, with
the frozen P7.3.4 variant binary as baseline and a copied harness for candidate.
Retain all noisy raw data; follow up material regressions only with bounded
paired runs. Record repeatable benefit, even if modest.

## Audit

Implementation, validation and paired measurements complete. Pre-existing
ScreenGridState.cell_pool exposure is recorded in P7.3.4 and unchanged here.

Initial `moon check --target all` failed in the new parameterized regression:
expect_row/expect_cell take UInt16 rows, while cell_style/cell_hyperlink take
Int; the test had those conversions reversed. Int.to_uint was also deprecated.
Corrected only those new test calls (`reinterpret_as_uint` for codepoint
markers), then the identical check passed and all 20 grid tests passed on wasm,
wasm-gc, JS and native. No implementation or scope change was needed.

## Correctness audit

Survivor dirty marking is appended after the existing SpacerHead cleanup and
wrap clearing. It reads the current descriptor after `clear_row_range` can
recompute metadata; no stale descriptor overwrites its flag corrections.
Whole-screen origin rotation and partial-height forward/backward copy loops
are unchanged. Every output row is either a moved survivor (already dirty) or
a freshly installed blank (now created dirty), so the final dirty-only pass
is redundant. Outside-region rows are untouched.

The parameterized regression exercises 24 combinations: up/down, full/partial
height, count one/two/entire region, and origins zero/four on a five-row grid.
All rows start clean with text, style, hyperlink, grapheme, semantic prompt,
wrap and trailing SpacerHead data. Assertions check exact survivor source,
cleanup and retained metadata, dirty colored blanks without displaced data,
and unchanged outside rows. A pooled buffer plus multi-row counts cover both
pooled and fresh blank allocation. No new helper or public item is introduced.

## Performance

Apple M3 Max; native release baseline d2c1a12f versus this candidate. Each
workload was selected separately with
`moon bench -p bench/workloads -f workloads_test.mbt -i INDEX --release --target native`,
then baseline/candidate ran adjacently, alternating order over four rounds.
Each result is the median of the four per-round means; each mean has ten
benchmark sample groups. Raw data are all retained.

| Workload | Baseline us | Candidate us | Time change |
|---|---:|---:|---:|
| scroll_storm | 581.940 | 519.660 | -10.70% |
| scroll_full | 3585.000 | 3150.000 | -12.13% |
| plain_lines | 213.105 | 206.465 | -3.12% |
| wrapped_blob | 206.660 | 206.435 | -0.11% |
| colored_log | 253.055 | 246.520 | -2.58% |
| tui_redraw | 752.725 | 746.160 | -0.87% |
| cjk_text | 277.450 | 270.170 | -2.62% |
| mixed_realistic | 435.715 | 422.760 | -2.97% |

Every scroll_storm pair improved (6.6–15.6% lower time), and every scroll_full
pair improved (8.2–12.7%). Controls show no repeatable regression: wrapped_blob
is effectively flat, while one TUI pair had a 32.2% stall and the other three
were slightly faster. No samples were discarded and no further optimization
was added in response to noise.

### Exact long-stream incremental comparison

Same unchanged native harness and byte-identical earlier three-way corpora,
120×80, whole process including input read and deinit, without rendering.
Baseline is the frozen P7.3.4 variant executable; candidate is independently
built against this worktree. Four alternating paired rounds per input, one
warmup and three measured runs per binary per round. The table uses medians
of raw per-round process means, **without startup subtraction**, unlike the
initial broad long-stream table in the P7.3.4 audit.

| Mode / input | Baseline seconds | Candidate seconds | Time change | Throughput change |
|---|---:|---:|---:|---:|
| primary / lines | 0.68255 | 0.66559 | -2.48% | +2.55% |
| primary / printable | 0.51689 | 0.50097 | -3.08% | +3.18% |
| alternate / lines | 0.58386 | 0.54691 | -6.33% | +6.75% |
| alternate / printable | 0.51752 | 0.50269 | -2.86% | +2.95% |

Every one of the sixteen long-input pairs improved. The lower primary-lines
gain includes history and other stream work untouched by this step; the
optimization does not make the complete scroll operation constant time.
Zig/xterm.js were not rerun: these are incremental MoonBit before/after gains.

Raw logs, runner scripts, summary JSON, corpus and binary hashes, frozen
baseline/candidate executables, generated C and ARM64 disassembly are under
worker `.tmp/scroll-fusion/`. The P7.3.4 frozen executable is also retained
under `.tmp/print-inline/`.

## Generated-code audit

Generated C has zero `dirty_idx` mentions in either shift function (six each
before), and each function is 46 C lines shorter. Dirty marking remains in
the existing survivor descriptor update and blank descriptor construction.
ARM64 disassembly confirms the second pass is absent: static instruction
counts are 134 → 112 for up and 131 → 112 for down; these include cold paths
and are not dynamic instruction counts. The origin/copy/blank loops remain.

## Final validation, coverage and public API

- `moon check --target all`: passed.
- `moon test --target all`: passed (668 wasm, 668 wasm-gc, 690 JS, 668 native).
- `moon test --target native --enable-coverage`: passed.
- `moon coverage analyze`: passed; caret grid report reviewed.
- `moon fmt`, default-target `moon info`, `git diff --check`: passed.
- No mbti change or unrelated formatting churn; no new warnings. Release
  benchmarks retain the baseline's existing warning 0073 in
  build_info_optimize_release.mbt; no deprecation warnings remain after the
  initial test-only conversion correction.

Every executable line in the changed survivor/blank functions is covered.
Remaining grid caret gaps at 266, 540, 543, 550, 1500–1513 and 1597 are inherited
absent-link, invalid/grapheme-cursor and hyperlink-copy paths outside the
changed functions; accepted as unrelated coverage debt for this bounded task.
No storage/API change or new public item. The pre-existing cell_pool mutable
Array handle exposure identified during P7.3.4 remains a separately recorded
API debt; this step does not expand it.

Main and an independent reviewer accepted the implementation boundaries,
parameterized regression, paired performance evidence, touched-line coverage,
and unchanged public API before this independent commit.
