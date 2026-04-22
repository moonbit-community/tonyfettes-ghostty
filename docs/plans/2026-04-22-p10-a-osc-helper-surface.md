# P10.A OSC Helper Surface

## Goal

Close the OSC parser-object slice for the MoonBit `src/terminal/c` translation by
turning the existing OSC parser into a public opaque owner type instead of
adding a second wrapper layer.

## Upstream files

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/c/osc.zig`

## MoonBit target files

- `src/terminal/osc.mbt`
- `src/terminal/osc_test.mbt`
- `src/terminal/osc_wbtest.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-22-p10-a-osc-helper-surface.md`

## Dependency notes

- The current `osc.mbt` file already contains the faithful parser
  implementation, command enum, and payload owner types.
- The missing C-surface parity was the parser-object boundary: construction,
  reset, byte feed, and end.
- `commandType` and `commandData` from `c/osc.zig` are not mirrored as extra
  MoonBit APIs because the existing public `Command` enum already exposes those
  semantics directly through pattern matching.

## Acceptance criteria

- `OscParser` is a public opaque owner type with `new`, `reset`, `next`, and
  `end`.
- Internal parser state types do not leak into `pkg.generated.mbti`.
- Blackbox tests cover construction, reset, byte feed, end, and command payload
  access through the existing `Command` surface.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/osc.mbt` stays covered by the existing whitebox suite in
  `src/terminal/osc_wbtest.mbt`, with `src/terminal/osc_test.mbt` adding
  blackbox coverage for the new public parser entrypoints.
- Pre-existing uncovered lines outside this slice remain in:
  - `src/terminal/stream.mbt:222`
  - documented invariant-only branches in
    `src/terminal/stream_terminal_bridge.mbt`
  - `tools/stream_terminal_perf/main.mbt`

## Commit scope

- `feat(c-parsers): add osc parser surface`

## Review findings

- The public parser surface is justified because both upstream `osc.zig` and
  `c/osc.zig` expose a reusable parser object to host code.
- `OscParserState` remains internal because it is implementation detail with no
  external consumer story.
- No extra `commandType` or `commandData` API was added because the public
  `Command` enum already carries the same information without C-style tagged
  accessors.
