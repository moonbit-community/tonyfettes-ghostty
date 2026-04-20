# P5.C2 DCS Facade And Passthrough

## Goal

Land the DCS half of `P5.C` by introducing a stream-facing DCS hook payload and
wiring DCS hook / put / unhook lifecycle actions through the public stream API
without exposing the parser-private `Dcs` struct directly.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/Parser.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p5-c-roadmap.md`
- `docs/plans/2026-04-20-p5-c2-dcs-facade-and-passthrough.md`

## Dependency notes

- parser-side DCS lifecycle actions already exist as:
  - `DcsHook(Dcs)`
  - `DcsPut(Byte)`
  - `DcsUnhook`
- the parser `Dcs` struct is package-private, so the stream API needs its own
  accessor-based payload type
- this slice intentionally lands the payload and the stream actions together so
  the new public type is justified immediately

## Acceptance criteria

- DCS hook / put / unhook each emit typed `StreamAction` values
- the stream-facing hook payload exposes:
  - intermediates
  - params
  - final byte
- blackbox stream tests verify hook payload accessors, lifecycle ordering, and
  later printable text

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` still reports the same single pre-existing uncovered
  line in `src/terminal/stream.mbt`:
  - `next_slice_capped` re-entering `consume_until_ground`
- the new DCS hook / put / unhook branches and blackbox lifecycle test are
  covered
- this slice introduces no new uncovered lines

## Commit scope

- `feat(stream)`

## Review findings

- the public DCS payload is opaque and accessor-based, which avoids leaking the
  parser-private `Dcs` representation
- the accessors return copied arrays so callers can inspect header data without
  mutating stored stream payload state
- this slice adds no public mutable fields

## Audit / result notes

- added the opaque `DcsHookPayload` type with accessor methods for:
  - intermediates
  - params
  - final byte
- wired `Stream::dcs_hook`, `Stream::dcs_put`, and `Stream::dcs_unhook` to
  emit typed stream actions instead of discarding parser output
- replaced the DCS placeholder stream test with a lifecycle assertion that
  verifies hook payload accessors, `put`, `unhook`, and later printable text
- updated the `P5.C` roadmap to merge facade introduction and passthrough
  wiring into one green slice
- validation completed:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
