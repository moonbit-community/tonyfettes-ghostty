# P7.3.9: typed SGR handler dispatch

Status: done. The user approved the public trait compatibility adapter and
package-private bridge method before implementation. Source/API review and all
quality gates passed. Main accepted the measured SGR/TUI gains with the small
observed APC cost described below.

The immediate benchmark baseline is P7.3.8 commit `9a4219fb`. Its action-slot
lifetime changes are excluded from this step's independent performance claim.
The original approved plan was
`docs/plans/2026-10-14-sgr-handler-fast-path-proposal.md`; this file replaces it
with the completed audit. The unchanged approval text is preserved in the PR
worktree's `.tmp/sgr-handler-fast-path/original-approved-proposal.md`.

## Final result

The terminal handler now receives SGR attributes through a typed method. Its
native dispatch removes one 16-byte allocator request (including header) and
corresponding wrapper drop per emitted attribute. Existing handlers inherit a
default that still delivers the same StreamSetAttribute events. Csi,
CsiDispatch, attribute payloads, and SGR parser storage are unchanged.

Four independent paired native release rounds show SGR faster in all four
pairs (median time -13.72%) and TUI faster in all four (-5.40%). The exact long
alternate-screen SGR corpus is also faster in all four pairs (-2.14% wall time,
-2.26% user+system CPU time). APC medians show +0.34% in the first four pairs
and +0.37% in the bounded six-pair follow-up. Main explicitly accepted this
small observed cost; these figures do not establish statistical significance
or zero regression. All samples and outliers are retained.

The approved design and initial acceptance plan follow, then final evidence.

## Evidence and falsifiable hypothesis

The final P7.3.7 SGR profile leaves action destruction and SGR decoding as
material costs. A profile attribution alone does not identify which object a
runtime drop frees. The allocation evidence here comes from the archived native
C and actual ARM64 assembly in
`.tmp/csi-fast-path/artifacts/action-expanded/`.

For a normal CSI containing one payload-free SGR attribute such as bold/reset,
the pre-change native path allocates a 56-byte Csi object, a 16-byte CsiDispatch
wrapper, and a 16-byte StreamSetAttribute wrapper (allocator request sizes,
including runtime headers). Csi and CsiDispatch occur once per CSI; the last
wrapper occurs once per emitted attribute. Payload-free SgrAttribute values and
their nullable Option return use constant constructors, without another box.
Color/Unknown payloads can allocate independently.

`next-stream.asm` at 0x100036040 and 0x100036070 contains the first two allocator
calls. `assembly.txt`'s specialized `Stream.emit_sgr` at 0x100038e3c allocates
the last wrapper and calls bridge.apply at 0x100038e5c; emit/vt have already
been inlined by the C compiler. Merely requesting that those functions inline
cannot remove this remaining allocation.

Hypothesis: a typed handler method lets the terminal consumer apply the
attribute without constructing StreamSetAttribute, eliminating exactly that
one wrapper allocation/drop per attribute on the terminal path. Verify in
new generated C and actual assembly before timing. This does not eliminate
Csi/CsiDispatch, payload allocations, or SgrParser.set_view reference traffic;
the end-to-end benefit was unknown at approval and is measured independently
in the final results below.

## Upstream mapping and capability conflict

Upstream references are relative to `upstream/ghostty/src/terminal/`. In this
managed checkout that submodule is absent; the inspected files are in
`/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/upstream/ghostty/src/terminal/`.

| Upstream owner | Target and preserved responsibility |
| --- | --- |
| `stream.zig`, `Stream.csiDispatch`, lines 1410–1425 | `terminal/stream/stream.mbt`, `Stream.emit_sgr`: iterate SGR attributes in order and call `handler.vt(.set_attribute, attr)` |
| `sgr.zig`, `Parser.next` | `terminal/sgr/sgr.mbt`, `SgrParser.next`: unchanged semantic decoding and Unknown ownership |
| `stream_terminal.zig`, `StreamTerminal.vt` `.set_attribute`, lines 209–212 | `terminal/stream_terminal.mbt`, private StreamTerminalHandler typed override |
| `Terminal.zig`, `Terminal.setAttribute`, lines 2752–2755 | `terminal/stream_terminal_bridge.mbt`, package-private `StreamTerminalBridgeState.set_attribute`: centralize the existing current-style update |

Zig's handler call selects an action at compile time and passes its typed
payload. The existing MoonBit `StreamHandler.vt(Self, StreamAction)` API instead
requires constructing the heterogeneous action value before dispatch. Compiler
inlining currently preserves that allocation. The project already expresses
the print operation using a typed `StreamHandler.print` method. SGR needs a
corresponding typed compatibility adapter to reproduce this upstream dispatch
property while keeping generic event consumers working.

Adding a public method and a private bridge entry point changes the approved
adapter/API boundary. AGENTS.md required confirmation of this exact shape, which the user supplied
before implementation.

## Approved minimal code shape

Add a defaulted method to the existing public open trait. Keep vt, print, and
deinit unchanged. MoonBit default-method syntax was checked against the current
MoonBit skill's `references/traits-methods.md`; implementation must still pass
the normal compiler gates.

```moonbit
pub(open) trait StreamHandler {
  fn vt(Self, StreamAction) -> Unit
  fn print(Self, UInt32) -> Unit
  fn set_attribute(Self, @sgr.SgrAttribute) -> Unit = _
  fn deinit(Self) -> Unit
}

impl StreamHandler with fn set_attribute(self, attribute) {
  Self::vt(self, StreamSetAttribute(attribute))
}
```

In the existing `Stream.emit_sgr` loop, replace only
`self.emit(StreamSetAttribute(attribute))` with
`H::set_attribute(self.handler, attribute)`.

Add the terminal implementation:

```moonbit
impl @stream.StreamHandler for StreamTerminalHandler with fn set_attribute(
  self,
  attribute,
) {
  self.bridge.set_attribute(attribute)
}
```

Add one package-private bridge method mapped to Terminal.setAttribute:

```moonbit
fn StreamTerminalBridgeState::set_attribute(
  self : StreamTerminalBridgeState,
  attribute : @sgr.SgrAttribute,
) -> Unit {
  self.current_style = self.current_style.apply_attribute(attribute)
}
```

The existing `StreamSetAttribute` arm of `StreamTerminalBridgeState.apply`
calls this same method and still returns true. Thus direct bridge.apply callers
and the optimized stream path retain one implementation of style application.
Duplicating the assignment directly in the terminal handler could avoid the
method, but would split the semantic owner between two locations. Approval
explicitly includes this private method; no other helper/type/storage/API is
proposed. The helper must not appear as a new public item in `.mbti`.

## Consumer contract and invariants

- Existing external handlers implementing only vt/print/deinit remain valid:
  the default method emits the same StreamSetAttribute event to vt, once per
  attribute, in the original order. It neither skips nor batches attributes.
- An overriding handler intentionally replaces how it consumes an attribute.
  Document the override contract and equivalence to receiving
  StreamSetAttribute. Generic event recorders retain the default.
- The terminal override changes only dispatch. Unknown remains ignored through
  existing CellStyle.apply_attribute behavior, matching upstream terminal vt;
  all reset, color, underline, and multi-attribute ordering remains unchanged.
- The parser's borrowed CSI views and synchronous SGR iterator window are
  unchanged. SgrUnknown owns copied parameter data because a user handler may
  retain it after later parser input overwrites scratch buffers. Keep those
  copies in both default and overriding handler paths.
- No parser state visibility, Csi representation, ActionList layout, SGR
  storage, reentrancy promise, callback order, or error policy is changed.

## Write boundary, tests, and completion gate

Implementation files: `terminal/stream/stream.mbt`,
`terminal/stream_terminal.mbt`, `terminal/stream_terminal_bridge.mbt`,
and the explicitly authorized `terminal/moon.pkg` sgr import required by the
approved bridge signature. The sgr package has no terminal dependency, so
this adds no dependency cycle.
Tests: existing stream and terminal test files; add a focused custom-handler
fixture only inside tests. Documentation: this task plan and `docs/plan.md`.
Only the defaulted StreamHandler.set_attribute method is an intended public
API addition; update generated interfaces with `moon info` and review the diff.

Required tests:

1. A handler with no set_attribute override still compiles and receives exact
   ordered StreamSetAttribute events for empty/reset, multiple parameters,
   semicolon/colon colors, underline, unknown/truncated forms, and mixed
   printable/control input. Existing recorder tests also exercise this route.
2. A handler with an override sees the same ordered attributes, with zero
   StreamSetAttribute deliveries to vt. Retain an Unknown attribute, feed a
   subsequent CSI, and prove its full/partial parameter snapshots remain owned.
3. Compare the optimized terminal path with explicit bridge.apply actions for
   the same attribute sequence; verify style and printed-cell snapshots across
   reset, palette/direct colors, underlines, Unknown, and primary/alternate
   screens. Test the bridge apply arm's true result remains unchanged.
4. Preserve existing parser/stream differential, every-chunk-split, SGR and
   terminal suites. Do not alter Parser.next_stream or SgrParser.next here.

Quality commands:

```sh
moon check --target all
moon test --target all
moon test --target native --enable-coverage
moon coverage analyze
moon fmt
moon info
git diff --check
```

Review fresh coverage traces for the default method, override, private bridge
method, changed apply arm, and changed emit_sgr call. Record any uncovered
executable line/site explicitly. Use this repo's verified native trace
collection path; empty annotated files are not evidence of coverage.

Inspect native code for elimination of the StreamSetAttribute allocation on
the terminal route and preservation of the default handler's event allocation.
Compare this candidate independently against its immediate clean baseline;
capture all raw samples and alternate run order. Measure sgr_storm, tui_redraw,
query_storm, representative long multi-parameter SGR, and existing plain/CJK,
scroll, OSC title/color and Kitty APC controls. Use repeated paired release
runs; inspect wall and CPU measurements for long workloads. Do not attribute
earlier CSI gains to this adapter or discard slower controls/outliers. A
repeatable regression requires explicit acceptance or rejection, not a claim
of zero regression. Retain only a supported improvement and commit it as one
atomic step with tests, plan updates, API audit and measured results.

## Public API audit and remaining boundaries

The new trait method has an external consumer story: typed SGR consumption without
the StreamSetAttribute wrapper, with an event-preserving default. The handler stays open and the
bridge method stays package-private. Existing public StreamAction/SgrAttribute
variants serve event consumers; SgrUnknown's readable owned payload serves
retaining handlers. Opaque Parser, Stream, SgrParser and ActionList remain
opaque; no public mutable fields are introduced.

Existing parser payloads are `pub(all)` and parser control methods
`enter_escape`/`reset_ground` are broader surface than this adapter needs.
They are unchanged and require a separate consumer audit before any reduction;
this change does not rely on or expand them. No claim is made that all
pre-existing public constructors are justified merely because white-box tests
use them. Further action representation changes, callback parser adapters,
buffer identity caches, or global cached action objects require a separate
deviation proposal.


## Implementation audit

Immediate baseline `9a4219fb` microbenchmark and unchanged 120x80 long harness
binaries were frozen before implementation in `.tmp/sgr-handler-fast-path/`.
New tests were added first. The expected RED was the missing trait method;
an additional test-only Int/UInt16 mismatch in four existing cell helper calls
was reported and corrected with `to_uint16()`, without expanding scope.


## Native code and ownership verification

The specialized terminal `emit_sgr` changes from one C `moonbit_malloc` site
to zero. Actual ARM64 removes the allocator call and bridge.apply dispatch;
it loads current style, calls CellStyle.apply_attribute, and stores the result.
The attribute itself is still released when required. `next_stream` and its
Csi/CsiDispatch allocations are unchanged. The release-built default Recorder
still has a StreamSetAttribute allocation in its default method, inlined into
its specialized emit_sgr assembly. This verifies both the optimized terminal
route and the event-preserving compatibility route.

Three meaningful tests were added: default/typed handler global event order
with empty, multi-attribute, color, underline, truncated and mixed control
inputs; retained Unknown ownership with full `[1, 999, 4]` versus partial
`[999, 4]` after subsequent CSI overwrites; and optimized terminal versus
explicit bridge.apply style/cell snapshots across primary/alternate screens.
The last test also verifies every explicit apply still returns true.

## Paired microbenchmark results

Frozen immediate-baseline and candidate executables use the unchanged native
benchmark driver's workload indexes. Odd rounds run baseline first, even
rounds candidate first. Tables report change of median per-invocation means,
not confidence intervals. The first round suffered large host slowdowns;
no sample or round was excluded.

| Workload | Four-pair time change | Faster pairs | Tight six-pair change | Faster pairs |
| --- | ---: | ---: | ---: | ---: |
| sgr_storm | -13.72% | 4/4 | not repeated | — |
| query_storm | -0.56% | 2/4 | not repeated | — |
| tui_redraw | -5.40% | 4/4 | not repeated | — |
| osc_titles | -4.53% | 2/4 | not repeated | — |
| color_storm | -1.66% | 3/4 | not repeated | — |
| kitty_apc_long | +0.34% | 0/4 | +0.37% | 2/6 |
| plain_lines | +0.05% | 3/4 | not repeated | — |
| cjk_text | +1.49% | 2/4 | +0.78% | 3/6 |
| scroll_full | +3.54% | 2/4 | -3.39% | 6/6 |

The bounded follow-up resolved the earlier scroll uncertainty (six faster
pairs); CJK remains mixed and is not claimed as a stable gain or regression.
APC is transparently retained as a small cost. No further favorable-sample
search or control rerun was performed. Per-round host process snapshots and
all complete benchmark JSON/stdout are in `.tmp/sgr-handler-fast-path/`.

## Exact long inputs, 120x80

The unchanged prior harness and byte-identical primary/alternate corpora were
used with independently built `9a4219fb` and candidate executables. Hyperfine
uses `-N -w 1 -r 3` per alternating pair, four rounds. Startup, stdin reading
and disposal are included without subtraction. CPU is user+system process
time, a separate work measure rather than throughput.

| Corpus | Wall time change | CPU time change | Faster wall pairs |
| --- | ---: | ---: | ---: |
| primary/sgr | -5.13% | -4.30% | 3/4 |
| primary/cursor | -0.58% | -0.43% | 3/4 |
| primary/printable | +0.89% | +0.41% | 1/4 |
| primary/lines | -2.64% | -2.68% | 2/4 |
| alternate/sgr | -2.14% | -2.26% | 4/4 |
| alternate/cursor | -1.19% | -1.21% | 2/4 |
| alternate/printable | +0.21% | +0.59% | 1/4 |
| alternate/lines | -0.44% | -0.36% | 4/4 |

Alternate SGR is the reliable long-input headline: all four pairs improve.
Primary SGR improves in three pairs but has a +52.88% candidate stall in round
two. Alternate printable includes +95.93%/-26.59% pair outliers, so its near-flat
median is not strong evidence. Primary printable's small +0.89% wall/+0.41%
CPU change is reported rather than hidden. These limits rule out a claim of a
uniform long-stream speedup. Raw hyperfine JSON, all outliers, corpus hashes,
binary hashes and dimensions are preserved in the artifact directory.

## Final SGR profile and remaining costs

Three fresh native release profiles collected 616, 630 and 648 samples
(1,894 total). Pooled self time remains concentrated in Parser.next_stream
18.69%, runtime drop_object 16.63%, SgrParser.next 13.83%, and mi_malloc 4.49%.
The runtime leaf attribution has consume_until_ground → drop_object at 16.53%
and next_non_utf8 → mi_malloc at 4.49%. These are sample shares after compiler
inlining, not exact object counts or independent predictions of possible gain.

The earlier P7.3.7 snapshot had csi_dispatch → drop_object at 4.64%; that
attribution no longer appears in these pooled results. The intervening
P7.3.8 change and symbol/inlining differences prevent isolating this step from
that profile comparison alone. The actual allocation removal is established
by C/ASM, and its independent performance evidence is the paired baseline.
CSI payload/wrapper allocation, remaining parser action destruction and SGR
semantic decoding remain potential future work requiring separate design and
measurement. This step does not broaden their representation or APIs.

## Final gates and touched-file coverage

- `moon check --target all` passed.
- `moon test --target all`: 674 wasm, 674 wasm-gc, 696 JS and 674 native passed,
  exactly three more tests than the immediate baseline.
- Native coverage tests: 674 passed, 41 fresh traces copied before analysis.
  `moon coverage analyze` and isolated native JSON/caret/HTML reports passed.
- All three changed production source digests match their native JSON digest.
  Default method line 187 hit 367; typed emit call 481 hit 428; terminal override
  27 hit 47; private helper 770 hit 64; apply arm 956 hit 17. All changed
  executable lines/sites are covered, including both compatibility routes.
- File summaries: stream 694/695 sites; handler 263/281; bridge 1431/1486.
  These are not whole-file 100% claims. Stream's sole uncovered site is the
  unchanged line 250 chunk-size `else { CP_BUF_LEN }` (previous line 241).
  The handler's eight and bridge's 34 completely uncovered lines were mapped
  to unchanged lines already uncovered in the immediate baseline. Partial-site
  gaps are outside the straight-line methods changed here. Existing gaps are
  accepted outside this scoped dispatch change; exact line mappings, caret
  diagnostics and HTML remain in the audit artifacts.
- `moon fmt`, default `moon info`, and `git diff --check` passed. The sole API
  addition is defaulted `StreamHandler.set_attribute(Self, SgrAttribute)`.
  The bridge method remains package-private; no mutable public fields appear.
- The required sgr import adds no dependency cycle. No parser/SGR source,
  storage layout, borrowed payload contract, or unrelated formatting changed.

All raw evidence, generated code, binaries, runners, fresh native traces/maps,
coverage proof, profile JSON/XML and summaries live under
`.tmp/sgr-handler-fast-path/`. Source/API review passed; final audit review
precedes a separate `perf(stream)` commit. No combined gain with earlier
optimizations is claimed.
