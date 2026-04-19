# P5.A Margins And Mode Save-Restore

## Goal

Land the next bounded `P5.A` slice for margin-setting and mode save/restore
dispatch in the stream layer.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- Builds on the current `P5.A` stream semantic surface.
- Introduces a dedicated `Margin` record matching upstream `stream.zig`.
- Reuses existing `Mode` values for save/restore dispatch, rather than adding a
  separate wrapper around a single field.

## Included semantic surface

- `CSI r`
  - top/bottom margin reset
  - one-value top margin
  - two-value top/bottom margins
- `CSI ? r`
  - restore mode for known DEC modes
- `CSI s`
  - zero-param ambiguous form is already implemented
  - one/two-value left/right margins
- `CSI ? s`
  - save mode for known DEC modes

## Acceptance criteria

- supported margin and mode save/restore forms emit typed stream actions
- invalid arity or unsupported intermediates are ignored
- unknown mode ids are ignored rather than emitted as bogus actions
- tests pass in the same change

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream.mbt`
  - new `CSI r`, `CSI s`, `CSI ? r`, and `CSI ? s` branches are covered by the
    added stream tests
  - pre-existing structural residuals remain in `next_slice_capped` and
    `next_non_utf8`; this slice does not expand them
- `src/terminal/stream_test.mbt`
  - added cases cover supported arities, unknown DEC mode ids, and silent
    invalid forms for this slice

## Commit scope

- `feat(stream)`

## Review findings

- `Margin` is a small typed record instead of reusing positional tuples in the
  action surface, which keeps the stream action payload explicit and close to
  upstream intent
- mode save/restore reuses the existing `Mode` enum rather than introducing a
  wrapper with no new semantics
- `pkg.generated.mbti` changes are limited to `Margin` plus
  `StreamSaveMode`, `StreamRestoreMode`, `StreamTopAndBottomMargin`, and
  `StreamLeftAndRightMargin`

## Audit / result notes

- `moon fmt` passed
- `moon check` passed with the existing warning baseline
- `moon test` passed (`179` tests)
- `moon coverage analyze` reported the same `2` pre-existing uncovered lines in
  `src/terminal/stream.mbt`
- `moon info` completed and the interface diff matched the intended stream
  action additions
