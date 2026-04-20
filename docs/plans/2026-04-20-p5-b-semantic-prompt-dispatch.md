# P5.B3 Semantic Prompt Dispatch

## Goal

Land the `P5.B3` stream slice by wiring translated `OSC 133` semantic-prompt
commands into a typed `StreamAction`, matching upstream `stream.zig` handler
forwarding.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/semantic_prompt.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p5-b-roadmap.md`
- `docs/plans/2026-04-20-p5-b-semantic-prompt-dispatch.md`

## Dependency notes

- This slice depends on `P4.C2` and the typed `Command::SemanticPrompt`
  payload.
- Terminal-side semantic prompt behavior remains a later phase concern; this
  slice only exposes the stream-facing typed action.

## Acceptance criteria

- `OSC 133` emits a typed `StreamAction` carrying the parsed semantic-prompt
  payload
- stream tests verify the action payload through the public `SemanticPrompt`
  accessors
- later printable text still flows after semantic-prompt dispatch
- no unrelated OSC behavior regresses

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` still reports the same two pre-existing uncovered
  lines in `src/terminal/stream.mbt`:
  - the `next_slice_capped` branch that re-enters `consume_until_ground`
  - the `next_non_utf8` `Some(Print(codepoint))` dispatch arm
- this slice adds no new uncovered lines

## Commit scope

- `feat(stream)`

## Review findings

- `StreamSemanticPrompt(SemanticPrompt)` is an intentional public stream action:
  downstream terminal handling needs the typed semantic-prompt payload
  unchanged.
- `SemanticPrompt` remains opaque; consumers observe it through accessors
  instead of mutating parser state.
- This slice replaces the earlier temporary no-op with the upstream-equivalent
  typed forward and does not expand terminal semantics on its own.

## Audit / result notes

- wired `Command::SemanticPrompt` through `Stream::osc_dispatch`
- added a blackbox stream test that:
  - observes the typed action
  - checks `action`, `aid`, and `cl` through public accessors
  - verifies printable text still resumes afterward
- validation completed:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
