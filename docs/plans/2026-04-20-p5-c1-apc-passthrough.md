# P5.C1 APC Passthrough

## Goal

Land the first `P5.C` implementation slice by forwarding APC lifecycle parser
actions through the public stream interface as typed `StreamAction` values.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/Parser.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p5-c-roadmap.md`
- `docs/plans/2026-04-20-p5-c1-apc-passthrough.md`

## Dependency notes

- APC passthrough is independent of the future DCS hook facade
- parser-side APC actions already exist as:
  - `ApcStart`
  - `ApcPut(Byte)`
  - `ApcEnd`
- this slice only wires those existing parser actions to stream actions

## Acceptance criteria

- APC start / put / end each emit typed `StreamAction` values
- ordering matches upstream passthrough semantics
- blackbox stream tests verify the APC lifecycle and later printable text

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
- the APC passthrough helpers and lifecycle test are covered
- this slice introduces no new uncovered lines

## Commit scope

- `feat(stream)`

## Review findings

- the APC passthrough surface is intentionally minimal:
  - `StreamApcStart`
  - `StreamApcPut(Byte)`
  - `StreamApcEnd`
- this slice adds no mutable public fields and no parser-internal types

## Audit / result notes

- added `StreamApcStart`, `StreamApcPut(Byte)`, and `StreamApcEnd`
- wired `Stream::apc_start`, `Stream::apc_put`, and `Stream::apc_end` to emit
  typed stream actions instead of discarding parser output
- replaced the APC placeholder stream test with a lifecycle assertion over
  start / put / end ordering and later printable text
- validation completed:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
