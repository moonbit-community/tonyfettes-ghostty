# Phase 3 Parser Contract

## Goal

Record the exact `Parser.zig` invariants and the minimum green test surface
needed to land the Phase 3 parser state machine in MoonBit without reopening
the Phase 2 parser-core boundaries.

## Upstream files

- `upstream/ghostty/src/terminal/Parser.zig`
- `upstream/ghostty/src/terminal/parse_table.zig`
- `upstream/ghostty/src/terminal/osc.zig`

## MoonBit target files

- `docs/plans/2026-04-19-p3-parser-contract.md`
- `src/terminal/parser.mbt`
- `src/terminal/parser_wbtest.mbt`

## Dependencies and invariants

- `Parser.next`
  - Preserve the upstream three-action ordering exactly:
    1. exit action from the old state
    2. transition action from the table entry
    3. entry action for the new state
  - Preserve state assignment after those actions are determined.

- parser-state transitions
  - Drive all transitions from the generated parse table in `parse_table.mbt`.
  - Reuse the shared parser enums from `parser_core_types.mbt`.
  - Preserve the state-entry side effects:
    - entering `Escape`, `DcsEntry`, or `CsiEntry` clears intermediates and
      parameter state
    - entering `OscString` resets the dedicated OSC parser
    - entering `DcsPassthrough` may emit `dcs_hook`
    - entering `SosPmApcString` emits `apc_start`
  - Preserve the state-exit side effects:
    - leaving `OscString` may emit `osc_dispatch`
    - leaving `DcsPassthrough` emits `dcs_unhook`
    - leaving `SosPmApcString` emits `apc_end`

- parameter handling
  - Preserve the upstream fixed limits:
    - `MAX_INTERMEDIATE = 4`
    - `MAX_PARAMS = 24`
  - Preserve parameter accumulation behavior:
    - `;` and `:` finalize the current parameter and start the next one
    - blank params become `0`
    - numeric accumulation saturates to the `u16` range
    - excessively long numeric runs stop affecting the action result
  - Preserve separator tracking:
    - record which parameter boundaries were `:`
    - only allow colon or mixed separators for final `m`
    - for non-`m` finals, mixed or colon-separated CSI input must dispatch no
      action

- overflow and ignore behavior
  - Preserve upstream overflow handling:
    - too many CSI params suppress `csi_dispatch`
    - too many DCS params suppress `dcs_hook`
    - too many intermediates are ignored rather than crashing
  - Preserve the parser-state behavior implied by the table:
    `csi_ignore`, `dcs_ignore`, and other ignore paths still transition, but
    user-visible dispatch may be dropped.

- OSC embedding
  - Preserve the dedicated OSC parser integration:
    - `osc_put` forwards bytes to `OscParser.next`
    - exit from `OscString` calls `OscParser.end` with the terminating byte
  - Preserve terminator handling:
    - `BEL` terminates immediately
    - `ESC \` terminates on the `ESC` byte and leaves the trailing `\` to the
      outer parser

- local adaptations
  - MoonBit can return copied arrays/slices in parser actions rather than
    ephemeral pointers, but action ordering and visible contents must match the
    upstream semantics.
  - No additional DCS/APC semantic module is required for Phase 3; the parser
    only needs the raw hook/put/unhook and apc-start/put/end action surface.

## Acceptance criteria

- Phase 3 implementation keeps the parse-table-driven state machine shape.
- `Parser.next` preserves upstream action ordering and the colon rule for CSI.
- Parser tests cover the minimum upstream behavior slice needed to trust the
  state machine before Phase 4 semantic decoders land.

## Validation commands

- doc review against `upstream/ghostty/src/terminal/Parser.zig`
- doc review against `docs/plan.md`
- `moon coverage analyze` remains part of the implementation gate for `P3.1`

## Coverage findings for touched files

- Docs-only task; no MoonBit coverage run required for this step.

## Commit scope

- `docs`: add Phase 3 parser contract checklist

## Review findings

- Main-agent review matched the contract against the upstream parser code and
  the direct parser tests in `Parser.zig`.
- The minimum green test slice for `P3.1` should include:
  - print / execute smoke
  - ESC dispatch with intermediates
  - CSI dispatch with params and intermediates
  - SGR colon handling, including mixed separators and non-`m` rejection
  - OSC title and minimal color-operation embedding
  - CSI and DCS parameter overflow
  - DCS hook / unhook and APC start / end lifecycle

## Audit/result notes

- Recorded the Phase 3 parser invariants and the minimum initial parser test
  surface.
- Confirmed there are no new module blockers beyond the already-landed
  `parse_table`, `parser_core_types`, and `osc` prerequisites.
