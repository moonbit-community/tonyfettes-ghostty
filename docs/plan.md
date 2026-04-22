# Ghostty Terminal Surface Translation Plan

## Goal and non-goals

Goal:

- Translate the upstream Ghostty terminal parser stack and the full
  `src/terminal/c` surface from Zig to MoonBit as faithfully as possible.

Primary upstream scope:

- `src/terminal/Parser.zig`
- `src/terminal/parse_table.zig`
- `src/terminal/UTF8Decoder.zig`
- `src/terminal/stream.zig`
- `src/terminal/osc.zig`
- `src/terminal/dcs.zig`
- `src/terminal/sgr.zig`
- `src/terminal/stream_terminal.zig`
- every file under `src/terminal/c/`
- the minimum upstream modules those layers require, including terminal model,
  render/formatter state, selection/focus helpers, input encoders, build info,
  and system callback plumbing

Non-goals for now:

- GTK/macOS frontend translation
- full PTY/backend/runtime parity beyond what `src/terminal/c` requires
- renderer/frontend work outside the `src/terminal/c/render.zig` and
  `src/terminal/c/formatter.zig` dependency surface
- native C-callable ABI/export parity
- packaging and distribution parity

Scope completion note:

- Phases 0 through 7 complete the parser-stack foundation and public MoonBit
  host facade.
- Phases 8 through 14 extend that foundation to the full `src/terminal/c`
  semantic surface in MoonBit.

## Implementation target vs ABI target

- The default target for this plan is a faithful MoonBit implementation of the
  full `src/terminal/c` semantic surface.
- `docs/architecture.md` remains the source of truth for the parser-stack
  architecture from Phases 0 through 7. The broader `src/terminal/c` layers
  must record wrapper-specific dependency maps in their own subplans.
- Do not introduce native FFI just to mimic C enums, structs, callbacks, or
  wrapper layering when MoonBit can express the same behavior directly.
- Native FFI/export work is out of scope for this plan.
- In the single `src/terminal` package, do not force a one-wrapper/one-file
  mirror of `src/terminal/c/*.zig`. Prefer extending existing translated owner
  modules when the C wrapper is only projecting behavior that already belongs
  there.
- Treat `main.zig` as package-surface closeout work, not as a required
  MoonBit module. File names are organizational only in MoonBit.
- Where the upstream C surface uses `get/get_multi/set` or output-pointer APIs
  only for ABI reasons, prefer typed MoonBit methods and return values while
  keeping the same reachable semantics.

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

`control plane -> package/file mapping -> foundational values -> parser prerequisites -> Parser -> semantic decoders -> stream -> terminal handler -> host bridge -> c-surface control plane -> stateless c helpers -> parser wrappers -> terminal host object -> input events/encoders -> render/formatter/graphics -> sys/types/main`

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
| P1.0 | done | package boundary decisions | single `src/terminal` package skeleton and file map | P0.4, P0.6, P0.7 | none | main | one `src/terminal` package exists and the planned file layout matches the mapping table | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main | `feat(parser)` |
| P1.A | done | `ansi.zig`, `charsets.zig`, `modes.zig` | corresponding MoonBit modules + tests | P1.0 | P1.B, P1.C | `[W]` | modules compile, tests pass, no missing shared types for downstream parser work | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-foundation)` |
| P1.B | done | `color.zig`, `mouse.zig`, `device_attributes.zig`, `device_status.zig` | corresponding MoonBit modules + tests | P1.0 | P1.A, P1.C | `[W]` | modules compile, tests pass, parser-facing contracts preserved | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-foundation)` |
| P1.C | done | `point.zig`, `size_report.zig`, small report/value types | corresponding MoonBit modules + tests | P1.0 | P1.A, P1.B | `[W]` | modules compile, tests pass, shared constants/types stable | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-foundation)` |

Phase 1 gate:

- P1.0, P1.A, P1.B, and P1.C are `done`

### Phase 2: Parser prerequisites

Gate: `[P]` after Phase 1  
Status: `done`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P2.0 | done | parser-core contracts | phase checklist in this doc and/or subplans | P1.A, P1.B, P1.C | none | `[E]` | exact invariants for UTF-8, parse table, and OSC core recorded before porting | doc review | `[R]` main | `docs` |
| P2.A | done | `UTF8Decoder.zig` | UTF-8 decoder module + translated tests | P2.0 | P2.B, P2.C | `[W]` | retry-on-error semantics preserved and tests pass in the same commit batch | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-core)` |
| P2.B | done | `parse_table.zig` | table-driven parse table module + smoke tests | P2.0 | P2.A, P2.C | `[W]` | generated/table-driven structure preserved and usable by `Parser` | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-core)` |
| P2.C | done | minimal `osc.zig` core needed by `Parser` | OSC parser core scaffold + direct tests | P2.0, P1.A, P1.B | P2.A, P2.B | `[W]` | `Parser` dependency on `osc.Parser` is unblocked without red commits | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-core)` |

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
Status: `done`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P4.0 | done | decoder contracts | per-decoder invariants checklist and subplan boundaries | P3.1 | none | `[E]` | SGR/OSC/DCS/APC contracts and hidden dependencies are recorded before worker tasks start | doc review | `[R]` main | `docs` |
| P4.A | done | `sgr.zig` | SGR module + tests | P4.0 | P4.B, P4.C, P4.D, P4.E | `[W]` | colon/semicolon parsing and attribute outputs match upstream with tests in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |
| P4.B | done | `dcs.zig` | DCS handler + tests | P4.0 | P4.A, P4.C, P4.D, P4.E | `[W]` | `hook/put/unhook` semantics and tests pass in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |
| P4.C | done | `osc.zig` core + high-frequency subparsers | bounded OSC high-frequency parser sub-slices + tests | P4.0 | P4.A, P4.B, P4.D, P4.E | `[W]` | each `P4.C*` sub-slice lands green, and the lane closes only after the translated high-frequency OSC parser surface is implemented and audited | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |
| P4.D | done | remaining OSC subparsers | bounded long-tail OSC parser sub-slices + tests | P4.0, P4.C | P4.A, P4.B, P4.E | `[W]` | each `P4.D*` sub-slice lands green, and the lane closes only after the translated long-tail OSC parser surface is implemented and audited | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |
| P4.E | done | APC-facing helpers | APC support modules + tests | P4.0 | P4.A, P4.B, P4.C, P4.D | `[W]` | helpers compile and match parser-facing expectations with tests | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(parser-protocols)` |

Phase 4 gate:

- P4.0 is `done`
- P4.A, P4.B, and P4.E are `done`
- P4.C is `done`
- P4.D is `done`

#### Phase 4 outputs

- Phase 4 decoder boundary notes and worker write sets live in:
  [2026-04-19-p4-semantic-decoder-contracts.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-semantic-decoder-contracts.md)
- Completed Phase 4 task audits live in:
  [2026-04-19-p4-a-sgr.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-a-sgr.md),
  [2026-04-19-p4-b-dcs.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-b-dcs.md),
  [2026-04-19-p4-e-apc.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-e-apc.md)
- Phase 4C workstream roadmap lives in:
  [2026-04-19-p4-c-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-c-roadmap.md)
- Phase 4D workstream roadmap lives in:
  [2026-04-20-p4-d-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-d-roadmap.md)
- Completed Phase 4C slice audits live in:
  [2026-04-19-p4-c-hyperlink.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p4-c-hyperlink.md),
  [2026-04-20-p4-c-semantic-prompt.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-c-semantic-prompt.md),
  [2026-04-20-p4-c-closeout.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-c-closeout.md)
- Completed Phase 4D slice audits live in:
  [2026-04-20-p4-d1-clipboard.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-d1-clipboard.md),
  [2026-04-20-p4-d2-kitty-color.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-d2-kitty-color.md),
  [2026-04-20-p4-d3-osc9.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-d3-osc9.md),
  [2026-04-20-p4-d4-rxvt-iterm2.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-d4-rxvt-iterm2.md),
  [2026-04-20-p4-d5-kitty-clipboard.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-d5-kitty-clipboard.md),
  [2026-04-20-p4-d6-context-text-sizing.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-d6-context-text-sizing.md),
  [2026-04-20-p4-d7-closeout.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p4-d7-closeout.md)

### Phase 5: Stream integration

Gate: `[S/P]` after Phase 4  
Status: `done`

`stream.zig` is the semantic join point, so the driver surface is integrated
serially first. After that, dispatch groups can be delegated in parallel, but
each lane must include its own test batch and finish green.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P5.0 | done | `stream.zig` contracts | stream dependency checklist and subplan boundaries | P4.A, P4.B, P4.C, P4.D, P4.E | none | `[E]` | handler contract and dispatch split recorded | doc review | `[R]` main | `docs` |
| P5.1 | done | `stream.zig` driver core | `StreamAction`, handler contract, fast-path scaffolding + base tests | P5.0 | none | main | core compiles, replay ordering is preserved, and base tests pass | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main | `feat(stream)` |
| P5.A | done | `execute`, `escDispatch`, `csiDispatch` workstream | bounded dispatch sub-slices + matching tests | P5.1 | P5.B, P5.C | `[W]` | each `P5.A*` sub-slice lands green, and the workstream closes only after a final execute / ESC / CSI parity audit | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(stream)` |
| P5.B | done | OSC dispatch wiring | bounded OSC dispatch sub-slices + matching tests | P5.1 | P5.A, P5.C | `[W]` | each `P5.B*` sub-slice lands green, and the workstream closes only after translated OSC command surface is wired and audited | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(stream)` |
| P5.C | done | DCS/APC passthrough | dispatch modules + matching tests | P5.1 | P5.A, P5.B | `[W]` | passthrough lifecycle matches upstream and tests pass in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(stream)` |

Phase 5 gate:

- P5.0 and P5.1 are `done`
- P5.A is `done`
- P5.B is `done`
- P5.C is `done`
- Phase 5 implementation is complete

#### Phase 5 outputs

- Phase 5 stream boundary notes live in:
  [2026-04-19-p5-stream-contracts.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-stream-contracts.md)
- Phase 5 driver-core implementation audit lives in:
  [2026-04-19-p5-1-stream-driver-core.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-1-stream-driver-core.md)
- Phase 5A workstream roadmap lives in:
  [2026-04-19-p5-a-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-roadmap.md)
- Phase 5B workstream roadmap lives in:
  [2026-04-19-p5-b-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-b-roadmap.md)
- Phase 5C workstream roadmap lives in:
  [2026-04-20-p5-c-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p5-c-roadmap.md)
- Completed Phase 5A slice audits live in:
  [2026-04-19-p5-a-foundational-esc-csi.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-foundational-esc-csi.md),
  [2026-04-19-p5-a-tab-and-cursor-controls.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-tab-and-cursor-controls.md),
  [2026-04-19-p5-a-xtwinops-and-title-stack.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-xtwinops-and-title-stack.md),
  [2026-04-19-p5-a-cursor-motion-and-editing.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-cursor-motion-and-editing.md),
  [2026-04-19-p5-a-margins-and-mode-save-restore.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-margins-and-mode-save-restore.md),
  [2026-04-19-p5-a-device-report-and-esc-controls.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-device-report-and-esc-controls.md),
  [2026-04-19-p5-a-sgr-and-modify-key-format.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-sgr-and-modify-key-format.md),
  [2026-04-19-p5-a-kitty-keyboard.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-kitty-keyboard.md),
  [2026-04-19-p5-a-closeout-audit.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-a-closeout-audit.md)
- Completed Phase 5B slice audits live in:
  [2026-04-19-p5-b-current-osc-core.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-b-current-osc-core.md),
  [2026-04-19-p5-b-hyperlink-dispatch.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p5-b-hyperlink-dispatch.md),
  [2026-04-20-p5-b-semantic-prompt-dispatch.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p5-b-semantic-prompt-dispatch.md),
  [2026-04-20-p5-b-clipboard-kitty-color-dispatch.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p5-b-clipboard-kitty-color-dispatch.md),
  [2026-04-20-p5-b-notification-progress-dispatch.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p5-b-notification-progress-dispatch.md),
  [2026-04-20-p5-b-long-tail-no-op-audit.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p5-b-long-tail-no-op-audit.md)
- Completed Phase 5C slice audits live in:
  [2026-04-20-p5-c1-apc-passthrough.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p5-c1-apc-passthrough.md),
  [2026-04-20-p5-c2-dcs-facade-and-passthrough.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p5-c2-dcs-facade-and-passthrough.md),
  [2026-04-20-p5-c4-closeout-audit.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p5-c4-closeout-audit.md)

### Phase 6: Terminal application surface

Gate: `[P]` after Phase 5  
Status: `done`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P6.0 | done | `stream_terminal.zig` + minimum model deps | terminal dependency checklist and subplan boundaries | P5.C | none | `[E]` | exact minimal model boundary recorded before implementation | doc review | `[R]` main | `docs` |
| P6.A | done | style + attributes | terminal style modules + tests | P6.0 | P6.B, P6.C | `[W]` | parser-facing style mutations compile and test in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(terminal)` |
| P6.B | done | cursor/tabstops/modes | terminal state modules + tests | P6.0 | P6.A, P6.C | `[W]` | cursor and mode actions have minimal backing state and tests | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(terminal)` |
| P6.C | done | screen/page/hyperlink state | terminal state modules + tests | P6.0 | P6.A, P6.B | `[W]` | parser-facing screen mutations compile and test in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(terminal)` |
| P6.1 | done | `stream_terminal.zig` | terminal application bridge + tests | P6.A, P6.B, P6.C | none | main + `[W]` | stream actions apply correctly with separated effects and tests pass in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(terminal)` |

Phase 6 gate:

- P6.0 is `done`
- P6.A and P6.B are `done`
- P6.C is `done`
- P6.1 is `done`

#### Phase 6 outputs

- Phase 6 boundary notes live in:
  [2026-04-20-p6-0-terminal-dependency-checklist.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-0-terminal-dependency-checklist.md)
- Phase 6A workstream roadmap lives in:
  [2026-04-20-p6-a-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-a-roadmap.md)
- Phase 6B workstream roadmap lives in:
  [2026-04-20-p6-b-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-b-roadmap.md)
- Phase 6C workstream roadmap lives in:
  [2026-04-21-p6-c-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-c-roadmap.md)
- Completed Phase 6A slice audits live in:
  [2026-04-20-p6-a1-style-core.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-a1-style-core.md)
  [2026-04-20-p6-a2-dynamic-colors.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-a2-dynamic-colors.md)
  [2026-04-20-p6-a3-protected-display-state.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-a3-protected-display-state.md)
- Completed Phase 6B slice audits live in:
  [2026-04-20-p6-b1-input-flags-and-keyboard.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-b1-input-flags-and-keyboard.md)
  [2026-04-21-p6-b2-cursor-geometry-and-margins.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-b2-cursor-geometry-and-margins.md)
  [2026-04-21-p6-b3-saved-cursor-and-charset.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-b3-saved-cursor-and-charset.md)
  [2026-04-21-p6-b4-tabstop-state.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-b4-tabstop-state.md)
- Completed Phase 6C slice audits live in:
  [2026-04-21-p6-c1-hyperlink-and-semantic-metadata.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-c1-hyperlink-and-semantic-metadata.md)
  [2026-04-21-p6-c2-title-and-aux-metadata.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-c2-title-and-aux-metadata.md)
  [2026-04-21-p6-c3-page-row-and-cell-values.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-c3-page-row-and-cell-values.md)
  [2026-04-21-p6-c4-screen-grid-and-mutations.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-c4-screen-grid-and-mutations.md)
- Phase 6.1 bridge slicing notes live in:
  [2026-04-20-p6-1-bridge-roadmap.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-1-bridge-roadmap.md)
- Completed Phase 6.1 slice audits live in:
  [2026-04-20-p6-1-a-phase6a-bridge.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-1-a-phase6a-bridge.md)
  [2026-04-21-p6-1-b-cursor-mode-tab-bridge.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-1-b-cursor-mode-tab-bridge.md)
  [2026-04-21-p6-1-c-screen-mutation-bridge.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-1-c-screen-mutation-bridge.md)
  [2026-04-21-p6-1-d-query-and-side-effect-bridge.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-1-d-query-and-side-effect-bridge.md)

### Phase 7: Host bridge and equivalence

Gate: `[S]` after Phase 6  
Status: `done`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P7.0 | done | integrated parser stack | host-bridge checklist and validation corpus notes | P6.1 | none | `[E]` | byte-slice API shape and validation corpus recorded before implementation | doc review | `[R]` main | `docs` |
| P7.1 | done | VT-facing entry surface | MoonBit byte-slice API + tests | P7.0 | none | main | public parser-facing API exists, is documented, and stays green | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main | `feat(api)` |
| P7.2 | done | upstream tests/fixtures | differential fixtures and parity suites | P7.1 | none | `[W]` | direct and end-to-end parity checks pass for the agreed corpus | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `test(parity)` |
| P7.3 | done | hot path behavior | perf notes and focused checks | P7.2 | none | `[W]` | parser hot paths are measured and deviations documented without breaking green status | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `docs/perf` |

Phase 7 gate:

- P7.0, P7.1, P7.2, and P7.3 are `done`

#### Phase 7 outputs

- Phase 7 host-bridge checklist and parity corpus notes live in:
  [2026-04-21-p7-0-host-bridge-checklist.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p7-0-host-bridge-checklist.md)
- Phase 7 implementation audits live in:
  [2026-04-21-p7-1-stream-terminal-facade.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p7-1-stream-terminal-facade.md)
  [2026-04-21-p7-2-facade-parity-suite.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p7-2-facade-parity-suite.md)
  [2026-04-21-p7-3-hot-path-perf-notes.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p7-3-hot-path-perf-notes.md)
- Phase 7 completed the parser-stack foundation; `P8.0` is the next planned
  task.

### Phase 8: `src/terminal/c` control plane

Gate: `[S]` after Phase 7  
Status: `done`

This phase rebases the denominator from parser-stack-only work to the full
`src/terminal/c` surface. It is docs-only and must not introduce code or API
surface.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P8.0 | done | `src/terminal/c/*.zig` inventory | c-surface file map, dependency clusters, and follow-on subplan boundaries | P7.3 | none | main + `[E]` | every wrapper under `src/terminal/c` is assigned to a phase/lane and cross-package deps are recorded before implementation starts | doc review | `[R]` main | `docs` |
| P8.A | done | MoonBit target policy for `src/terminal/c` | pure-MoonBit surface policy note in this doc and task subplans | P8.0 | none | `[E]` | pure-MoonBit semantic parity is the default target, and C-only ABI helpers are either absorbed or declared out of scope before implementation starts | doc review | `[R]` main | `docs` |

Phase 8 gate:

- P8.0 and P8.A are `done`

#### Phase 8 outputs

- Phase 8 inventory and dependency mapping live in:
  [2026-04-21-p8-0-terminal-c-surface-control-plane.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p8-0-terminal-c-surface-control-plane.md)
- Phase 8 target-policy notes live in:
  [2026-04-21-p8-a-moonbit-surface-target.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p8-a-moonbit-surface-target.md)
- Phase 8 is complete; `P9.A`, `P9.B`, and `P9.C` are the next available
  implementation lanes.

### Phase 9: Stateless C-surface helpers

Gate: `[P]` after Phase 8  
Status: `active`

These wrappers are the low-dependency foundation for the broader C-surface
port. They should land before terminal/render wrappers start leaning on them.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P9.A | done | `result.zig`, `build_info.zig` | shared result/build-info surface + tests | P8.A | P9.B, P9.C | `[W]` | error/result/build metadata match upstream contracts with tests in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-surface-foundation)` |
| P9.B | done | `color.zig`, `style.zig`, `modes.zig`, `focus.zig`, `size_report.zig`, `paste.zig` | extensions to existing owner modules + tests | P8.A | P9.A, P9.C | `[W]` | stateless encoders, value projections, and small helper contracts land in MoonBit owner modules with tests | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-surface-foundation)` |
| P9.C | done | `selection.zig`, `row.zig`, `cell.zig` | page/selection view helpers + tests | P8.A, P9.B | P9.A | `[W]` | row/cell data views and selection structs match upstream contracts with tests in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-surface-foundation)` |

Phase 9 progress:

- P9.A, P9.B, and P9.C are `done`

#### Phase 9 outputs

- Completed Phase 9A audit lives in:
  [2026-04-21-p9-a-result-and-build-info.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p9-a-result-and-build-info.md)
- Completed Phase 9B audit lives in:
  [2026-04-22-p9-b-stateless-helper-surface.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p9-b-stateless-helper-surface.md)
- Completed Phase 9C audit lives in:
  [2026-04-22-p9-c-row-cell-selection-surface.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p9-c-row-cell-selection-surface.md)

### Phase 10: Parser object wrappers

Gate: `[P]` after Phase 9  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P10.A | done | `src/terminal/c/osc.zig` | host-facing OSC helper surface + tests | P9.A, P9.B | P10.B | `[W]` | constructor/reset/next/end/data-query parity matches upstream tests and stays green in one task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-parsers)` |
| P10.B | done | `src/terminal/c/sgr.zig` | host-facing SGR helper surface + tests | P9.A, P9.B | P10.A | `[W]` | parameter feed, next/unknown handling, and attribute query parity match upstream tests in one task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-parsers)` |

Phase 10 gate:

- P10.A and P10.B are `done`

#### Phase 10 outputs

- Completed Phase 10A audit lives in:
  [2026-04-22-p10-a-osc-helper-surface.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p10-a-osc-helper-surface.md)
- Completed Phase 10B audit lives in:
  [2026-04-22-p10-b-sgr-helper-surface.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p10-b-sgr-helper-surface.md)

### Phase 11: Terminal host object parity

Gate: `[S/P]` after Phase 10  
Status: `active`

This phase broadens the current `StreamTerminal` facade and adjacent terminal
helpers toward the richer `src/terminal/c/terminal.zig` host surface, while
keeping kitty-graphics-only fields deferred until Phase 13C.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P11.0 | done | `terminal.zig`, `grid_ref.zig` contracts | terminal host-surface checklist and write-set split | P10.A, P10.B, P9.C | none | `[E]` | callbacks, query surface, viewport/grid pinning, and graphics deferrals are recorded before worker tasks start | doc review | `[R]` main | `docs` |
| P11.A | done | `src/terminal/c/terminal.zig` core host controls | `StreamTerminal` callback/control surface + tests | P11.0, P9.A, P9.B | none | main + `[W]` | `new/free/vt_write`, runtime effect replacement/clearing, `reset`, `mode_get`, `mode_set`, and host metadata setters land as MoonBit owner methods with upstream non-graphics tests in one green task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-terminal)` |
| P11.B0 | done | `src/terminal/c/terminal.zig` viewport/screen substrate | screen-set, scrollback, resize, viewport, and page-pin groundwork + tests | P11.0, P11.A, P9.C | none | main + `[W]` | active/alt screen state, pixel dimensions, total/scrollback row accounting, `resize`, `scroll_viewport`, and page-pin substrate land green and unblock faithful grid refs and typed host queries | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-terminal)` |
| P11.B | done | `src/terminal/c/grid_ref.zig` | grid pin/query helpers + tests | P11.0, P9.C, P11.B0 | P11.C | `[W]` | row/cell/style/hyperlink/grapheme access from terminal grid refs matches upstream contracts with tests in the same task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-terminal)` |
| P11.C | done | `src/terminal/c/terminal.zig` query surface | typed terminal query surface + tests | P11.0, P11.A, P11.B0, P9.B, P9.C | P11.B | `[W]` | non-graphics terminal data, metadata, scrollback, and default/current color state close as typed MoonBit queries; kitty graphics fields stay deferred to P13.C | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-terminal)` |

Phase 11 gate:

- P11.0, P11.A, P11.B0, P11.B, and P11.C are `done`

#### Phase 11 outputs

- Completed P11.0 checklist lives in:
  [2026-04-22-p11-0-terminal-host-surface-checklist.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p11-0-terminal-host-surface-checklist.md)
- Completed P11.A audit lives in:
  [2026-04-22-p11-a-host-control-surface.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p11-a-host-control-surface.md)
- Completed P11.B0 audit lives in:
  [2026-04-22-p11-b0-viewport-screen-substrate.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p11-b0-viewport-screen-substrate.md)
- Completed P11.B audit lives in:
  [2026-04-22-p11-b-grid-ref-surface.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p11-b-grid-ref-surface.md)
- Completed P11.C audit lives in:
  [2026-04-22-p11-c-typed-terminal-query-surface.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p11-c-typed-terminal-query-surface.md)

### Phase 12: Input events and encoders

Gate: `[P]` after Phase 11  
Status: `active`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P12.A | done | `key_event.zig`, `mouse_event.zig` | input event owner types + tests | P9.A | P12.B | `[W]` | create/free/get/set parity for key and mouse events lands as MoonBit owner types with upstream behavior tests in one task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-input)` |
| P12.B | todo | `key_encode.zig`, `mouse_encode.zig` | input encoder surfaces + tests | P12.A, P11.A, P9.B | P12.A | `[W]` | encoder option surfaces and terminal-derived defaults match upstream tests in one task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-input)` |

Phase 12 gate:

- P12.A is `done`
- P12.B remains `todo`

#### Phase 12 outputs

- Completed P12.A audit lives in:
  [2026-04-22-p12-a-input-event-owner-types.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-22-p12-a-input-event-owner-types.md)

### Phase 13: Render, formatter, and graphics wrappers

Gate: `[S/P]` after Phase 11 and Phase 12  
Status: `todo`

These wrappers sit on broader terminal/render state and should only start after
the terminal host object and input helper layers are stable.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P13.0 | todo | `render.zig`, `formatter.zig`, `kitty_graphics.zig` contracts | dependency checklist and write-set split | P11.C, P12.B | none | `[E]` | render-state, formatter, selection/grid, and kitty-graphics deps are recorded before worker tasks start | doc review | `[R]` main | `docs` |
| P13.A | todo | `src/terminal/c/render.zig` | render-state surface + tests | P13.0, P11.C | P13.B, P13.C | `[W]` | render snapshots, row iteration, row-cell query/mutation, and dirty-state parity land green in one task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-render)` |
| P13.B | todo | `src/terminal/c/formatter.zig` | formatter surface + tests | P13.0, P11.B, P9.C | P13.A, P13.C | `[W]` | terminal/screen formatting buffer and allocation paths match upstream tests in one task, using MoonBit-owned results instead of C allocation helpers | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-render)` |
| P13.C | todo | `src/terminal/c/kitty_graphics.zig` + remaining `terminal.zig` graphics hooks | graphics wrapper + terminal graphics parity + tests | P13.0, P11.A, P11.B, P11.C | P13.A, P13.B | `[W]` | image/query/placement surface lands green and closes the remaining graphics-dependent terminal fields | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-render)` |

Phase 13 gate:

- P13.0, P13.A, P13.B, and P13.C remain `todo`

### Phase 14: Sys, type metadata, and aggregate C surface

Gate: `[P]` after Phase 13  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | validation | audit | commit scope |
|---|---|---|---|---|---|---|---|---|---|---|
| P14.A | todo | `src/terminal/c/sys.zig` | system callback/config wrapper + tests | P9.A | P14.B | `[W]` | logging/image-decode callback registry matches upstream contracts with tests in one task | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-runtime)` |
| P14.B | todo | `src/terminal/c/types.zig` | typed surface registry + tests | P13.A, P13.B, P13.C, P12.B, P11.C, P9.C | P14.A | `[W]` | translated metadata reflects the implemented surface and stays green in one task; JSON stays a derived representation if still needed | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main or reviewer subagent | `feat(c-runtime)` |
| P14.C | todo | `src/terminal/c/main.zig` | package-surface closeout + smoke tests | P14.A, P14.B | none | main + `[W]` | the final package API is coherent, intentional, and covered by smoke tests without creating a redundant aggregator module | `moon check && moon test && moon coverage analyze && moon fmt && moon info` | `[R]` main | `feat(c-runtime)` |

Phase 14 gate:

- P14.A, P14.B, and P14.C remain `todo`
- Phase 14 completion will close pure-MoonBit parity for the full
  `src/terminal/c` semantic surface

## Definition of done

The translated terminal surface is ready for review when:

- all phase gates through Phase 14 are `done` for the pure-MoonBit target
- every implementation task landed in a green state
- parser-core, semantic decoders, stream driver, terminal application surface,
  and every wrapper under `src/terminal/c` have MoonBit counterparts
- translated tests and parity suites pass for the covered surface
- the MoonBit API can reproduce the upstream parser and `src/terminal/c`
  behavior for the agreed scope
- delegated tasks have both subplans and audit records where required
- the mainline history remains atomic and phase-by-phase
