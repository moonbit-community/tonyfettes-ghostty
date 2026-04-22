# P10.B SGR Helper Surface

## Goal

Close the SGR parser-object slice for the MoonBit `src/terminal/c` translation
by exposing the existing SGR parser as a public opaque owner type with a typed
parameter feed method.

## Upstream files

- `upstream/ghostty/src/terminal/sgr.zig`
- `upstream/ghostty/src/terminal/c/sgr.zig`

## MoonBit target files

- `src/terminal/sgr.mbt`
- `src/terminal/sgr_test.mbt`
- `src/terminal/sgr_wbtest.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-22-p10-b-sgr-helper-surface.md`

## Dependency notes

- The current `sgr.mbt` file already contains the translated attribute enum,
  unknown payload carrier, and parser core.
- The missing host-facing surface was the public parser object that can accept
  parameter arrays and iterate parsed attributes.
- The C wrapper helpers `unknown_full`, `unknown_partial`, `attribute_tag`, and
  `attribute_value` are intentionally absorbed into the existing public
  `SgrAttribute` and `SgrUnknown` surface.

## Acceptance criteria

- `SgrParser` is a public opaque owner type with `new`, `reset`, `set_params`,
  and `next`.
- Public parsing of unknown payloads is covered through the existing
  `SgrAttribute::Unknown` and `SgrUnknown` surface.
- Invalid separator shapes return `TerminalResultCode::InvalidValue`.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/sgr.mbt` stays covered by the existing whitebox suite in
  `src/terminal/sgr_wbtest.mbt`, with `src/terminal/sgr_test.mbt` adding
  blackbox coverage for the new public parser entrypoints.
- Pre-existing uncovered lines outside this slice remain in:
  - `src/terminal/stream.mbt:222`
  - documented invariant-only branches in
    `src/terminal/stream_terminal_bridge.mbt`
  - `tools/stream_terminal_perf/main.mbt`

## Commit scope

- `feat(c-parsers): add sgr parser surface`

## Review findings

- `SgrParser` is justified public surface because both upstream `sgr.zig` and
  `c/sgr.zig` expose a reusable parser object to host code.
- The typed `set_params` method is intentionally simpler than the C pointer API:
  callers pass MoonBit arrays, and `SgrAttribute` pattern matching replaces the
  C-side tag/value accessor helpers.
- No public mutable fields were added; the parser stays opaque.
