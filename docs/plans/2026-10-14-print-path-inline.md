# P7.3.4: print-path call reduction

Status: done. User approved this first step before scroll-loop merging.

## Goal and boundaries

Reduce existing-function call and repeated descriptor overhead in the native
print hot path. No new helper, storage model, public API, CSI or scroll change.
Worker owns `terminal/grid/grid.mbt` print functions and existing function
annotations in `terminal/page/cell.mbt`; main reviews before an atomic commit.

## Upstream and dependency map

- `upstream/ghostty/src/terminal/Terminal.zig`: `print` narrow-cell
  `@call(.always_inline, printCell, ...)`, `printCell` writes and flag updates.
- `upstream/ghostty/src/terminal/Screen.zig`: `cursorMarkDirty` and cursor
  movement; `upstream/ghostty/src/terminal/page.zig`: `Cell`/`Row` packed fields.
- Final targets: existing grid `print_cell`, its removed sole-caller
  `write_cell_and_update_row_flags` helper, `apply_row_prompt`, and page
  `PageRowState::record_cell_write`; behavioral coverage in grid_wbtest.mbt.
  Constructor/packing and cursor-dirty annotations were explored but removed
  after their generated calls remained. Existing packing/flag adapters retained.
- Depends on P7.3.3 and the 2026-10-14 hotpath investigation.

## Invariants and acceptance

Keep pending-wrap/insert/margin checks, cursor movement, wide-cell cleanup,
semantic prompt, style/hyperlink interning, lost-grapheme/style/link rescans,
dirty flags and all action ordering identical. The body merge, enum tag test
and inlining attribute preserve behavior. Review pre-existing API.
Retain changes only with repeatable measured gains.

## Validation and measurement

Run `moon check --target all`, `moon test --target all`,
`moon test --target native --enable-coverage`, `moon coverage analyze`,
`moon coverage analyze -- -f caret -F terminal/grid/grid.mbt` (and cell.mbt),
`moon fmt`, default-target `moon info`, and `git diff --check`. Review touched
executable coverage and mbti output. Inspect generated release C/assembly.
Compare baseline 23bb4548 to this worktree with four serial paired rounds of
`moon bench -p bench/workloads --release --target native`, alternating order.
Report median per-round mean and paired changes. Reuse exact primary/alternate
long-stream inputs from the earlier three-way harness for a successful variant.

## Audit

The initial six-annotation pilot produced no convincing plain/wrapped gain.
Generated C kept the grid helper and constructor calls; those ineffective
annotations were removed. The candidate instead moves the write/flag body
into its sole caller `print_cell`, retaining the exact order of cleanup,
old-flag capture, hyperlink/style interning, cell store, optional link store,
rescan and descriptor update. The former helper is removed. This matches the
upstream single `printCell` owner and adds no helper or adapter.

`apply_row_prompt` tests the None tag using a pattern instead of derived enum
equality. `PageRowState::record_cell_write` keeps its effective `#inline`;
generated C confirms the packed flag operations replace the call. No dirty
write moves across cleanup or printing.

All paired measurements, validation and coverage review completed; main boundary
review accepted the source and regression test before commit.


## Public API review

No signatures or public mutable fields are added; the removed write helper was
private. `PageRowState::record_cell_write` serves grid writes across the package
boundary, so its public method has a current consumer. Existing opaque cell/row
values remain opaque. Reviewer identified pre-existing API debt: readable
`ScreenGridState.cell_pool` exposes a mutable Array handle despite grid-local
consumers only. Privatizing it would change the existing API and is outside this
explicitly API-preserving performance step; track separately. Other existing
shared grid arrays have cross-package PageList/Screen consumers.

## Existing behavior tests retained

The existing grid suite checks printed metadata and dirty/prompt flags, wide
wrap and one-column fallback, pending-wrap/insert/margin edges, prior Wide and
SpacerTail cleanup including previous-row SpacerHead, and row-flag rescans.
Caret coverage found the inherited lost-metadata rescan branch untested. Added
`screen grid/print overwrite rescans lost row metadata` in `grid_wbtest.mbt`: it
independently overwrites style, hyperlink and grapheme contributors, verifying
that another cell keeps the corresponding row flag set until the final
contributor is overwritten. This directly tests the existing rescan contract.

## Performance results

Apple M3 Max, native release; baseline `23bb4548`, candidate source unchanged
through all performance runs. Four complete alternating baseline/variant rounds
ran `moon bench -p bench/workloads --release --target native`; each reported
mean includes the benchmark's 10 sample groups. Table uses median of the four
per-round means, in microseconds (lower is better). All rounds are retained.

The host had substantial intermittent unrelated CPU activity. For example,
plain-lines variant round 3 was 461.71 us instead of its usual 209–217 us,
and baseline round 4 was about 701 us instead of about 235 us. These are noisy
end-to-end observations, not reliable precision estimates of individual wins.

| Workload | Baseline us | Candidate us | Time change |
|---|---:|---:|---:|
| plain_lines | 239.60 | 212.18 | -11.45% |
| wrapped_blob | 255.60 | 215.20 | -15.81% |
| scroll_storm | 661.48 | 599.06 | -9.44% |
| scroll_full | 4050.00 | 3730.00 | -7.90% |
| colored_log | 259.60 | 275.57 | +6.15% |
| tui_redraw | 811.28 | 737.71 | -9.07% |
| cjk_text | 293.01 | 278.57 | -4.93% |
| mixed_realistic | 492.24 | 447.94 | -9.00% |

Because the initial colored-log median regressed, a separate bounded follow-up
alternated baseline/candidate closely for six rounds of colored_log and
plain_lines, selecting each benchmark with `-f workloads_test.mbt -i 4` /
`-i 0`. The original data were not discarded. Colored_log improved in all six
pairs: median **265.72 → 256.285 us (-3.55%)**. Plain_lines median was
**238.32 → 219.425 us (-7.93%)**, with one candidate stall retained. These
confirm the print gain without treating the original colored-log regression
as noise without evidence.

### Exact earlier three-way inputs

Copied the original native harness unchanged into two independent workspaces,
one depending on baseline and one on candidate; preserved separate binaries.
Input SHA-256 values and binary hashes are saved with the raw results. Geometry
120×80, same primary/alternate .bin files as the earlier three-way retest,
whole process (read + parse + buffer update + deinit, no rendering).
For each of four alternating rounds, hyperfine used two warmups and four
measured runs per binary/input; tiny startup baselines used eight runs.
Table throughput is input MB divided by the median per-round mean after
subtracting that round's tiny baseline. Neither Zig nor xterm.js was rerun in
this implementation step; this measures incremental MoonBit benefit only.

| Mode / input | Baseline MB/s | Candidate MB/s | Throughput change |
|---|---:|---:|---:|
| primary / printable | 56.59 | 65.81 | +16.30% |
| primary / lines | 38.22 | 40.94 | +7.12% |
| primary / sgr | 59.32 | 62.61 | +5.55% |
| primary / cursor | 56.65 | 67.69 | +19.50% |
| alternate / printable | 61.60 | 70.28 | +14.09% |
| alternate / lines | 55.49 | 58.40 | +5.24% |
| alternate / sgr | 55.18 | 48.22 | -12.61% |
| alternate / cursor | 42.89 | 62.92 | +46.72% |

The large cursor gains and apparent alternate-SGR regression are affected by
host stalls. Alternate SGR's four baseline means were 0.524/0.702/1.021/0.524 s
and candidate means 0.502/0.900/1.699/0.504 s. To resolve the regression, a
second bounded six-round follow-up tightly paired alternate SGR and printable
(one warmup, three measured runs each, alternating order, frozen binaries).
SGR improved in four of six pairs; median raw total process time improved **4.38%** (typical baseline 0.52–0.53 s versus
candidate 0.50–0.51 s). This follow-up uses raw process times, without subtracting
startup, unlike the preceding table. Printable median improved **14.07%**, with all six
printable pairs improved. One SGR host stall remained and is retained.
Do not interpret the noisy broad-run percentages as precise expected speedups.
The repeated plain/colored gains and long-input follow-ups support retaining
the bounded change; they do not imply every workload improves by one number.

Raw logs, scripts, summaries, input hashes, frozen baseline/candidate benchmark
and long-stream binaries, generated C and disassembly are in the worker's
`.tmp/print-inline/` (untracked measurement artifacts).

## Generated-code audit

The final generated native C removes `write_cell_and_update_row_flags` and
`record_cell_write` calls; the old-cell and physical-row scalars stay within
`print_cell`. ARM64 disassembly confirms the baseline print_cell called the
write helper; the candidate contains the write directly. Static function
instructions go from 125 in print_cell + 106 in the write helper to 166 in
combined print_cell (including cold branches, not a dynamic instruction count).
The remaining hyperlink/style intern, wide cleanup, optional link store and
rescan calls remain. `apply_row_prompt` becomes a direct tag test in generated C,
but its final ARM64 instructions are identical to baseline; no independent
runtime gain is attributed to that source simplification.

## Final validation and coverage

- `moon check --target all`: passed.
- `moon test --target all`: passed; 667 wasm, 667 wasm-gc, 689 JS, 667 native.
- `moon test --target native --enable-coverage`: passed.
- `moon coverage analyze`: passed; caret reports reviewed after the new test.
- `moon fmt`, default-target `moon info`, `git diff --check`: passed. No mbti
  change and no unrelated formatting churn. Release measurement builds retain
  the baseline's existing warning 0073 in build_info_optimize_release.mbt; no
  deprecation warning or new warning introduced.

All executable lines in the moved print body, changed prompt guard, and
annotated row-write function are covered. Remaining grid caret gaps at
266, 537, 540, 547, 1511–1524 and 1608 are inherited unrelated absent-link,
invalid/grapheme-cursor and hyperlink-copy paths. Remaining cell gaps at
267, 306, 318, 320, 334 and 444 are inherited semantic/flag/empty-grapheme
constructor branches. None is a newly changed executable line; they are
acceptable deferred coverage debt for this API-preserving print-only step.
Main reviewed the boundary, coverage, public API, and new regression.
