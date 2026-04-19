# P3.6 Parser API Visibility Tightening

## Goal

Shrink the package public API so parser-core scaffolding stays internal until
the Phase 7 host-facing API is intentionally designed.

This task covers two related adjustments:

- hide parser and parse-table implementation machinery from `pkg.generated.mbti`
- make mode-state records opaque so callers cannot mutate their backing fields
  directly

## Upstream files

- `upstream/ghostty/src/terminal/Parser.zig`
- `upstream/ghostty/src/terminal/parse_table.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/modes.zig`

## MoonBit target files

- `src/terminal/parser_core_types.mbt`
- `src/terminal/parse_table.mbt`
- `src/terminal/parser.mbt`
- `src/terminal/osc.mbt`
- `src/terminal/modes.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p3-6-parser-api-visibility.md`

## Dependency notes

- Phase 3 parser correctness and Phase 3.5 outbound encoder work are already
  done.
- This task is about package visibility only. It must not change parser action
  ordering, parse-table behavior, or OSC parsing semantics.
- White-box tests are allowed to keep touching internals; that is not
  justification for public visibility.
- The host-facing public parser API is deferred to Phase 7.

## Acceptance criteria

- Parser state-machine internals are no longer exported through
  `pkg.generated.mbti`.
- Transition-table helpers are internal to the package.
- `OscParser` is no longer a standalone public helper parser.
- Mode-state backing fields are no longer directly accessible outside the
  package.
- Existing tests stay green without semantic behavior changes.

## Validation commands

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` was run successfully.
- `src/terminal/parser_core_types.mbt`: visibility-only change, no uncovered
  lines reported.
- `src/terminal/parse_table.mbt`: visibility-only change, no uncovered lines
  reported.
- `src/terminal/parser.mbt`: visibility-only change, no uncovered lines
  reported.
- `src/terminal/modes.mbt`: visibility-only change, no uncovered lines
  reported.
- `src/terminal/osc.mbt`: 8 previously existing uncovered defensive/error arms
  remain. This task only changed visibility and did not change parser
  semantics; coverage for those paths is explicitly carried forward unchanged in
  this audit.

## Commit scope

- `refactor(api): hide parser core internals`

## Review findings

- Main-agent review: parser-core state machinery, transition helpers, and
  embedded OSC parser lifecycle were removed from the package interface without
  behavioral changes.
- Reviewer subagent `Sagan`: the original parser-core public API leak was
  fixed after this task. One follow-up finding identified `report_max_size` as
  leftover unjustified public surface; that constant was then made internal.

## Audit / result notes

- Parser-core items are now internal:
  - `ParserState`
  - `TransitionAction`
  - `Transition`
  - `transition_for`
  - parser state/action integer decode helpers
  - `Parser`
  - `Action`, `ActionList`, `Csi`, `Esc`, `Dcs`, `SepList`
  - `OscParser`
- Mode-layer backing records are now opaque in the public interface:
  - `ModeTag`
  - `ModePacked`
  - `ModeState`
- `report_max_size` is now internal because it only supports report encoding
  and tests.
- Validation completed successfully:
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
  - `moon fmt`

## Public API visibility findings

- `.mbti` was reviewed after `moon info`.
- Intentional public API change:
  - remove parser-core and parse-table scaffolding from the package interface
  - keep mode-layer types opaque instead of exposing mutable fields
- The resulting public surface keeps semantic/value-layer APIs public while
  deferring host-facing parser API design to Phase 7.
