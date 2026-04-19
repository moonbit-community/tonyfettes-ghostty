# P3.1 Parser State Machine

## Goal

Port the core `Parser.zig` state machine into MoonBit as a parse-table-driven
`Parser` that preserves upstream action ordering, parameter handling, and the
embedded OSC/DCS/APC lifecycle, with the implementation and its tests landing
green in one slice.

## Upstream files

- `upstream/ghostty/src/terminal/Parser.zig`
- `upstream/ghostty/src/terminal/parse_table.zig`
- `upstream/ghostty/src/terminal/osc.zig`

## MoonBit target files

- `src/terminal/parser.mbt`
- `src/terminal/parser_wbtest.mbt`
- `docs/plans/2026-04-19-p3-parser-state-machine.md`
- `docs/plan.md`

## Dependency notes

- Depends on the Phase 3 contract checklist in
  [2026-04-19-p3-parser-contract.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-19-p3-parser-contract.md).
- Reuses:
  - `ParserState`, `TransitionAction`, and `transition_for` from the Phase 2
    parser-core work
  - `OscParser` and `Command` from the OSC prerequisite slice
- Keeps the single-package `src/terminal` layout chosen in Phase 1.
- Local adaptation:
  - parser actions return copied arrays instead of ephemeral Zig slices
  - public dispatch payloads use `final_byte` field names to avoid reserved-word
    friction in MoonBit

## Acceptance criteria

- `Parser::next` preserves the three output slots:
  1. exit action from the old state
  2. transition action from the parse-table entry
  3. entry action for the new state
- Parser state changes happen after those slots are computed.
- CSI, ESC, DCS, OSC, and APC paths preserve the Phase 3 contract behavior.
- Parser white-box tests cover:
  - print/execute smoke
  - ESC dispatch and intermediate overflow
  - CSI params, intermediates, colon handling, colon rejection, param overflow,
    and long-digit saturation
  - OSC BEL/ST behavior and embedded OSC parsing
  - DCS hook/put/unhook and param overflow
  - APC start/put/end ordering
- `moon check`, `moon test`, `moon coverage analyze`, `moon fmt`, and
  `moon info` all pass at the end of the slice.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/parser.mbt`: 0 uncovered lines after adding overflow-path tests
  for intermediate truncation and long numeric CSI params.
- `src/terminal/parser_wbtest.mbt`: test file for the slice; no uncovered code
  reported by `moon coverage analyze`.
- Residual repository-wide uncovered lines remain in `src/terminal/osc.mbt`,
  `src/terminal/modes.mbt`, and `src/terminal/color.mbt`, but those files are
  outside this slice's write set.

## Commit scope

- `feat(parser-core): add parser state machine`

## Review findings

- Main-agent review:
  - confirmed the parser remains table-driven via `transition_for`
  - confirmed exit/transition/entry ordering stays explicit in
    `Parser::next`
  - confirmed touched-file coverage is closed for `src/terminal/parser.mbt`
- Reviewer-subagent pass:
  - found no correctness risk in `Parser::next` ordering or state-update timing
  - requested one additional scenario test for positive mixed `;`/`:` SGR
    dispatch
  - that gap was closed in `parser_wbtest.mbt`

## Audit/result notes

- Added `src/terminal/parser.mbt` with:
  - parser action payload types
  - parser state storage
  - `Parser::next`, `Parser::clear`, and parser-local helpers
- Added `src/terminal/parser_wbtest.mbt` with direct state-machine tests across
  ESC, CSI, OSC, DCS, and APC behavior.
- Added overflow-path coverage for:
  - excess ESC intermediates
  - excessively long CSI numeric runs
- Added mixed-separator SGR coverage after reviewer feedback.
