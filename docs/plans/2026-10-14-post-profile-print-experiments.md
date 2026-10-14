# P7.3.6: bounded print hot-path experiments

Status: experiments complete; no implementation retained. Baseline `4752d446`
includes P7.3.4 and P7.3.5. User requested profiling then further optimization.
All three candidates were rejected under their acceptance criteria; this is
a negative-result audit, not a claim of an additional performance improvement.

## Scope, mapping, and invariants

The fresh profile identified plain-text printing as the dominant sampled cost
in the diagnostic workload. The first candidate mapped existing bridge print
to upstream `Terminal.print`; the following two mapped the existing
`ScreenGridState::print_cell` style lookup / `StyleTable::intern` adapter to
upstream `Terminal.printCell` and its default-style behavior.

Each experiment changed only existing symbols and was authorized before its
edit. No new helper/type/API/storage model or compatibility adapter was added.
The first candidate preserved status-display/grapheme early returns. The
second retained style lookup after wide-cell cleanup and hyperlink interning
so style ID allocation and action order were unchanged. The third was only
an inline hint. Every implementation edit was restored after rejection.

## Acceptance and validation methodology

First inspect release generated C and actual ARM64 binary disassembly. Only
candidates with the intended machine-code effect proceed to four tightly
paired native release rounds with alternating order for plain, wrapped,
colored, TUI, CJK, and mixed controls. Preserve all samples. Require repeated
plain improvement and no persistent control regression. Only a surviving
candidate proceeds to unchanged 120x80 primary/alternate printable/SGR long
inputs and full all-target test, native coverage, format, and API gates.

The experiments passed their `moon check --target all` and native release
build commands. None passed the acceptance gate, so long-input/full tests and
coverage were not run for a change that would be discarded. The final diff
contains documentation only and `git diff --check` passes.

Raw artifacts, rejected patches, scripts, logs and summary.json live under
`.tmp/print-argument-arc/`. No samples were discarded.

## Rejected first experiment: argument hoisting

The bridge argument-hoist candidate passed `moon check --target all` and
`moon build bench/plain_lines --target native --release`, but failed the
code-generation acceptance criterion. Normal print still has both grid/cursor
retain/release pairs in generated C and actual `otool -tvV` ARM64 disassembly.
The operations move to immediately before/after `grid.print`; they do not
vanish. Whole function static instruction count changed 130 to 131, not a
reduction. The initial cross-getter lifetime hypothesis was insufficient.
No timing claim is made; this candidate was rejected before benchmarking and
the bridge edit was restored. Frozen baseline/candidate C, binaries, function
excerpts, disassembly and candidate.patch remain under
`.tmp/print-argument-arc/artifacts/`.

## Second candidate: default-style interning guard

Main authorized this exact follow-up after the first code-generation result.
Write boundary now: the existing `ScreenGridState::print_cell` style_id
assignment in `terminal/grid/grid.mbt`, this report and `docs/plan.md`.
Upstream mapping: `Terminal.printCell` uses the cursor style ID and skips
reference-table work for `style.default_id` (Terminal.zig:799–831).
The existing MoonBit StyleTable adapter's `intern(default)` returns
`default_style_id` immediately without modifying last_style/last_id or the map.
Use the existing `CellStyle::is_default` and default_style_id at the call site
so plain cells avoid that function call and table load. Keep the
assignment AFTER wide-cell cleanup, preserving allocation/ID order for all
nondefault styles. No new helper, API, storage or adapter.

Acceptance: generated C AND actual assembly skip `StyleTable::intern` for the
default branch, then the same four paired rounds and full gates listed above.
A surviving implementation would require coverage review of grid/grid.mbt. Raw measurement evidence stays in
`.tmp/print-argument-arc/`; the final name retains the rejected first experiment.


### Default-style guard measurement

Four tightly paired native release rounds alternate baseline/candidate order.
Baseline worktree is `4752d446`. Each invocation is the unchanged
`moon bench -p bench/workloads -f workloads_test.mbt -i INDEX --release --target native`.
All six workloads run serially. Entries below are medians of four reported
run means, in microseconds; negative change means less time. All raw logs,
summary.json, C/ASM and default-guard.patch are preserved.

| Workload | Baseline | Guard | Time change | Faster pairs |
| --- | ---: | ---: | ---: | ---: |
| plain_lines | 209.490 | 202.955 | -3.12% | 4/4 |
| wrapped_blob | 211.930 | 195.860 | -7.58% | 4/4 |
| colored_log | 251.510 | 254.185 | +1.06% | 0/4 |
| tui_redraw | 765.750 | 775.625 | +1.29% | 1/4 |
| cjk_text | 267.245 | 263.565 | -1.38% | 4/4 |
| mixed_realistic | 432.745 | 417.380 | -3.55% | 4/4 |

Guard rejected under the acceptance criterion: plain improves, but colored_log
slows consistently. It adds a repeated default-style predicate on nondefault
writes. TUI has a small overall regression with one faster round; no claim of
a universal TUI slowdown is justified. The unusually slow second wrapped
baseline is retained. Long-input and final implementation gates were not run
for this rejected candidate.

## Third candidate: inline the existing style interning function

Main authorized replacing the rejected guard with `#inline` on the existing
`StyleTable::intern` in `terminal/style/style_table.mbt`. Both prior code edits
are restored. This is the only implementation edit. Upstream mapping remains
Terminal.printCell style lookup plus the existing StyleTable adapter; all
interning semantics and signatures stay unchanged. No helper/API/storage
change. Check the actual binary to determine whether the hint is honored and
avoids a duplicate nondefault predicate before any benchmarks. If ignored,
reject immediately. If effective, repeat the same four paired workloads,
long-input tests, and full gates; coverage audit applies to style_table.mbt.

### Inline-hint result

`moon check --target all` and the native release build passed. Both generated
C and actual native assembly still call `StyleTable::intern` from print_cell.
Baseline and inline candidate print_cell have the same 255 generated C lines
and 166 ARM64 instructions; their disassembly is identical after normalizing
addresses. The compiler did not honor this hint at the relevant call site.
No benchmark was run and the hint was restored. Evidence is in
`artifacts/inline/`, `inline.patch`, and `inline-assembly-comparison.txt`.

Existing production call sites are print_cell, clear_row_range, and
blank-cell creation in `terminal/grid/grid.mbt`. Existing StyleTable tests
exercise pre-seeded ID 0, default reinterning without growth, new styles,
nondefault cache hits, and ID round trips. No API or test changes remain.

## Conclusion

Argument ordering and an inline hint do not remove the measured work with this
compiler. An outer default-style guard does improve plain text but adds a
consistent colored-text regression, so it is not retained. Broader optimization
must be designed and measured separately rather than stretching this result.
