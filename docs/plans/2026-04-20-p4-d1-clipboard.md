# P4.D1 Clipboard Operations

## Goal

Land the first bounded `P4.D` slice by adding typed `OSC 52` clipboard parsing
without dragging stream dispatch or other long-tail OSC protocols into the same
commit.

## Upstream files

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/clipboard_operation.zig`

## MoonBit target files

- `src/terminal/osc.mbt`
- `src/terminal/osc_wbtest.mbt`
- `src/terminal/parser_wbtest.mbt`
- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p4-d-roadmap.md`
- `docs/plans/2026-04-20-p4-d1-clipboard.md`

## Dependency notes

- This slice extends the current `OSC` parser after `P4.C` closeout.
- Stream dispatch for clipboard contents belongs to `P5.B4`, not this parser
  slice. `stream.mbt` only acknowledges the new command variant and stays
  intentionally silent for now.

## Acceptance criteria

- `OSC 52` parses into a typed clipboard payload with `kind` and `data`
- default clipboard kind for the `52;;...` form matches upstream (`'c'`)
- invalid `OSC 52` forms are rejected
- parser integration emits `OscDispatch(ClipboardContents(...))`
- stream behavior remains intentionally silent until `P5.B4`

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` still reports only the two pre-existing uncovered
  lines in `src/terminal/stream.mbt`:
  - the `next_slice_capped` branch that re-enters `consume_until_ground`
  - the `next_non_utf8` `Some(Print(codepoint))` dispatch arm
- no new uncovered lines remain in the touched OSC parser logic

## Commit scope

- `feat(parser-protocols)`

## Review findings

- `ClipboardContents` is an intentional public opaque payload because both
  `osc.Command` and future stream actions need to preserve the upstream `kind`
  plus `data` pairing.
- `ClipboardContents::kind()` stays `Byte` rather than a narrowed enum to keep
  parser fidelity with upstream's raw clipboard selector.
- `Stream::osc_dispatch` explicitly ignores clipboard commands for now. That is
  intentional and covered by a regression test until `P5.B4`.

## Audit / result notes

- added `Command::ClipboardContents(ClipboardContents)` to the OSC parser
  surface
- introduced a dedicated `Prefix52` branch so `OSC 52` clipboard parsing does
  not disturb the existing `OSC 5` color fast path
- added direct parser tests for:
  - get/set forms
  - default-kind form
  - clear form
  - invalid forms
- added parser integration coverage and a stream-level no-op regression test
- validation completed:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
