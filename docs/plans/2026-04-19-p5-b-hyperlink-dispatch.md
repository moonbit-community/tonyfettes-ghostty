# P5.B2 Hyperlink Dispatch

## Goal

Land the next bounded `P5.B` slice by wiring translated `OSC 8` hyperlink
commands into typed `StreamAction` values.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/hyperlink.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p5-b-roadmap.md`
- `docs/plans/2026-04-19-p5-b-hyperlink-dispatch.md`

## Dependency notes

- This slice depends on `P4.C1` and its typed `Command::HyperlinkStart` /
  `Command::HyperlinkEnd` outputs.
- Terminal-side hyperlink state remains a later Phase 6 concern; this slice is
  only about typed stream actions.

## Acceptance criteria

- hyperlink start emits a typed stream action with URI and optional `id`
- hyperlink end emits a typed stream action
- stream tests cover both forms and later printable text
- no unrelated OSC behavior regresses

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` still reports the same two pre-existing uncovered lines
  in `src/terminal/stream.mbt`:
  - the `next_slice_capped` branch that re-enters `consume_until_ground`
    mid-slice
  - the `next_non_utf8` `Some(Print(codepoint))` dispatch arm
- this slice introduced no new uncovered lines

## Commit scope

- `feat(stream)`

## Review findings

- `StreamStartHyperlink(HyperlinkStart)` is an intentional public stream action:
  downstream terminal state will need the parsed URI and optional `id`
- `HyperlinkStart` remains opaque; blackbox tests must observe it through
  `uri()` and `id()` accessors instead of constructing it directly
- terminal-side hyperlink state and semantic prompt handling remain future work
  in later slices

## Audit / result notes

- wired `OSC 8` hyperlink start/end commands through `Stream::osc_dispatch`
  into typed `StreamAction` values
- replaced the prior silent-behavior test with a blackbox assertion over the
  emitted actions and later printable text
- validation completed:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
