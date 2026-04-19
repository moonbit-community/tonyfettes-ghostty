# Ghostty Parser Translation Plan

## Goal and non-goals

Goal:

- Translate the upstream Ghostty terminal parser stack from Zig to MoonBit as
  faithfully as possible.

Primary upstream scope:

- `src/terminal/Parser.zig`
- `src/terminal/parse_table.zig`
- `src/terminal/UTF8Decoder.zig`
- `src/terminal/stream.zig`
- `src/terminal/osc.zig`
- `src/terminal/dcs.zig`
- `src/terminal/sgr.zig`
- `src/terminal/stream_terminal.zig`
- the minimum terminal-model modules those files require

Non-goals for now:

- renderer translation
- GTK/macOS frontend translation
- full PTY/backend parity beyond the parser-facing bridge
- packaging and distribution parity

## Fidelity invariants

These constraints apply to every phase:

- preserve upstream module boundaries unless MoonBit forces a local adaptation
- keep the parser table-driven
- preserve `Parser.next` three-action ordering
- preserve UTF-8 retry-on-error semantics
- keep OSC dedicated and DCS incremental
- keep tests close to each translated layer
- keep the work reviewable in small, atomic commits

## Quality gates

This plan is intentionally structured so that every implementation commit can
end in a green state.

- Do not create standalone failing tests in one commit and the implementation
  in a later commit.
- Each implementation task must include the minimum runnable implementation,
  its tests, and the quality checks in the same task and commit batch.
- For MoonBit source changes, the task is not complete until:
  - `moon check` passes
  - `moon test` passes
  - `moon coverage analyze` is run
  - uncovered lines in the touched files are reviewed
  - `moon fmt` is run
  - `moon info` is run
  - any formatter/interface churn is reviewed and intentional
  - public API visibility is reviewed against `pkg.generated.mbti`
- If touched executable lines remain uncovered, the task stays open until the
  gap is either covered by tests or explicitly recorded in the task audit with
  reviewer signoff.
- Public API review is part of the gate:
  - every `pub` item touched or newly exposed must have an external consumer
    story
  - public mutable fields require explicit justification
  - pre-existing but unjustified public surface in the touched area must be
    reported as a finding, even if the current patch did not introduce it
- Docs-only tasks do not require MoonBit validation, but they still require a
  review pass for consistency with `docs/architecture.md`, this plan, and
  `AGENTS.md`.

## Dependency graph

`control plane -> package/file mapping -> foundational values -> parser prerequisites -> Parser -> semantic decoders -> stream -> terminal handler -> host bridge -> differential/perf`

## Task template and status legend

Legend:

- `[S]` serial gate
- `[P]` parallel lane
- `[E]` explorer subagent
- `[W]` worker subagent
- `[R]` review by main agent or reviewer subagent
- status: `done`, `todo`, `active`, `blocked`

Task fields:

- `ID`
- `upstream`
- `moonbit target`
- `depends on`
- `parallel with`
- `subagent`
- `acceptance`
- `validation`
- `audit`
- `commit scope`

## Parallelization rules

- A lane may run in parallel only after its dependency gate is `done`.
- A lane must have a distinct target module or write set.
- A lane must not depend on another unfinished lane for acceptance.
- If a task crosses parser layers, run an explorer first and update the
  dependency notes before any worker starts porting.
- If a task cannot end in a green state on its own, it is decomposed wrong and
  must be split differently before implementation starts.

## Subagent playbook

- Main agent: planning, boundary design, review, integration, plan updates,
  commits.
- Explorer subagent: map upstream contracts, hidden dependencies, tests, and
  must-preserve invariants. Output should be a short checklist, not code.
- Worker subagent: implement a bounded translation in a distinct write set with
  explicit validation commands, coverage review evidence, and a green end
  state.
- Reviewer: the main agent by default, or a dedicated review subagent when the
  change is large enough to benefit from an extra pass.

Default flow for each non-trivial delegated task:

1. main agent defines the boundary and acceptance criteria
2. explorer extracts exact upstream contracts if the boundary is not already
   mapped
3. worker creates or updates its subplan under `docs/plans/`
4. worker implements and runs validation
5. reviewer checks the boundary, validation evidence, coverage findings for the
   touched files, and the public API visibility of the touched surface
6. if issues are found, resume the worker and keep the task `active`
7. only then update this plan and land the commit

## Delegated subplans

For non-trivial delegated work, the worker must carry a task-specific subplan
under `docs/plans/`.

Required filename pattern:

- `docs/plans/YYYY-MM-DD-<task-id>-<slug>.md`

Required contents:

- goal
- upstream files
- MoonBit target files
- dependency notes
- acceptance criteria
- validation commands
- coverage findings for touched files
- commit scope
- review findings
- audit/result notes after implementation

These subplans are meant to support both pre-implementation checking and
post-implementation auditing.

## Phase board

### Phase 0: Translation control plane

Gate: `[S]`  
Status: `done`

This phase is docs-only. It must not generate failing code or tests.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P0.1 | done | repo setup | `AGENTS.md` | none | none | main | repo workflow policy documented | doc review | `[R]` main | `docs` |
| P0.2 | done | `ghostty-org/ghostty` | `upstream/ghostty` submodule | none | none | main | upstream source pinned locally | submodule sanity check | `[R]` main | `chore` |
| P0.3 | done | parser stack docs | `docs/architecture.md` | P0.2 | none | main + `[E]` | architecture and data flow documented | doc review | `[R]` main | `docs` |
| P0.4 | done | parser slice inventory | file mapping table in this doc or linked doc | P0.3 | P0.5, P0.6, P0.7 | `[E]` | exact upstream->MoonBit file map recorded | doc review | `[R]` main | `docs` |
| P0.5 | done | parser/test files | translated-test inventory only | P0.3 | P0.4, P0.6, P0.7 | `[E]` | test sources and target locations recorded as inventory, not created as runnable code | doc review | `[R]` main | `docs` |
| P0.6 | done | parser/terminal edges | dependency and ownership map | P0.3 | P0.4, P0.5, P0.7 | `[E]` | serial gates and worker write sets recorded | doc review | `[R]` main | `docs` |
| P0.7 | done | delegated workflow pattern | `docs/plans/` convention and template | P0.3 | P0.4, P0.5, P0.6 | main | delegated task plan convention is documented and available | doc review | `[R]` main | `docs` |

Phase 0 gate:

- P0.4, P0.5, P0.6, and P0.7 are `done`

#### Phase 0 outputs

- Detailed file mapping, translated-test inventory, dependency notes, and
  worker ownership for this gate live in:
  [2026-04-18-p0-control-plane.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-18-p0-control-plane.md)

### Phase 1: Foundations

Gate: `[P]` after Phase 0  
Status: `done`

Every lane in this phase must end with compiling modules, passing tests, and
format/interface checks. Tests land with the code they validate.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P1.0 | done | package boundary decisions | single `src/terminal` package skeleton and file map | P0.4, P0.6, P0.7 | none | main | one `src/terminal` package exists and the planned file layout matches the mapping table | `moon check && moon test && moon fmt && moon info` | `[R]` main | `feat(parser)` |
| P1.A | done | `ansi.zig`, `charsets.zig`, `modes.zig` | corresponding MoonBit modules + tests | P1.0 | P1.B, P1.C | `[W]` | modules compile, tests pass, no missing shared types for downstream parser work | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-foundation)` |
| P1.B | done | `color.zig`, `mouse.zig`, `device_attributes.zig`, `device_status.zig` | corresponding MoonBit modules + tests | P1.0 | P1.A, P1.C | `[W]` | modules compile, tests pass, parser-facing contracts preserved | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-foundation)` |
| P1.C | done | `point.zig`, `size_report.zig`, small report/value types | corresponding MoonBit modules + tests | P1.0 | P1.A, P1.B | `[W]` | modules compile, tests pass, shared constants/types stable | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-foundation)` |

Phase 1 gate:

- P1.0, P1.A, P1.B, and P1.C are `done`

### Phase 2: Parser prerequisites

Gate: `[P]` after Phase 1  
Status: `done`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P2.0 | done | parser-core contracts | phase checklist in this doc and/or subplans | P1.A, P1.B, P1.C | none | `[E]` | exact invariants for UTF-8, parse table, and OSC core recorded before porting | doc review | `[R]` main | `docs` |
| P2.A | done | `UTF8Decoder.zig` | UTF-8 decoder module + translated tests | P2.0 | P2.B, P2.C | `[W]` | retry-on-error semantics preserved and tests pass in the same commit batch | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-core)` |
| P2.B | done | `parse_table.zig` | table-driven parse table module + smoke tests | P2.0 | P2.A, P2.C | `[W]` | generated/table-driven structure preserved and usable by `Parser` | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-core)` |
| P2.C | done | minimal `osc.zig` core needed by `Parser` | OSC parser core scaffold + direct tests | P2.0, P1.A, P1.B | P2.A, P2.B | `[W]` | `Parser` dependency on `osc.Parser` is unblocked without red commits | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-core)` |

Phase 2 gate:

- P2.A, P2.B, and P2.C are `done`

#### Phase 2 outputs

- Phase 2 contract notes and the parser-core boundary decisions for this gate
  live in:
  [2026-04-19-p2-parser-prereqs.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p2-parser-prereqs.md)

### Phase 3: Parser state machine

Gate: `[S]` after Phase 2  
Status: `done`

This phase keeps `Parser` implementation and parser tests together so the core
ordering contract is gated on quality, not just on code landing.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P3.0 | done | `Parser.zig` contract | parser invariants checklist and subplan | P2.A, P2.B, P2.C | none | `[E]` | action ordering, param handling, colon rules, and overflow behavior are recorded before implementation | doc review | `[R]` main | `docs` |
| P3.1 | done | `Parser.zig` and `Parser.zig` tests | parser module + translated tests | P3.0 | none | `[W]` | state, actions, params, OSC embedding, and `next` semantics are ported and parser tests pass in the same green change | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-core)` |

Phase 3 gate:

- P3.1 is `done`

#### Phase 3 outputs

- Phase 3 implementation notes, coverage findings, and review/audit results live
  in:
  [2026-04-19-p3-parser-state-machine.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p3-parser-state-machine.md)

### Phase 3.5: Outbound encoder byte normalization

Gate: `[S]` after Phase 3 / before broader Phase 4 protocol work  
Status: `done`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P3.5 | done | `size_report.zig`, `device_attributes.zig`, `modes.zig` writer-based output | outbound encoder APIs + tests + subplan | P3.1 | none | main + `[R]` | protocol encoders return `Bytes`, tests stay green, semantic text payloads remain `String` | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `refactor(parser-foundation)` |

#### Phase 3.5 outputs

- Protocol-byte refactor notes, validation evidence, and audit details live in:
  [2026-04-19-p3-5-outbound-encoder-bytes.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p3-5-outbound-encoder-bytes.md)

### Phase 3.6: Parser API visibility tightening

Gate: `[S]` after Phase 3.5 / before Phase 7 host-facing API work  
Status: `done`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P3.6 | done | parser-core internals are implementation detail until host API phase | parser/parse-table/osc visibility + subplan | P3.5 | none | main + `[R]` | parser-core scaffolding is removed from package API, mode-state fields are opaque, and `.mbti` only retains the intended semantic/value surface | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `refactor(api)` |

#### Phase 3.6 outputs

- Parser visibility notes, validation evidence, and audit details live in:
  [2026-04-19-p3-6-parser-api-visibility.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p3-6-parser-api-visibility.md)

### Phase 4: Semantic decoders

Gate: `[P]` after Phase 3  
Status: `active`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P4.0 | done | decoder contracts | per-decoder invariants checklist and subplan boundaries | P3.1 | none | `[E]` | SGR/OSC/DCS/APC contracts and hidden dependencies are recorded before worker tasks start | doc review | `[R]` main | `docs` |
| P4.A | done | `sgr.zig` | SGR module + tests | P4.0 | P4.B, P4.C, P4.D, P4.E | `[W]` | colon/semicolon parsing and attribute outputs match upstream with tests in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |
| P4.B | done | `dcs.zig` | DCS handler + tests | P4.0 | P4.A, P4.C, P4.D, P4.E | `[W]` | `hook/put/unhook` semantics and tests pass in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |
| P4.C | todo | `osc.zig` core + high-frequency subparsers | OSC core, title/icon, hyperlink, report pwd, color, semantic prompt, mouse shape + tests | P4.0 | P4.A, P4.B, P4.D, P4.E | `[W]` | high-frequency commands compile and tests pass in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |
| P4.D | todo | remaining OSC subparsers | clipboard, kitty color/clipboard, iTerm2, rxvt, context signal, text sizing + tests | P4.0 | P4.A, P4.B, P4.C, P4.E | `[W]` | long-tail fidelity surface lands in a green state | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |
| P4.E | done | APC-facing helpers | APC support modules + tests | P4.0 | P4.A, P4.B, P4.C, P4.D | `[W]` | helpers compile and match parser-facing expectations with tests | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |

Phase 4 gate:

- P4.0 is `done`
- P4.A, P4.B, and P4.E are `done`
- P4.C and P4.D are pending

#### Phase 4 outputs

- Phase 4 decoder boundary notes and worker write sets live in:
  [2026-04-19-p4-semantic-decoder-contracts.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-semantic-decoder-contracts.md)
- Completed Phase 4 task audits live in:
  [2026-04-19-p4-a-sgr.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-a-sgr.md),
  [2026-04-19-p4-b-dcs.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-b-dcs.md),
  [2026-04-19-p4-e-apc.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-e-apc.md)

### Phase 5: Stream integration

Gate: `[S/P]` after Phase 4  
Status: `active`

`stream.zig` is the semantic join point, so the driver surface is integrated
serially first. After that, dispatch groups can be delegated in parallel, but
each lane must include its own test batch and finish green.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P5.0 | done | `stream.zig` contracts | stream dependency checklist and subplan boundaries | P4.A, P4.B, P4.C, P4.D, P4.E | none | `[E]` | handler contract and dispatch split recorded | doc review | `[R]` main | `docs` |
| P5.1 | done | `stream.zig` driver core | `StreamAction`, handler contract, fast-path scaffolding + base tests | P5.0 | none | main | core compiles, replay ordering is preserved, and base tests pass | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main | `feat(stream)` |
| P5.A | active | `execute`, ESC, CSI subsets | dispatch modules + matching tests | P5.1 | P5.B, P5.C | `[W]` | covered finals behave like upstream and tests pass in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(stream)` |
| P5.B | todo | OSC dispatch wiring | dispatch modules + matching tests | P5.1 | P5.A, P5.C | `[W]` | typed OSC commands route correctly and tests pass in the same task | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(stream)` |
| P5.C | todo | DCS/APC passthrough | dispatch modules + matching tests | P5.1 | P5.A, P5.B | `[W]` | passthrough lifecycle matches upstream and tests pass in the same task | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(stream)` |

Phase 5 gate:

- P5.0 and P5.1 are `done`
- P5.A is `active`
- P5.B and P5.C are pending

#### Phase 5 outputs

- Phase 5 stream boundary notes live in:
  [2026-04-19-p5-stream-contracts.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-stream-contracts.md)
- Phase 5 driver-core implementation audit lives in:
  [2026-04-19-p5-1-stream-driver-core.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-1-stream-driver-core.md)
- Active Phase 5A slice audits live in:
  [2026-04-19-p5-a-foundational-esc-csi.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-foundational-esc-csi.md),
  [2026-04-19-p5-a-tab-and-cursor-controls.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-tab-and-cursor-controls.md),
  [2026-04-19-p5-a-xtwinops-and-title-stack.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-xtwinops-and-title-stack.md),
  [2026-04-19-p5-a-cursor-motion-and-editing.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-cursor-motion-and-editing.md)

### Phase 6: Terminal application surface

Gate: `[P]` after Phase 5  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P6.0 | todo | `stream_terminal.zig` + minimum model deps | terminal dependency checklist and subplan boundaries | P5.C | none | `[E]` | exact minimal model boundary recorded before implementation | doc review | `[R]` main | `docs` |
| P6.A | todo | style + attributes | terminal style modules + tests | P6.0 | P6.B, P6.C | `[W]` | parser-facing style mutations compile and test in the same task | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(terminal)` |
| P6.B | todo | cursor/tabstops/modes | terminal state modules + tests | P6.0 | P6.A, P6.C | `[W]` | cursor and mode actions have minimal backing state and tests | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(terminal)` |
| P6.C | todo | screen/page/hyperlink state | terminal state modules + tests | P6.0 | P6.A, P6.B | `[W]` | parser-facing screen mutations compile and test in the same task | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(terminal)` |
| P6.1 | todo | `stream_terminal.zig` | terminal application bridge + tests | P6.A, P6.B, P6.C | none | main + `[W]` | stream actions apply correctly with separated effects and tests pass in the same task | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(terminal)` |

Phase 6 gate:

- P6.A, P6.B, P6.C, and P6.1 are `done`

### Phase 7: Host bridge and equivalence

Gate: `[S]` after Phase 6  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P7.0 | todo | integrated parser stack | host-bridge checklist and validation corpus notes | P6.1 | none | `[E]` | byte-slice API shape and validation corpus recorded before implementation | doc review | `[R]` main | `docs` |
| P7.1 | todo | VT-facing entry surface | MoonBit byte-slice API + tests | P7.0 | none | main | public parser-facing API exists, is documented, and stays green | `moon check && moon test && moon fmt && moon info` | `[R]` main | `feat(api)` |
| P7.2 | todo | upstream tests/fixtures | differential fixtures and parity suites | P7.1 | none | `[W]` | direct and end-to-end parity checks pass for the agreed corpus | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `test(parity)` |
| P7.3 | todo | hot path behavior | perf notes and focused checks | P7.2 | none | `[W]` | parser hot paths are measured and deviations documented without breaking green status | `moon check && moon test && moon fmt && moon info` | `[R]` main or reviewer subagent | `docs/perf` |

Phase 7 gate:

- P7.1, P7.2, and P7.3 are `done`

## Definition of done

The scoped translation is ready for review when:

- all phase gates through Phase 7 are `done`
- every implementation task landed in a green state
- parser-core, semantic decoders, stream driver, and terminal application
  surface have MoonBit counterparts
- translated tests and differential tests pass for the covered surface
- the MoonBit API can accept byte slices and reproduce upstream parser behavior
- delegated tasks have both subplans and audit records where required
- the mainline history remains atomic and phase-by-phase
