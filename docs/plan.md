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
- keep one atomic mainline commit per completed task or integration batch

## Dependency graph

`package/file mapping -> foundational values -> parser prerequisites -> Parser -> semantic decoders -> stream -> terminal handler -> host bridge -> differential/perf`

## Task template / status legend

Legend:

- `[S]` serial gate
- `[P]` parallel lane
- `[E]` explorer subagent
- `[W]` worker subagent
- status: `done`, `todo`, `active`, `blocked`

Task fields:

- `ID`
- `upstream`
- `moonbit target`
- `depends on`
- `parallel with`
- `subagent`
- `acceptance`
- `commit scope`

## Parallelization rules

- A lane may run in parallel only after its dependency gate is `done`.
- A lane must have a distinct target module or write set.
- A lane must not depend on another unfinished lane for acceptance.
- If a task crosses parser layers, run an explorer first and update the
  dependency notes before any worker starts porting.

## Subagent playbook

- Main agent: planning, boundary design, review, integration, plan updates,
  commits.
- Explorer subagent: map upstream contracts, hidden dependencies, tests, and
  must-preserve invariants. Output should be a short checklist, not code.
- Worker subagent: implement a bounded translation in a distinct write set with
  explicit validation commands.

Default flow for each non-trivial phase:

1. main agent defines the boundary
2. explorer extracts exact upstream contracts
3. workers translate isolated targets
4. main agent verifies the boundary, updates this plan, and commits

## Phase board

### Phase 0: Translation control plane

Gate: `[S]`  
Status: `active`

This phase establishes the map and control documents needed for all later
delegation.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | commit scope |
|---|---|---|---|---|---|---|---|---|
| P0.1 | done | repo setup | `AGENTS.md` | none | none | main | commit discipline documented | `docs` |
| P0.2 | done | `ghostty-org/ghostty` | `upstream/ghostty` submodule | none | none | main | upstream source pinned locally | `chore` |
| P0.3 | done | parser stack docs | `docs/architecture.md` | P0.2 | none | main + `[E]` | architecture/data flow documented | `docs` |
| P0.4 | todo | parser slice inventory | file mapping table in this doc or linked doc | P0.3 | P0.5, P0.6 | `[E]` | exact upstream->MoonBit file map recorded | `docs` |
| P0.5 | todo | parser/test files | translated-test inventory | P0.3 | P0.4, P0.6 | `[E]` | test sources and expected MoonBit homes listed | `docs` |
| P0.6 | todo | parser/terminal edges | dependency and ownership map | P0.3 | P0.4, P0.5 | `[E]` | serial gates and worker write sets recorded | `docs` |

Phase 0 gate:

- P0.4, P0.5, and P0.6 are `done`

### Phase 1: Foundations

Gate: `[P]` after Phase 0  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | commit scope |
|---|---|---|---|---|---|---|---|---|
| P1.1 | todo | package boundary decisions | package skeleton | P0.4, P0.6 | none | main | package layout exists and matches mapping table | `feat(parser)` |
| P1.A | todo | `ansi.zig`, `charsets.zig`, `modes.zig` | corresponding MoonBit modules | P1.1 | P1.B, P1.C | `[W]` | compile, tests added if direct ones exist, plan updated | `feat(parser-foundation)` |
| P1.B | todo | `color.zig`, `mouse.zig`, `device_attributes.zig`, `device_status.zig` | corresponding MoonBit modules | P1.1 | P1.A, P1.C | `[W]` | compile, parser-facing contracts preserved | `feat(parser-foundation)` |
| P1.C | todo | `point.zig`, `size_report.zig`, small report/value types | corresponding MoonBit modules | P1.1 | P1.A, P1.B | `[W]` | compile, shared constants/types stable | `feat(parser-foundation)` |

Phase 1 gate:

- P1.1, P1.A, P1.B, and P1.C are `done`

### Phase 2: Parser prerequisites

Gate: `[P]` after Phase 1  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | commit scope |
|---|---|---|---|---|---|---|---|---|
| P2.0 | todo | parser-core contracts | phase checklist in this doc | P1.A, P1.B, P1.C | none | `[E]` | exact invariants for UTF-8, parse table, and OSC core recorded | `docs` |
| P2.A | todo | `UTF8Decoder.zig` | UTF-8 decoder module + tests | P2.0 | P2.B, P2.C | `[W]` | retry-on-error semantics preserved, translated tests pass | `feat(parser-core)` |
| P2.B | todo | `parse_table.zig` | table-driven parse table module | P2.0 | P2.A, P2.C | `[W]` | generated/table-driven structure preserved, colon extension covered | `feat(parser-core)` |
| P2.C | todo | minimal `osc.zig` core needed by `Parser` | OSC parser core scaffold | P2.0, P1.A, P1.B | P2.A, P2.B | `[W]` | `Parser` dependencies on `osc.Parser` are unblocked | `feat(parser-core)` |

Phase 2 gate:

- P2.A, P2.B, and P2.C are `done`

### Phase 3: Parser state machine

Gate: `[S]` after Phase 2  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | commit scope |
|---|---|---|---|---|---|---|---|---|
| P3.0 | todo | `Parser.zig` contract | parser invariants checklist | P2.A, P2.B, P2.C | none | `[E]` | action ordering, param handling, and overflow rules recorded | `docs` |
| P3.1 | todo | `Parser.zig` | parser module | P3.0 | none | `[W]` | state, actions, params, OSC embedding, and `next` semantics ported | `feat(parser-core)` |
| P3.2 | todo | `Parser.zig` tests | parser test suite | P3.1 | none | `[W]` | CSI, OSC, DCS, colon-SGR, and overflow tests pass | `test(parser-core)` |

Phase 3 gate:

- P3.1 and P3.2 are `done`

### Phase 4: Semantic decoders

Gate: `[P]` after Phase 3  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | commit scope |
|---|---|---|---|---|---|---|---|---|
| P4.0 | todo | decoder contracts | per-decoder invariants checklist | P3.2 | none | `[E]` | SGR/OSC/DCS/APC contracts and dependencies recorded | `docs` |
| P4.A | todo | `sgr.zig` | SGR module + tests | P4.0 | P4.B, P4.C, P4.D, P4.E | `[W]` | colon/semicolon parsing and attribute outputs match upstream | `feat(parser-protocols)` |
| P4.B | todo | `dcs.zig` | DCS handler + tests | P4.0 | P4.A, P4.C, P4.D, P4.E | `[W]` | `hook/put/unhook` semantics and tests pass | `feat(parser-protocols)` |
| P4.C | todo | `osc.zig` core + high-frequency parsers | OSC core, title/icon, hyperlink, report pwd, color, semantic prompt, mouse shape | P4.0 | P4.A, P4.B, P4.D, P4.E | `[W]` | high-frequency commands compile and tests pass | `feat(parser-protocols)` |
| P4.D | todo | remaining OSC subparsers | clipboard, kitty color/clipboard, iTerm2, rxvt, context signal, text sizing | P4.0 | P4.A, P4.B, P4.C, P4.E | `[W]` | long-tail fidelity surface implemented with tests | `feat(parser-protocols)` |
| P4.E | todo | APC-facing helpers | APC support modules | P4.0 | P4.A, P4.B, P4.C, P4.D | `[W]` | helpers compile and match parser-facing expectations | `feat(parser-protocols)` |

Phase 4 gate:

- P4.A, P4.B, P4.C, P4.D, and P4.E are `done`

### Phase 5: Stream integration

Gate: `[S/P]` after Phase 4  
Status: `todo`

`stream.zig` is the semantic join point, so the top-level phase is serial even
though some sub-work can be delegated in parallel once the driver surface is
fixed.

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | commit scope |
|---|---|---|---|---|---|---|---|---|
| P5.0 | todo | `stream.zig` contracts | stream dependency checklist | P4.A, P4.B, P4.C, P4.D, P4.E | none | `[E]` | handler contract and dispatch split recorded | `docs` |
| P5.1 | todo | `stream.zig` driver core | `Stream.Action`, handler contract, fast-path scaffolding | P5.0 | none | main | core compiles and replay ordering is preserved | `feat(stream)` |
| P5.A | todo | `execute`, ESC, CSI subsets | dispatch modules/tests | P5.1 | P5.B, P5.C, P5.D | `[W]` | covered finals behave like upstream and tests pass | `feat(stream)` |
| P5.B | todo | OSC dispatch wiring | dispatch modules/tests | P5.1 | P5.A, P5.C, P5.D | `[W]` | typed OSC commands route correctly | `feat(stream)` |
| P5.C | todo | DCS/APC passthrough | dispatch modules/tests | P5.1 | P5.A, P5.B, P5.D | `[W]` | passthrough lifecycle matches upstream | `feat(stream)` |
| P5.D | todo | translated `stream.zig` tests | stream test batches | P5.1 | P5.A, P5.B, P5.C | `[W]` | tests land with the dispatch they verify | `test(stream)` |

Phase 5 gate:

- P5.1, P5.A, P5.B, P5.C, and P5.D are `done`

### Phase 6: Terminal application surface

Gate: `[P]` after Phase 5  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | commit scope |
|---|---|---|---|---|---|---|---|---|
| P6.0 | todo | `stream_terminal.zig` + minimum model deps | terminal dependency checklist | P5.D | none | `[E]` | exact minimal model boundary recorded | `docs` |
| P6.A | todo | style + attributes | terminal style modules | P6.0 | P6.B, P6.C | `[W]` | parser-facing style mutations compile and test | `feat(terminal)` |
| P6.B | todo | cursor/tabstops/modes | terminal state modules | P6.0 | P6.A, P6.C | `[W]` | cursor and mode actions have minimal backing state | `feat(terminal)` |
| P6.C | todo | screen/page/hyperlink state | terminal state modules | P6.0 | P6.A, P6.B | `[W]` | parser-facing screen mutations compile and test | `feat(terminal)` |
| P6.1 | todo | `stream_terminal.zig` | terminal application bridge | P6.A, P6.B, P6.C | none | main + `[W]` | stream actions apply correctly with separated effects | `feat(terminal)` |

Phase 6 gate:

- P6.A, P6.B, P6.C, and P6.1 are `done`

### Phase 7: Host bridge and equivalence

Gate: `[S]` after Phase 6  
Status: `todo`

| ID | status | upstream | moonbit target | depends on | parallel with | subagent | acceptance | commit scope |
|---|---|---|---|---|---|---|---|---|
| P7.0 | todo | integrated parser stack | host-bridge checklist | P6.1 | none | `[E]` | byte-slice API shape and validation corpus recorded | `docs` |
| P7.1 | todo | VT-facing entry surface | MoonBit byte-slice API | P7.0 | none | main | public parser-facing API exists and is documented | `feat(api)` |
| P7.2 | todo | upstream tests/fixtures | differential fixtures and translated suites | P7.1 | none | `[W]` | direct and end-to-end parity checks pass for agreed corpus | `test(parity)` |
| P7.3 | todo | hot path behavior | perf notes and focused checks | P7.2 | none | `[W]` | parser hot paths measured and deviations documented | `docs/perf` |

Phase 7 gate:

- P7.1, P7.2, and P7.3 are `done`

## Definition of done

The scoped translation is ready for review when:

- all phase gates through Phase 7 are `done`
- parser-core, semantic decoders, stream driver, and terminal application
  surface have MoonBit counterparts
- translated tests and differential tests pass for the covered surface
- the MoonBit API can accept byte slices and reproduce upstream parser behavior
- the mainline history remains atomic and phase-by-phase
