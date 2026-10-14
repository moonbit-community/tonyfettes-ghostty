# P7.3.7: preserve opaque parser ownership for upstream CSI fast paths

Status: done. The user explicitly approved the opaque adapter before
implementation. Main accepted the final measured tradeoff: SGR/query/TUI gains
with a small +1.27% Kitty APC control cost. All-target checks/tests and native
touched-line/site coverage passed; independent source/API review passed.

The approved proposal was originally recorded as
`docs/plans/2026-10-14-csi-fast-path-proposal.md` and was renamed to this file
when the implementation and audit were finalized. Its original approved text
is preserved in `.tmp/csi-fast-path/original-approved-proposal.md`.

## Final result

The retained implementation ports upstream ESC/CSI parameter fast paths and
its required inline fallback behavior into the one approved Parser.next_stream
adapter. Native code removes generic Parser.next/do_action calls from this
stream path, while generic Parser.next itself is unchanged. No new mutable
public state, result type, helper, or storage model was introduced.

| Microbenchmark | Baseline median | Candidate median | Time change |
| --- | ---: | ---: | ---: |
| sgr_storm (four pairs) | 6.860 ms | 5.965 ms | -13.05% |
| query_storm (four pairs) | 7.420 ms | 6.725 ms | -9.37% |
| tui_redraw (four pairs) | 757.585 us | 723.385 us | -4.51% |
| OSC color_storm (four pairs) | 16.990 ms | 16.980 ms | -0.06%, effectively flat |
| OSC osc_titles (four pairs) | 243.805 us | 244.205 us | +0.16%, effectively flat |
| plain_lines (four pairs) | 212.09 us | 212.00 us | -0.04%, effectively flat |
| cjk_text (four pairs) | 266.67 us | 267.87 us | +0.45%, effectively flat |
| scroll_full (six tight pairs) | 3.260 ms | 3.240 ms | -0.61%, no persistent slowdown |
| kitty_apc_long (six tight pairs) | 1.965 ms | 1.990 ms | **+1.27% observed cost** |

Each number is a median of per-invocation benchmark means, not a confidence
interval. The three improved target workloads were faster in every one of
four pairs. APC was slower in five of six pairs and tied in one; this is an
observed tradeoff, not dismissed as noise. The main agent explicitly accepted
it after reviewing the result. This amends the initial no-control-regression
acceptance goal transparently rather than claiming a universal improvement.
All prior candidates, raw samples and outliers remain in `.tmp/csi-fast-path/`.

SGR's single-digit microbenchmark does not exercise the dense digit loop: its
gain combines the ESC shortcut and faithful source expansion of upstream inline
fallbacks. The multi-parameter long SGR corpus validates the combined change.
No independent numerical gain is attributed to the digit fast path alone.

## Measured reason and scope

The post-P7.3.5 profile identifies parser transition/action work as a major SGR
cost. See `2026-10-14-post-optimization-profile.md` for the actual samples and
their workload limits. Three bounded print experiments were rejected; none
justifies a performance claim or a retained implementation change.

The active step is P7.3.7, following P7.3.5 and the P7.3.6 experiment
audit. It ports the already-existing upstream ESC/CSI parameter fast paths,
without adding a new parsing algorithm, exposing parser fields, or changing
storage. This change does not include SGR semantic decoding changes.

## Upstream owner and package conflict

- `upstream/ghostty/src/terminal/stream.zig:649–704`, `nextNonUtf8`: ESC `[`;
  dense `csi_param` controls, digits, separators and DEL; ordinary parser
  fallback for all other bytes.
- `upstream/ghostty/src/terminal/Parser.zig`, `next` and parameter/clear actions:
  fallback state transitions, dispatch payloads and exit/transition/entry order.
- MoonBit targets: `terminal/parser/parser.mbt` and
  `terminal/stream/stream.mbt`; existing parser/stream test files and this plan.

Upstream stream code directly accesses Parser.state, params, params_idx,
params_sep, param_acc and param_acc_idx. MoonBit's Parser deliberately owns
these as opaque fields in another package. The conflict is package privacy,
not a missing arithmetic or compiler feature. Exposing the mutable state would
violate this repository's public API contract.

## Approved compatibility adapter

Add one parser-owned public behavioral method; no new helper/result type:

```text
pub fn Parser::next_stream(self : Parser, c : Byte) -> ActionList
```

Its sole intended production consumer is `Stream::next_non_utf8`, which changes
its `self.parser.next(byte)` call to `self.parser.next_stream(byte)` and retains
its existing synchronous exit/transition/entry dispatch. The method returns
the existing opaque value-shaped ActionList; ParserState and accumulators stay
private. Generic `Parser::next` remains unchanged and table-driven.

The adapter is intentionally stream-specific: it preserves upstream stream
events, rather than promising identical raw Parser actions for ignored C0
bytes. Its documentation makes this distinction explicit. The accepted
candidate also expands the original next orchestration and do_action match
inside this method, matching upstream nextNonUtf8's always_inline next call
and inline doAction. Generic next and do_action remain unchanged. This
source duplication is intentional compiler adaptation, protected by an exact
source audit and all-14-state × 256-byte differential tests.

Pseudocode (shape, not unverified MoonBit implementation syntax):

```text
if state is Escape and c == '[':
    state = CsiEntry
    return empty ActionList
if state is CsiParam:
    0x00..0x0F:
        return ActionList(exit=None, transition=Execute(c), entry=None)
    0x10..0x17, 0x19, 0x1C..0x1F, 0x7F:
        return empty ActionList
    0x18, 0x1A:
        state = Ground
        return empty ActionList
    '0'..'9':
        if params.length < MaxParams:
            param_acc = existing saturating_param_append(param_acc, c)
            param_acc_idx = param_acc_idx | 1
        return empty ActionList
    ':', ';':
        if params.length < MaxParams:
            if c == ':': params_sep = params_sep.set(params.length)
            params.push(param_acc)
            param_acc = 0
            param_acc_idx = 0
        return empty ActionList
    otherwise: fall through
otherwise execute the unchanged generic next body here, with its do_action
match expanded inline as upstream requires
```

The empty value uses the existing ActionList fields directly inside its owning
package; no new constructor/helper is needed. Existing saturating arithmetic
remains the single implementation. The first parameter byte in CsiEntry still
uses the existing state machine; only subsequent CsiParam bytes use the fast
path, matching upstream. ESC-to-CsiEntry skips a redundant clear because entry
into Escape already cleared all accumulators. This invariant needs a test.

## Must-preserve contracts

- Digit values saturate at 65535; 24-parameter capacity and overflow-dispatch
  suppression match upstream. Empty/trailing parameters and colon bit positions
  are unchanged. param_acc_idx is private and consumed only as nonzero on this
  path; its fast-path OR behavior is upstream's, not a new digit-count contract.
- CAN/SUB return to Ground. ESC, final bytes, private markers, intermediates,
  malformed inputs and other bytes use the existing fallback where applicable.
- OSC/DCS/APC exit/entry actions and their ordering remain the generic parser's
  responsibility. No fast path applies outside Escape/CsiParam.
- Existing Csi/Esc/Dcs views remain borrowed from parser buffers. Dispatch must
  finish before another next/next_stream/enter_escape call. No stored borrowed
  payloads or asynchronous dispatch are introduced; DCS still takes its owned
  copy in the stream layer.
- Upstream's fast-path C0 execution bypasses its optional raw interception.
  The current MoonBit Stream has no raw hook. Do not accidentally promise raw
  Action equivalence or add such a hook in this change.
- Stream byte-at-a-time and next_slice/chunked input produce identical typed
  events and terminal state, including partial UTF-8 before an escape.

## Original validation and acceptance plan

The final result above records the accepted APC tradeoff that amends the
original control-regression criterion below.

Parser white-box tests should compare adapter and generic parsing at sequence
boundaries, copying borrowed payloads immediately. For ordinary cases compare
ordered actions and finalized CSI values; for fast-path ignored/CAN/SUB C0
cases assert the explicitly specified stream behavior, not raw-action equality.

Cover ESC `[`, first/subsequent digit, empty and trailing `;`/`:`, mixed
separators, 65535/65536/very long digits, 23/24/25 params, saturated buffers,
colon rejection for non-`m` finals, C0 execute and ignored ranges, CAN/SUB,
DEL, private/intermediate bytes, repeated ESC, malformed CSI, and a later valid
sequence after every termination/overflow case. Include fallback OSC BEL/ST,
DCS unhook, and APC termination order checks.

Stream recorder tests should compare `next` with `next_slice` at every split
point of representative CSI/SGR sequences, including splits after ESC, `[`, a
digit, separator, CAN/SUB and immediately before final dispatch. Include one
UTF-8 boundary/control mixture and back-to-back escape sequences. Existing
terminal integration tests verify actual SGR/cursor effects.

Inspect native C and ARM64: common parameter bytes must bypass transition-table
lookup and generic do_action, without new allocation for empty action results.
Then run four tightly paired rounds of SGR/cursor benchmarks with plain/CJK,
OSC/DCS and scroll controls, followed by the unchanged primary/alternate long
inputs. Preserve all samples and reject a persistent control regression.

Required gates: `moon check --target all`, `moon test --target all`,
`moon test --target native --enable-coverage`, `moon coverage analyze`, touched
parser/stream caret review, `moon fmt`, default `moon info`, `git diff --check`.
The sole intentional `.mbti` addition is Parser.next_stream. Review coverage
for every new arm and document any accepted gap. Update docs/plan.md and this
subplan in the same independently green commit; main/reviewer approval follows
the full correctness, API and measured-performance audit.

## Approval and maintenance boundary

This moves upstream stream-owned state mutation behind a new parser-owned
public compatibility adapter. It changes a module boundary and public API,
even though storage and externally observed terminal behavior are preserved.
The user explicitly approved this adapter before implementation. The main
agent subsequently authorized source expansion of the existing fallback and
do_action to reproduce upstream inline behavior without changing this API or
storage boundary.

Alternative: put equivalent fast paths directly into Parser.next. That avoids
a new public method but changes the generic parser's table-driven structure
and cannot copy stream-only C0 handling verbatim without changing its raw-action
contract. It requires its own explicit mapping and approval, so the narrowly
documented next_stream adapter is preferred.

## Implementation and rejected-candidate audit

The approved method is implemented with the exact fast-path state ownership
and existing ActionList return representation. Generic next is unchanged.
Focused validation: `moon check --target all`, parser tests (37 each backend),
and stream tests (70 each backend) passed. Initial check failed only in new
test expressions at parser_wbtest.mbt:654 (ParserState lacks Debug); related
new to_repr expressions were deprecated and a stream test range direction was
ambiguous. The failure was reported before edits; tests now use existing
state.ordinal(), Repr(), and an explicit ascending range. No API/derive was
added to accommodate tests.

Generated C and actual ARM64 binary show digit accumulation as inline
saturating multiply/add and OR1, separators using existing Array.push, and
ESC `[`/empty results returned as three zero words without allocation.
Unhandled bytes tail-branch to generic Parser.next. Low C0 Execute still
allocates its existing Action payload: this does not claim all controls are
allocation-free. Artifacts: `.tmp/csi-fast-path/artifacts/variant/`.

### Initial paired performance (before acceptance)

The first broad four-round run had substantial host load and correlated drift;
all raw logs are retained in `.tmp/csi-fast-path/`. The bounded six-round
follow-up alternated baseline/candidate order for three affected controls.
These are medians of reported run means, not confidence intervals:

| Workload | Baseline | Candidate | Time change | Slower pairs |
| --- | ---: | ---: | ---: | ---: |
| single-digit sgr_storm | 6.895 ms | 7.100 ms | +2.97% | 5/6 |
| OSC color_storm | 17.115 ms | 18.570 ms | +8.50% | 6/6 |
| OSC osc_titles | 245.745 us | 253.180 us | +3.02% | 6/6 |

Workload interpretation is essential: sgr_storm repeats ESC[1m/ESC[0m and
never consumes a subsequent digit in CsiParam, while color_storm is OSC palette
churn. These are controls for fallback overhead, not direct dense-parameter
measurements. The exact prior long SGR corpus (ESC[38;5;Nm plus text) exercises
the new path and is measured separately before judging the tradeoff. The
current candidate nevertheless has a persistent control regression, so it
cannot pass the acceptance gate solely by improving long SGR.

### Adapter inline hint experiment

The observed next_stream machine code saves a frame before checking its state,
then restores it and tail-branches to generic next for OSC and other fallbacks.
A bounded `#inline` hint on existing next_stream was authorized to test removal
of this extra call/frame. The release build succeeded, but generated C still
has the call and actual ARM64 still calls next_stream (0x100035b50), whose
function begins with the same two stp instructions (0x100035c9c). The hint was
ineffective; no additional timing run was performed for it. C/binary/assembly
are retained under `artifacts/inline/`.

The initial long-input sweep was stopped after the complete first round and
the beginning of the second, as instructed after the persistent control
regressions. Primary SGR/cursor first-pair changes were -0.66%/-7.99%; alternate
SGR/cursor -7.92%/-14.22%. Alternate plain-lines also changed -18.30%, so these
single-pair values contain substantial unrelated drift and are diagnostic only.
All completed and partial logs/JSONs remain; no repeatable long-input gain is
claimed from this run.

### Faithful expansion of upstream always_inline fallback

Main authorized an implementation correction inside the same approved adapter:
upstream stream.zig explicitly uses `@call(.always_inline, Parser.next)`.
MoonBit's tested `#inline` hint cannot express that generated-code result here.
Remove the ignored hint and expand the exact generic next body at the fallback
site in next_stream, while leaving generic next unchanged. Shared transition,
action, and clear implementations remain the only implementations of those
operations. This duplicates the small orchestration body and therefore needs
synchronized maintenance; an explicit comment and reachable-state × all-256-byte
differential test protect action ordering and payload parity. No new helper,
type, storage or API beyond the approved next_stream method is introduced.

### Expanded fallback measurement

Focused checks and parser/stream tests pass on every backend; the differential
corpus now reaches all 14 parser states using real prefixes and tests all 256
following byte values. Independent source review confirms the expanded fallback
body is text-identical to generic next. The native adapter no longer calls
generic next: the extra frame/call is gone.

Four alternating-order tightly paired rounds produced these medians of run
means (every sample retained):

| Workload | Baseline | Expanded fallback | Time change | Faster pairs |
| --- | ---: | ---: | ---: | ---: |
| sgr_storm | 6.835 ms | 6.580 ms | -3.73% | 4/4 |
| OSC color_storm | 16.865 ms | 17.605 ms | +4.39% | 0/4 |
| OSC osc_titles | 241.005 us | 247.335 us | +2.63% | 0/4 |
| tui_redraw | 757.855 us | 733.025 us | -3.28% | 4/4 |

This removes the initial single-digit SGR regression, but OSC controls still
slow consistently. The acceptance gate remains unmet. Work paused after this
result before any further implementation experiment; no claim of a universally
faster parser is made. Expanded code, executable and disassembly are preserved
under `artifacts/expanded/`, with `expanded-summary.json` and raw logs.

### Expand upstream's inline doAction within the approved adapter

After the observed residual fallback call was identified, main authorized
expanding the exact existing do_action match body at the adapter's
transition_action binding. Upstream Parser.zig declares doAction inline.
Generic next and shared do_action stay unchanged; the adapter still uses the
existing collect, consume_param and OSC next operations. No new helper, API,
state or storage change. This second copied body must remain synchronized,
and the same all-states differential protects it. Inspect assembly, rerun
focused checks/tests, then the same bounded four paired control rounds.

The first check of the expanded action match failed at parser.mbt:222 onward
because moving it from an Action?-returning function lost its expected type:
None/Print/Execute became ambiguous with TransitionAction. This was reported
before a bounded correction: annotate only the local transition_action as
Action?. The same all-target focused check/parser/stream commands then passed.
Independent review confirms the action-match body equals the original
textually; generic next/do_action are unchanged. Actual adapter ARM64 now has
neither a generic Parser.next call nor a Parser.do_action call. OSC's own next
and the shared transition lookup remain.

### Final candidate paired result

After expanding both upstream inline bodies, the four paired rounds gave:
SGR median 6.860 -> 5.965 ms (-13.05%, all four faster), TUI median
757.585 -> 723.385 us (-4.51%, all four faster). OSC title median
243.805 -> 244.205 us (+0.16%) is effectively flat, not an improvement claim.
OSC palette median 16.990 -> 16.980 ms (-0.06%) is likewise effectively flat;
three rounds improved and a fourth +12.03% outlier is retained. The former
persistent OSC regressions are not reproduced with this candidate.

A harness build command mistakenly used unsupported
`moon build --release --target native --manifest-path .tmp/csi-fast-path/long/moon.work`.
The CLI rejected it before building. Running the previously validated
`moon build --release --target native` with the long harness directory as cwd
succeeded. No source change was made for this command correction.

The unchanged exact 120x80 primary/alternate long inputs and remaining
control workloads were measured serially. Final audits are recorded below.

## Long-input validation

Unchanged corpus files and unchanged harness use 120x80, native release,
primary/alternate screens, four alternating-order paired rounds, with one
warmup and three measured process runs per command per round. The frozen
baseline long binary comes from the prior scroll-fusion candidate and is
source-identical to the current baseline; input sizes/hashes are in metadata.json.
These timings include process startup, stdin read, processing and disposal.
No startup subtraction is used here; CPU time means hyperfine user+system and
is not a throughput measurement.

| Input | Wall-time change | CPU-time change | Wall faster pairs |
| --- | ---: | ---: | ---: |
| primary SGR | -16.42% (noisy baseline) | -8.47% | 4/4 |
| primary cursor | -4.54% | -4.67% | 4/4 |
| primary printable | +21.33% (descheduling outliers) | +2.70% | 2/4 |
| primary lines | -0.95% | -0.93% | 3/4 |
| alternate SGR | -5.73% | -5.60% | 4/4 |
| alternate cursor | -5.03% | -5.29% | 4/4 |
| alternate printable | -0.30% | -0.22% | 1/4 |
| alternate lines | -0.06% | +0.02% | 2/4 |

Prefer the alternate SGR/cursor approximately 5–6% result to the noisy primary
SGR headline. Primary printable's first candidate round spans 503.4–1570.5 ms
versus the baseline's 503.3–506.8 ms, with a much smaller CPU difference. Host
snapshots show unrelated Chromium, builds and tests active. The final two
primary printable pairs improved 2.14% and 0.27%; the large aggregate wall
regression is not reliable evidence of a code slowdown. Its exact size cannot
be estimated from this run. Native plain_lines is flat in the separate four
paired control runs. All outliers are retained, not discarded or substituted.

The initial four-pair scroll/APC controls were noisy (+2.11%/+1.00% median),
so one bounded six-pair follow-up was run; it resolves scroll to mixed-sign
near-flat results and APC to the explicitly accepted small cost above. No
further reruns were used to select a favorable result.

## New SGR profile and remaining bottlenecks

Three new native profiles recorded 714, 717 and 722 samples (2153 pooled),
compared with the baseline's 821, 820 and 851 (2492 pooled), for the same
workload and iteration count. Percentages are statistical stack attribution,
not exact instruction timing; inlining also changes symbol attribution.

The old separate generic parser next/do_action self buckets (12.08%/13.16%)
are replaced by next_stream at 17.28%; transition_for self attribution falls
from 5.78% to 2.79%. SgrParser.next is now 13.33% (previously 11.52%), and
consume_until_ground -> drop_object is 13.66% (previously 11.60%). These larger
remaining percentages do not mean those operations got slower; their share
rises as other work shrinks. Semantic SGR decoding and action/lifetime cleanup
remain substantial. No further optimization is included in this step.

## Final gates, native coverage, and public API

Passed `moon check --target all`; `moon test --target all` with 671 wasm,
671 wasm-gc, 693 JS, and 671 native tests; native coverage collection;
`moon coverage analyze`; `moon fmt`; default `moon info`; and `git diff --check`.
Release builds retain the pre-existing warning 0073 in
build_info_optimize_release.mbt; no new or deprecated warning remains.

An extra native-only reporting script initially assumed traces lived below
_build/native/debug/test and stopped with Missing native coverage traces.
The toolchain actually writes them at _build/moonbit_coverage_*.txt. To avoid
mixing analysis runs, native coverage was rerun and its 41 newly generated
traces isolated. This was an audit-path correction, not a source/test failure.
The resulting native-coverage.json includes both changed files with digests
matching the final source, and native-touched-line-proof.json records counts.

- Parser has 158/158 coverage sites, 121 instrumented executable lines, no
  uncovered line. All 52 instrumented lines in the new adapter region have
  positive counts, including rare OSC-end None, CSI suppression and DCS limit
  branches. Blank/comment/uninstrumented adjacent statements share those sites.
- Stream has 694/695 coverage sites and no wholly uncovered executable line.
  The changed next_stream call at line 402 has 7958 hits. Its sole uncovered
  site is the inherited `CP_BUF_LEN` else branch at line 241 (chunk >=4096),
  on a line whose other sites are covered. This unchanged chunking branch is
  acceptable for this scoped adapter change and explicitly remains coverage
  debt; the whole stream is not claimed to have 100% site coverage.
- Empty caret reports mean no uncovered whole lines; they were cross-checked
  against native JSON and HTML rather than accepted as proof by themselves.

The only .mbti change is the approved `Parser::next_stream(Self, Byte) ->
ActionList`. Its production consumer is Stream.next_non_utf8; Parser and
ActionList stay opaque and parser state/buffers remain private. Existing
borrowed Csi/Esc/Dcs payloads retain their documented synchronous contract.
No new API was introduced for tests. Generic next and do_action are unchanged.

## Maintenance risk and evidence

The next orchestration and do_action match are intentionally duplicated inside
next_stream because the current compiler does not honor the needed inline hint.
Future semantic edits must update both counterparts together; comments beside
each copy say so. Independent review compared both copied bodies to their
sources, and the reachable-state differential test protects observable action
order and payloads. This maintenance cost is explicit, not hidden abstraction.

Raw artifacts include every rejected-stage C/ASM/binary, all paired logs and
JSONs, long-input hashes, native coverage traces/source maps/JSON/HTML, final
profile JSON/XML, and frozen final/baseline long binaries. No new Zig/xterm
benchmark was run, so this step does not establish a new three-way ratio.
