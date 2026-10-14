# P7.3.8: consume parser action slots before dispatch

Status: done. Main accepted the reduced ARC with end-to-end timing uncertainty.
All-target checks/tests and native touched-line/site review passed. The user requested
allocation/reference-count optimization with independently measured commits.
The main agent authorized this local lifetime experiment after the explorer
mapped its ownership and ordering constraints. No API/storage change is approved.

## Goal and ownership

Reduce redundant action retains/releases in the existing
`Stream::next_non_utf8` by reading all three `ActionList` slots into local
variables before dispatch. This permits the value list's lifetime to end before
its actions are consumed. Preserve exit, transition, entry dispatch order.

Upstream mapping: `upstream/ghostty/src/terminal/stream.zig::nextNonUtf8`,
lines 709–745, iterates the three ordered actions from `Parser.next`.
`Parser.zig::next/doAction` owns borrowed CSI/Esc/DCS payloads;
`stream.zig::csiDispatch`, `sgr.zig::Parser.next`, and
`stream_terminal.zig::StreamTerminal.vt` explain downstream ownership.

Write boundary: only existing `terminal/stream/stream.mbt::next_non_utf8`,
this subplan, and `docs/plan.md`. Existing stream tests may be extended only
if coverage identifies a meaningful gap. No helpers, types, storage, public
API, unsafe indexing, inline hints, or concurrent SGR changes.

## Baseline and allocation audit

Baseline commit: `50b9ed39`, with the retained P7.3.7 adapter. Reproduced from
the new worker with:

```sh
moon bench -p bench/workloads -f workloads_test.mbt -i 9 --release --target native
```

One baseline run: 5.66 ms ± 88.19 us, 10 × 18 runs. This establishes a working
measurement command, not a comparative performance conclusion. Environment,
raw output, generated black-box benchmark C and executable, and actual `otool`
assembly are saved under `.tmp/action-lifetime/`.

Generated C and actual ARM64 both show two redundant retain/release pairs in
`next_non_utf8`: exit and transition actions are retained while the list is
still live for later slot reads, dispatched, released, then released again
when the list ends. Entry already transfers its ownership. The list itself is
an inline three-pointer value and does not allocate.

For one ordinary single-digit SGR sequence, the hot path allocates a `Csi`
record, an `Action::CsiDispatch` wrapper, and a `StreamSetAttribute` wrapper.
`Option` uses nullable pointers, Bold/Unset are static variants, and the SGR
iterator is reused. Payload-bearing attributes (indexed/direct colors and
Unknown) differ; no blanket allocation count is claimed for them. Removing
the typed-action wrapper requires a separately approved handler boundary;
changing CSI representation would be a storage/API proposal. Neither is part
of this first experiment.

## Invariants and acceptance

- Read only existing immutable action slots; dispatch order remains unchanged.
- Payload arrays remain borrowed until synchronous dispatch completes; no
  parser call or buffer mutation is added between slot extraction and dispatch.
- Generic parser, typed stream events, fallback consumers and APIs are unchanged.
- First inspect generated C and actual ASM. Reject unchanged code generation
  without timing it. If reduced, run focused stream/parser tests before timing.
- Run four alternating tightly paired native release rounds for SGR, query,
  TUI, OSC title/color, APC and print/scroll controls. Preserve all samples.
  Require repeatable target gains and assess any persistent control costs
  explicitly before main acceptance. Do not expand an ineffective candidate.
- If retained, run `moon check --target all`, `moon test --target all`,
  `moon test --target native --enable-coverage`, `moon coverage analyze`, native
  touched-line/site review, `moon fmt`, default `moon info`, and
  `git diff --check`. Verify fresh native traces and source hashes; do not infer
  coverage from an empty caret report alone. No `.mbti` change is intended.
- Stop and report unexpected failures before any scope expansion. Main and
  independent review must approve before a separate Conventional Commit.

## Audit

The approved three-local candidate removes both generated C increfs. Actual
ARM64 `next_non_utf8` falls from 91 to 59 instructions (92 to 60 listing lines
including the symbol label). All three nonempty slots retain their necessary
post-dispatch release; redundant C releases in impossible null branches are
eliminated by clang. No allocation count changes in this candidate.

Focused validation passed: `moon check --target all`, native parser 37/37 and
native stream 70/70. Four paired rounds and one bounded six-pair follow-up are complete. Frozen executables
are invoked with the generated driver's observed argument format,
`workloads_test.mbt:INDEX-END`, preserving exact JSON benchmark summaries;
`run_pairs.py` records baseline-first odd rounds and candidate-first even
rounds. All logs and the complete summaries are retained.

The prior P7.3.7 SGR profile (2,153 pooled samples) attributes 13.66% to
`consume_until_ground <- moonbit_drop_object`, 4.64% to
`csi_dispatch <- moonbit_drop_object`, and 1.16% to
`next_non_utf8 <- moonbit_incref_cycle_free_inlined`. These are sampling
attributions after inlining, not exact per-object costs or a predicted gain.
The generated SGR `set_view` also retains the new backing array and releases
the old one once per sequence. That operation maintains stored view ownership;
removing it would require a separate lifetime/storage design, not this local
slot-extraction change.


## Measured outcome and acceptance decision

The initial repeatable wall-time gain criterion was **not met**. Main accepted
this small local change on the independently verified removal of two redundant
ARC pairs and 32 native instructions, preserved semantics, and low maintenance
complexity. This is an explicit amendment of the original acceptance criterion;
no reliable percentage improvement in end-to-end SGR/TUI throughput is claimed.
Query/plain results do not demonstrate a persistent regression. No further
reruns were used to select favorable results.

Each table entry is the percentage change of median per-invocation means.
These medians are descriptive; they are not confidence intervals. Matched-pair
signs and complete raw statistics are retained for interpreting drift.

| Workload | Initial four pairs | Tight six pairs | Tight pairs faster |
| --- | ---: | ---: | ---: |
| sgr_storm | -5.73% | -1.75% | 3/6 |
| query_storm | +1.06% | +0.24% | 5/6 |
| tui_redraw | -7.42% | -0.10% | 3/6 |
| osc_titles | -5.31% | not repeated | — |
| color_storm | -7.23% | not repeated | — |
| kitty_apc_long | -6.44% | -3.01% | 4/6 |
| plain_lines | +2.01% | -0.78% | 3/6 |
| cjk_text | -1.35% | not repeated | — |
| scroll_full | -4.25% | not repeated | — |

The tight SGR/TUI comparisons each had three faster and three slower pairs.
Query was faster in five of six adjacent pairs although its aggregate medians
show +0.24%, illustrating between-round drift. The first tight APC candidate
was +45.87%, while a TUI baseline stall produced -26.22%; both remain in the
record. Repeated external Chromium and compiler activity was observed in saved
per-round process snapshots. No external process was stopped or modified.

Artifacts: `.tmp/action-lifetime/{samples,tight-samples}.json` contain all raw
benchmark summaries, `{summary,tight-summary}.json` summarize them; original
stdout logs, explicit runner order, per-round host snapshots, executable hashes,
and baseline/candidate C/ASM/binaries are preserved alongside them. This change
reduces reference-count instructions, not the number of action allocations.


## Final validation and coverage

- `moon check --target all`: passed.
- `moon test --target all`: wasm 671, wasm-gc 671, JS 693, native 671 passed.
- `moon test --target native --enable-coverage`: 671 passed; exactly 41 fresh
  native trace files were preserved before analysis.
- `moon coverage analyze`: completed. Isolated native reports use only those
  41 traces and native source maps. The stream source digest matches current
  MD5 `6a207b8312eeab4a1279995ff229df4e`.
- `next_non_utf8` entry and each new slot read (lines 402, 409–411) hit 7,958
  times. Exit/transition/entry dispatch sites (413/416/419) hit 246/2,116/110.
  All changed executable sites are covered by existing tests; no new test
  was needed. JSON proof: `.tmp/action-lifetime/native-touched-line-proof.json`.
- The stream file has 694/695 sites and no completely uncovered executable
  lines. HTML identifies its sole uncovered site as the **unchanged** line 241
  `else { CP_BUF_LEN }` branch, inherited from P7.3.7. This existing chunk-size
  coverage gap is accepted outside this local action lifetime change. Empty
  caret output alone was not treated as proof of full site coverage.
- `moon fmt`, default `moon info`, and `git diff --check`: passed. No `.mbti`
  or unrelated formatting changes. Public API is unchanged.
- Independent source/C/ASM/ownership review passed; final audit review precedes
  the independent `perf(stream)` commit.

Audit tooling correction: after copying the native traces, `moon coverage
analyze` consumed the original `_build/moonbit_coverage_*.txt` files. The first
explicit JSON report still referenced those original paths and failed with
`Sys_error(... No such file or directory)`. It was reported before correction;
the report was rerun against the exact saved trace copies, with no test rerun
or source change. The failed command log and corrected script are preserved.
A documentation-generation Python f-string syntax error likewise wrote no
file; splitting the formatting expression fixed it without changing scope.
