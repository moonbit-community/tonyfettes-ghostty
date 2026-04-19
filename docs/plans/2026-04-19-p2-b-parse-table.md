# P2.B Parse Table

## Goal

Port `upstream/ghostty/src/terminal/parse_table.zig` into MoonBit as a
table-driven parser transition table, using generated static data instead of
runtime table construction.

## Upstream files

- `upstream/ghostty/src/terminal/parse_table.zig`
- `upstream/ghostty/src/terminal/Parser.zig`

## MoonBit target files

- `src/terminal/parser_core_types.mbt`
- `src/terminal/parse_table.mbt`
- `src/terminal/parse_table_data.mbt`
- `src/terminal/parse_table_wbtest.mbt`
- `tools/gen_parse_table.py`
- `docs/plans/2026-04-19-p2-b-parse-table.md`

## Dependencies and invariants

- Depends on `P2.0` contract notes in
  `docs/plans/2026-04-19-p2-parser-prereqs.md`.
- Introduce shared parser-core enums in `parser_core_types.mbt` so the table
  can land before `Parser`.
- Keep the parser table table-driven.
- Use generated static table data; do not build the table dynamically at
  runtime.
- Preserve upstream defaults and special cases:
  - unspecified cells fall back to `{ same_state, none }`
  - anywhere transitions
  - `csi_param` accepts `':'`
  - `csi_entry` rejects `':'` into `csi_ignore`
  - OSC accepts `BEL` as immediate terminator while `ESC \\` is handled by the
    outer parser

## Acceptance criteria

- `ParserState`, `TransitionAction`, and `Transition` cover the exact upstream
  state/action surface used by `parse_table`.
- `parse_table` provides a parser-facing lookup over generated static data.
- Smoke tests cover representative anywhere, ground, CSI, DCS, OSC, and
  fallback transitions.
- `python3 tools/gen_parse_table.py`, `moon info`, `moon fmt`, `moon check`,
  and `moon test` pass.

## Validation commands

- `python3 tools/gen_parse_table.py`
- `moon info`
- `moon fmt`
- `moon check`
- `moon test`

## Commit scope

- `feat(parser-core): add parse table`

## Review findings

- Explorer review confirmed the exact upstream state list, action list,
  fallback rule, and the key special cases for CSI colon handling and OSC
  payload handling.
- Main-agent review kept the table data generated and packed rather than
  runtime-built, with a thin decode wrapper in MoonBit.
- Test review corrected one bad assumption: in `osc_string`, byte `0x9B`
  is handled by the OSC payload rule because that state overrides the generic
  anywhere transition for `0x20..0xFF`.

## Audit/result notes

- Added `src/terminal/parser_core_types.mbt` with `ParserState`,
  `TransitionAction`, and `Transition`.
- Added `tools/gen_parse_table.py` and generated
  `src/terminal/parse_table_data.mbt`.
- Added `src/terminal/parse_table.mbt` as the parser-facing lookup wrapper.
- Added `src/terminal/parse_table_wbtest.mbt` with smoke coverage for
  anywhere, ground, ESC, CSI, DCS, OSC, APC, and fallback transitions.
- Ran `python3 tools/gen_parse_table.py`, `moon info`, `moon fmt`,
  `moon check`, and `moon test` successfully at the end of the slice.
