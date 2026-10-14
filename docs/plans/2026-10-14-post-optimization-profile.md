# Post-optimization profile (2026-10-14)

## Goal and scope

Read-only diagnostic follow-up to completed P7.3.5 at commit
4752d44684b0254b1f379294cd14eb5fffb7f0e5 (PR #62). Re-sample the optimized native
release implementation, rank remaining bottlenecks, and identify a bounded
faithful next experiment. No implementation, API, or storage edits are owned
by this profiling task.

## Sources, targets, and dependencies

Upstream: `src/terminal/Terminal.zig`, `Screen.zig`, `PageList.zig`, `page.zig`,
`Parser.zig`, `stream.zig`, `sgr.zig`. MoonBit: `terminal/grid/grid.mbt`,
`terminal/page/cell.mbt`, `terminal/pagelist/pagelist.mbt`,
`terminal/stream_terminal_bridge.mbt`, `terminal/parser`, `terminal/stream`,
`terminal/sgr`, and the existing `bench/workloads` entry points. Depends on
P7.3.4 print fusion and P7.3.5 scroll-pass fusion. Preserve existing module
boundaries, action ordering, scroll cleanup and ownership contracts.

## Delegation and acceptance

Profiling explorer owns this document and ignored
`.tmp/post-optimization-profile/` only. Main reviews the evidence and chooses
the implementation boundary. Run profiles serially without competing benchmark
work, retain raw outputs and generated C, report sample counts and self versus
inclusive attribution, and distinguish measured costs from optimization
hypotheses. No public API changes; source coverage gates apply to any later
implementation, not this read-only audit.

## Validation commands

Three repeated runs of each:

- `moon run bench/plain_lines --release --target native --profile`
- `moon run bench/scroll_full --release --target native --profile`
- `moon run bench/sgr_storm --release --target native --profile`

Inspect emitted native C for the dominant sampled functions. Review final
`git diff --check` and status for accidental implementation/interface changes.
These use fresh 80x24 terminals, not the three-way comparison's long-lived
120x80 terminal. Repeated traces improve sampling confidence but do not measure
an optimization's speedup or establish the exact long-input cost distribution.

## Audit notes

All nine profile commands passed. Raw JSON, XML, stdout, command logs,
per-trace metadata, pooled rankings, and current generated C are retained in the
ignored artifact directory above. The prior stdin-based long-stream xctrace harness
blocked awaiting stdin; this task does not repeat that invalid measurement.


## Repeated profile findings

Counts are summed over three serial traces; percentages are sample-weighted,
not an average of rounded percentages. Each sample represents approximately
1 ms. Self and inclusive costs overlap and must not be added. There is no
single cross-workload largest bottleneck without a representative workload mix.

| Workload | Three sample counts | Total | Leading self costs | Selected inclusive cost |
|---|---|---:|---|---|
| plain_lines | 331, 317, 328 | 976 | print_cell 29.4%; grid.print 12.7%; bridge.print 7.7%; codepoint_width 6.6%; cursor_mark_dirty 4.1% | grid.print 45.4%; bridge.print 58.5% |
| scroll_full | 285, 299, 248 | 832 | drop_object 17.7%; shift_full_width_up 15.7%; set_blank_row 10.0%; mi_malloc 6.6% | shift_full_width_up 30.3%; capture_top_scroll_region_up 28.8% |
| sgr_storm | 821, 820, 851 | 2492 | drop_object 14.8%; Parser.do_action 13.2%; Parser.next 12.1%; SgrParser.next 11.5%; transition_for 5.8% | Parser.next 27.7%; csi_dispatch 28.8% |

`plain_lines` still spends most parsing time on per-character terminal writes.
The fused print_cell is now the largest individual source function, so its
larger self percentage must not be mistaken for a regression: it absorbed the
removed helper. This diagnostic also spends about 10.2% in initial resize,
which the long-lived throughput harness amortizes away.

`scroll_full` still pays for survivor cleanup plus blank-row refill and the
history row allocation/release lifecycle. The earlier pass fusion did not make
the operation O(1). The fresh-terminal workload also includes history disposal;
its total destructor cost is not all steady-state scroll eviction.

`sgr_storm` barely prints text and stresses a different bottleneck: generic
byte-state parsing, semantic SGR decoding, and temporary action allocation.
Optimizing printing alone cannot improve this case substantially.

## Runtime attribution and generated-code audit

Current emitted C is saved as `plain_lines.c`, with focused function excerpts.
C establishes object lifetimes and calls before clang; it does not establish
that a call survives native optimization. In particular, the separate explorer
verified that PageCellState's constructor is already inlined in current ARM64
machine code. Do not propose another constructor-inline change based on C alone.

- `bridge-print.c` loads grid and cursor before calling `active_hyperlink` and
  `ModeState.get`; it emits one retain/release pair for each receiver on the
  positive-width printing path. The paired source-only candidate is to evaluate
  these pure arguments first, then load/pass receivers. Runtime leaf samples
  attributed to the enclosing `StreamHandler.print` are 2.2% incref and 1.5%
  decref. These are caller attribution after native inlining, not a clean
  isolated measurement of those four operations; they do not promise a 3.7%
  speedup. The combined bridge's 7.7% self likewise includes other work.
- `print-cell.c` already avoids retaining its row array across style interning,
  guards absent hyperlink lookup, and updates row flags in the fused body.
  `StyleTable.intern` still runs per character, but its default fast path is
  small; an outer guard may duplicate comparisons on colored text. This is a
  measured-candidate option, not automatically a win. Broader row/flag fusion
  needs the upstream ordering audit before implementation.
- `scroll-up.c` confirms the former final region-wide dirty pass is gone;
  surviving rows still require trailing-cell and metadata work. Retaining
  existing wrap and SpacerHead semantics is part of the approved adapter.
- `make-pinned-row.c` confirms three singleton arrays plus PageListPage and
  PageListRow allocations, with PageListNode creation through its constructor.
  The history path still has multiple small objects per harvested row even
  though its cell buffer is transferred/recycled. Runtime leaf costs include
  capture -> drop_object 3.4%, make_pinned_row_owned -> malloc 2.3%, and
  harvest_scrollback_row -> malloc 2.0%. Grouped pages or node reuse would
  change storage/pin ownership and require a separate approved design.
- `parser-next.c` calls general `transition_for` and `do_action`; the latter
  allocates Csi and CsiDispatch separately. `ActionList` remains a value-shaped
  carrier, so converting it again is not a useful proposal. Runtime leaf
  consume_until_ground -> drop_object accounts for 11.6% of SGR samples and
  csi_dispatch -> drop_object for 3.3%. These native caller buckets may include
  inlined descendants; do not attribute all 11.6% to the BytesView destructor
  merely because the C excerpt also contains a view release.
- Upstream `stream.zig::nextNonUtf8` lines 649–700 has ESC-to-CSI and CSI parameter
  fast paths. Current `Stream::next_non_utf8` unconditionally calls Parser.next.
  Reintroducing them through an opaque parser-owned entry point is a larger
  likely SGR opportunity, but its new cross-package compatibility adapter needs
  to be recorded/approved before editing; do not expose mutable parser state.

## Next bounded experiment

Start with `StreamTerminalBridgeState::print` argument lifetime shortening:
source owner upstream `Terminal.print` / `stream_terminal.Handler`, MoonBit
`terminal/stream_terminal_bridge.mbt:1283`. This preserves storage, public API,
helpers and action ordering, and targets a bounded part of the dominant plain-text printing path with a
suspected ARC mechanism. The bridge is 7.7% self versus print_cell at
29.4%; this choice is not a claim that bridge ARC is the biggest absolute
remaining opportunity. It is a small
experiment, not a forecast that it can close the roughly twofold historical
throughput gap. Verify generated C and native assembly remove the pairs, then
paired release measurements across plain, wrapped, colored, scroll and Unicode
controls plus the existing long-input harness. Keep only repeatable gains.

CSI fast paths and history allocation deserve separate design/measurement
steps if the remaining gap persists. Do not rank their expected speedup by
comparing percentages from these different synthetic workloads.

## Validation and limits

Each workload's stdout checksum matched across all three runs: plain_lines
435000 (1500 iterations, 14600-byte payload); scroll_full 808160 (80 iterations,
40000-byte payload); sgr_storm 0 (120 iterations, 400000-byte payload). The SGR
checksum is only an optimization anchor, not a semantic equivalence test.
Profiler quality notes report 1–3 running samples without retained profile
symbols and occasionally one unresolved stack per trace; these samples are
excluded from the table denominator. Outlined/deduplicated native symbols
remain in the raw report and are not reassigned speculatively.

No implementation or generated interface files changed. `git diff --check`
passed. No tests/coverage were rerun for this read-only audit; the selected
implementation must perform the full repository gate, touched-line coverage
review, and public API review before commit.

## Follow-up experiment result

Argument hoisting was tested and rejected: the normal print branch retains the
same grid/cursor incref/decref pairs in both generated C and ARM64 assembly;
they move adjacent to grid.print instead of disappearing. The getter-lifetime
hypothesis alone is therefore insufficient. No performance gain is claimed.
The next bounded candidate is an outer default-style guard in the existing
print_cell style lookup; details and acceptance are recorded in
[the P7.3.6 experiment audit](2026-10-14-post-profile-print-experiments.md).

The default-style guard was also rejected: four paired runs consistently
improved plain text (median -3.12% time) but slowed colored_log (+1.06%, all
four pairs slower). An inline hint on the existing intern function did not
change the relevant native call or instruction count. No implementation from
these three bounded experiments is retained; the audit preserves negative
results and raw samples.
