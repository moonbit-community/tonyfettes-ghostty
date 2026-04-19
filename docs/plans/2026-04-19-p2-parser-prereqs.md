# Phase 2 Parser Prerequisites

## Goal

Record the exact contracts and local adaptations needed before porting the
parser-core prerequisite lanes:

- `UTF8Decoder.zig`
- `parse_table.zig`
- the minimal parser-facing slice of `osc.zig`

This gate exists to keep the follow-up implementation tasks green and to avoid
backtracking on package boundaries once `Parser` starts depending on them.

## Upstream files

- `upstream/ghostty/src/terminal/UTF8Decoder.zig`
- `upstream/ghostty/src/terminal/parse_table.zig`
- `upstream/ghostty/src/terminal/Parser.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers.zig`
- `upstream/ghostty/src/terminal/osc/parsers/change_window_title.zig`
- `upstream/ghostty/src/terminal/osc/parsers/change_window_icon.zig`
- `upstream/ghostty/src/terminal/osc/parsers/report_pwd.zig`
- `upstream/ghostty/src/terminal/osc/parsers/mouse_shape.zig`
- `upstream/ghostty/src/terminal/osc/parsers/color.zig`

## MoonBit target files

- `docs/plans/2026-04-19-p2-parser-prereqs.md`
- `src/terminal/utf8_decoder.mbt`
- `src/terminal/utf8_decoder_wbtest.mbt`
- `src/terminal/parser_core_types.mbt`
- `src/terminal/parse_table.mbt`
- `src/terminal/parse_table_wbtest.mbt`
- `src/terminal/osc.mbt`
- `src/terminal/osc_wbtest.mbt`

## Dependencies and invariants

- `UTF8Decoder`
  - Preserve the Hoehrmann DFA tables exactly.
  - Preserve the `{ codepoint?, consumed }` contract from `next`.
  - Preserve retry-on-error semantics:
    - invalid leading byte consumes the byte and emits U+FFFD
    - invalid continuation byte emits U+FFFD and does not consume the byte
  - Tests must cover ASCII, well-formed multibyte sequences, and partially
    invalid input.

- `parse_table`
  - Preserve the table-driven parser model and the exact transition coverage.
  - Preserve the `csi_param` adaptation that accepts `':'`.
  - Preserve the "anywhere" transitions and the default fallback transition of
    `{ same_state, none }`.
  - Hidden dependency: upstream `parse_table.zig` imports `Parser.State` and
    `Parser.TransitionAction`.
  - Local adaptation: introduce a shared `parser_core_types.mbt` module for
    parser states and transition actions so `parse_table` can land before
    `Parser` without cyclic package dependencies.

- minimal `osc`
  - This lane is only the parser-facing core needed to unblock `Parser`.
  - Preserve the OSC numeric prefix state machine, capture behavior, and
    terminator tracking (`BEL` vs `ST`).
  - Keep fixed-buffer capture and allocating capture behavior distinct.
  - The minimal command surface for this lane is:
    - `invalid`
    - `change_window_title`
    - `change_window_icon`
    - `report_pwd`
    - `mouse_shape`
    - minimal `color_operation` support sufficient for direct OSC tests and
      parser integration smoke tests
  - Defer the broader OSC semantic surface to Phase 4:
    - hyperlink
    - semantic prompt
    - kitty color / kitty clipboard / kitty text sizing
    - notifications
    - ConEmu extensions
    - iTerm2, rxvt, context signal, and clipboard details

- cross-lane rules
  - Keep all new code inside `src/terminal`.
  - P2.A, P2.B, and P2.C must each land in a green state with their own tests.
  - `Parser` itself remains deferred to Phase 3.

## Acceptance criteria

- The Phase 2 invariants and hidden dependencies are explicit enough to port
  `UTF8Decoder`, `parse_table`, and minimal `osc` without reopening the
  package design.
- The required local adaptation for shared parser-core enums is documented.
- Deferred OSC surface is listed clearly enough that Phase 2 and Phase 4 do not
  overlap accidentally.

## Validation commands

- doc review against `docs/architecture.md`
- doc review against `docs/plan.md`
- doc review against upstream files listed above

## Commit scope

- `docs`: add Phase 2 prerequisite checklist

## Review findings

- Main-agent review compared the checklist against upstream `UTF8Decoder`,
  `parse_table`, `Parser`, and the OSC parser entry points referenced by
  parser-core work.
- The only material local adaptation required at this gate is lifting parser
  state and transition-action enums into a shared parser-core module so
  `parse_table` can land before `Parser`.
- No additional Phase 2 blockers were found beyond the documented OSC scope
  split between the minimal core in Phase 2 and the semantic surface in
  Phase 4.

## Audit/result notes

- Added the Phase 2 prerequisite checklist and the parser-core boundary notes.
- Recorded the shared `parser_core_types` adaptation for `parse_table`.
- Recorded the minimum OSC command surface for the parser-core gate and the
  deferred semantic OSC surface for Phase 4.
