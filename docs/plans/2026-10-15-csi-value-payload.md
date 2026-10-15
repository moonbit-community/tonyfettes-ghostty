# P7.3.10 — CSI dispatch payload as a value

## Goal and authorization

The active execution plan is `docs/plan.md`, step P7.3.10, following P7.3.9.
The user requested parser-stack performance work and explicitly permits public
API changes. This bounded experiment applies `#valtype` to the existing `Csi`
record, matching upstream's by-value `Parser.Action.CSI`. It changes no fields,
accumulator storage, parser state, ordering, or borrowed-view lifetime.

## Upstream sources and MoonBit targets

- `upstream/ghostty/src/terminal/Parser.zig`: `Action.CSI`, `next`, and
  `doAction` (especially `.csi_dispatch` construction).
- `upstream/ghostty/src/terminal/stream.zig`: `nextNonUtf8` and `csiDispatch`.
- `upstream/ghostty/src/terminal/sgr.zig`: `Parser.next`, synchronous parameter
  consumption.
- Implementation: `terminal/parser/parser.mbt`, existing `Csi` declaration and
  its ownership/representation documentation only.
- Public representation follow-up: `terminal/seplist/seplist.mbt`, existing
  `SepList` declaration and documentation only; upstream mapping remains
  `Parser.Action.CSI.SepList = std.StaticBitSet(MAX_PARAMS)`.
- Generated public signatures: `terminal/parser/pkg.generated.mbti` and
  `terminal/seplist/pkg.generated.mbti`.
- Existing parser/stream tests may change only if review identifies a meaningful
  behavior or ownership gap. No new production helpers, models, or adapters.

The upstream submodule is read from the main checkout; the worker checkout
contains the same baseline source at `86da0bc` and has separate build outputs.

## Dependencies and invariants

- P7.3.7's `Parser.next_stream` adapter and P7.3.8's ordered action-slot
  consumption remain unchanged.
- The prior `Csi #valtype` feasibility attempt was blocked by abstract `SepList`.
  `SepList` is now an unboxed `UInt64` newtype; current compiler feasibility is
  checked before the experiment proceeds.
- `Action`/`ActionList`/`Esc`/`Dcs` stay unchanged. `CsiDispatch` keeps its enum
  allocation; only the separate `Csi` heap object is expected to disappear.
- The two ArrayView backing buffers remain retained during dispatch and remain
  borrowed from the parser. Copying a Csi value does not snapshot parameters.
- Unknown SGR and DCS hook payloads retain their existing owned-copy boundaries.
- No changes to mutable field visibility or existing API methods are allowed.

## Acceptance criteria

1. All-target compilation accepts `#valtype Csi`; generated native C and ARM64
   assembly show no separate Csi allocation and one remaining CsiDispatch box.
2. Borrowed views retain correct ownership; generic-parser differential,
   chunk-boundary, Unknown SGR persistence, and DCS ownership tests pass.
3. Paired release measurements by the integrating agent compare frozen baseline
   and candidate binaries, including CSI-heavy workloads and non-CSI controls.
4. Full gates pass; touched-site coverage, formatting, and the generated public
   API diff are reviewed before commit. Existing unjustified public surface is
   explicitly noted.

## Validation commands

- `moon check --target all`
- `moon bench -p bench/workloads --release --target native --build-only`
- `moon test --target all`
- `moon test --target native --enable-coverage`
- `moon coverage analyze`
- Native coverage inspection for `terminal/parser/parser.mbt` and
  `terminal/seplist/seplist.mbt`
- `moon fmt`
- `moon info`
- `git diff --check`
- Generated native C and ARM64 code inspection; frozen paired release
  benchmarking is owned by the integrating agent to avoid competing workloads.

## Audit and validation results

- Initial `moon check --target all` failed on 2026-10-15 with compiler E4173 at
  `terminal/parser/parser.mbt:27:16`, the `params_sep : @seplist.SepList` field:
  “Value type is not allowed for using abstract type as field type.”
- Toolchain: moon 0.1.20261012 / moonc v0.10.15+943464bfa (2026-10-12).
- The historical abstract-field restriction still applies even though SepList
  is already an unboxed UInt64 newtype. No codegen/build/performance result is
  available for this initial candidate.
- The worker stopped before expanding scope. A proposed follow-up is changing
  the existing SepList declaration to `pub struct SepList(UInt64)` (read-only
  public representation), then retrying Csi value representation. This adds no
  helper or adapter, but exposes a previously abstract public type's immutable
  representation and needs a revised approved boundary.
- Managed-worktree writes/builds require scoped sandbox escalation; that was
  granted and is not the compiler blocker.

- After the initial failure report, the integrating agent authorized the
  bounded follow-up under the user's explicit permission to adjust public API,
  and announced the exact E4173 limitation and proposed representation to the
  user. The approved shape is `pub struct SepList(UInt64)`: externally readable
  immutable representation, no `pub(all)`, no added constructor or method, and
  no mutable fields. The external consumer story is CSI/SGR separator metadata
  transport, while existing `init_empty`/`set`/`is_set`/`count` remain the
  construction and behavior interface. This is the upstream bitset's existing
  representation, not an additional compatibility adapter.

### Compiler, code generation, and focused validation

- The approved `pub struct SepList(UInt64)` retry passes `moon check --target
  all` (193 tasks).
- `moon bench -p bench/workloads --release --target native --build-only` passes.
  Its only diagnostic is the pre-existing unnecessary `OptimizeMode::`
  annotation in `terminal/build_info_optimize_release.mbt:3`.
- Generated native C declares Csi as a 48-byte value containing two 16-byte
  views, an inline UInt64 separator word, and final-byte/padding. CsiDispatch
  embeds that value directly. Its CSI constructor retains both backing buffers,
  creates the Csi value locally, and allocates CsiDispatch once. The object
  layout descriptor traces both nested backing-buffer pointers.
- ARM64 disassembly of `Parser.next_stream` confirms one 56-byte allocator
  request including the header on the accepted-CSI branch, replacing baseline
  requests of 56 bytes (Csi) plus 16 bytes (CsiDispatch). This saves exactly one
  allocation, one object drop, and 16 requested bytes per accepted CSI. The
  dispatch wrapper allocation remains; this is not allocation-free CSI parsing.
- `ActionList` remains its existing three-word value with three ordered Action
  slots; `Action`, `Esc`, and `Dcs` representations are unchanged.
- Independent source/C/ARM64 review confirms the allocation reduction and
  ownership. It also identifies an ABI cost: `dispatch_action` grows its stack
  frame from 0x30 to 0x60 bytes and copies the 48-byte CSI value with q-register
  loads/stores. `next_non_utf8` assembly is unchanged. Allocation removal alone
  is not a claim that every instruction or workload improves; paired timing
  determines the net result.
- A focused invocation initially used historical nonexistent paths
  `terminal/stream_test.mbt` and `terminal/stream_wbtest.mbt`; Moon failed before
  running tests while canonicalizing the first path. The command/path failure
  was reported, the actual package paths were inspected, and the corrected
  `moon test --target native terminal/parser terminal/stream` passes 109/109.
- Existing tests cover generic/stream parser differential for all 14 reachable
  states and all 256 following bytes, mixed separators and parameter caps,
  every chunk split, retained Unknown SGR slices for default and typed handlers,
  and stored DCS hook lifecycle payloads. No new executable branches or testing
  gaps were introduced, so no redundant tests were added.

### Public API audit

- `moon info` completed. The only generated signature change is
  `type SepList` to `pub struct SepList(UInt64)`; its methods are unchanged.
  The parser interface does not serialize `#valtype`, so its generated file has
  no textual diff. Csi fields and constructor availability remain unchanged.
- SepList's immutable backing word is externally readable for CSI/SGR metadata
  transport, while construction remains private to the package. No public
  mutable field, new method, helper model, or adapter was added.
- Parser state and accumulators remain abstract. ActionList continues to expose
  only its ordered accessors. Existing read-only Csi/Esc/Dcs payload fields have
  their parser-to-stream consumer story; their mutable backing storage still
  obeys the documented synchronous borrowing contract.
- Pre-existing API debt: `Parser.reset_ground` has only a fresh-Ground setup
  caller in `terminal/stream/stream_wbtest.mbt`, with no production consumer.
  Remove or restrict that exposure in a separate API-cleanup task; this scoped
  performance change does not add a new use or widen it.
- Pre-existing construction exposure: Csi/Esc/Dcs are `pub(all)` although their
  demonstrated external consumer reads parser outputs. That construction
  surface is broader than required by those reads. It remains unchanged here;
  review read-only output records in a separate API-cleanup task.

### Paired native release measurements

The integrating agent measured frozen baseline and candidate executables on
native ARM64 with moon 0.1.20261012 / moonc v0.10.15+943464bfa. Every workload
invocation processes a fresh 80×24 terminal through `Workload.process`. Four
rounds alternate baseline/candidate order within each workload pair; all 96
samples are retained. The table uses the median of each version's four means;
negative elapsed-time change is faster. No worker build or test competed with
the timed runs. This establishes performance for these native 80×24 benchmark
workloads only: no long-lived-session or JavaScript/WebAssembly speedup is
claimed. No previous long-running-session harness was available in this
checkout.

| Workload | Baseline (µs) | Candidate (µs) | Time change | Faster pairs |
| --- | ---: | ---: | ---: | ---: |
| sgr_storm | 4924.65 | 4392.54 | -10.81% | 4/4 |
| tui_redraw | 708.08 | 673.55 | -4.88% | 4/4 |
| query_storm | 6589.16 | 6235.70 | -5.36% | 4/4 |
| colored_log | 232.40 | 225.38 | -3.02% | 4/4 |
| plain_lines | 228.81 | 227.37 | -0.63% | 2/4 |
| wrapped_blob | 226.25 | 227.42 | +0.52% | 1/4 |
| cjk_text | 279.84 | 281.11 | +0.45% | 0/4 |
| scroll_full | 3312.10 | 3301.63 | -0.32% | 4/4 |
| osc_titles | 248.37 | 249.89 | +0.61% | 1/4 |
| color_storm | 16158.62 | 16259.08 | +0.62% | 1/4 |
| kitty_apc_long | 2041.34 | 2056.38 | +0.74% | 1/4 |
| mixed_realistic | 416.48 | 411.45 | -1.21% | 4/4 |

The main agent accepts the repeatable CSI-heavy gains with the observed small
control costs: wrapped, CJK, OSC title, OSC color, and APC medians increased by
0.45–0.74%. This is an explicit tradeoff, not a zero-regression claim. CJK was
slower in all four pairs, and the other listed controls were slower in three.
The measured benefit is local to this candidate; no gains from earlier work
are included. Raw logs, runner, binaries, source code, all samples, and summary
are retained in the integrating checkout's `.tmp/csi-value/`.

### Final validation and coverage

- `moon check --target all` passes.
- `moon test --target all` passes: wasm 674, wasm-gc 674, JavaScript 696,
  native 674. Only pre-existing libtool warnings about empty platform stubs
  appeared.
- `moon test --target native --enable-coverage` passes 674/674. Exactly 41
  fresh native traces and 122 native source maps were copied before analysis.
- `moon coverage analyze` passes. Isolated Coveralls JSON, HTML, caret, and
  summary reports were generated against the saved native maps/traces only.
  The whole-workspace analysis includes pre-existing uncovered benchmark,
  example, and unrelated production lines; this is not a whole-repo coverage
  completion claim.
- Touched-file source digests match current content: parser
  `d8ef9eb1b1802ae2d161873c3c0c2bc5`, SepList
  `40cd5e9c302fd836a3eae581ef57966b`. Native site coverage is 158/158 in
  `terminal/parser/parser.mbt` and 5/5 in `terminal/seplist/seplist.mbt`.
  There are no uncovered executable sites in either touched file. Changes are
  declaration annotations/visibility and comments, with no new executable
  line. The two existing CSI construction branches (lines 248 and 397) hit
  4,842 and 4,104 times; SepList's init/set/is_set/count lines (19/24/29/36)
  hit 30,984/351/762/811. The JSON/source-digest and HTML site-count proof is
  saved in `.tmp/csi-value/native-touched-line-proof.json`; an empty caret
  report alone was not treated as proof.
- `moon fmt`, `moon info`, and `git diff --check` pass. No unrelated formatting
  or generated-interface churn occurred. The final source/API diff is exactly
  Csi's value annotation/docs, SepList's read-only representation/docs, and its
  generated signature.
- Independent source/C/ARM64/ownership/API review found no blocking issue.
  Existing API debt and the measured control costs are recorded above.

Status: complete. Main reviewed the source/API diff and independently checked
both source digests and CSI construction counts in the native report.
Worker coverage artifacts are preserved in the integrating checkout at
`.tmp/csi-value/worker/`, alongside the paired benchmark evidence. The current
roadmap records completion. Implementation, API, audit and roadmap status form
one atomic performance step.
