# P5.A XTWINOPS And Title Stack

## Goal

Land the next bounded `P5.A` slice for `CSI t` handling in the stream layer:

- XTWINOPS size-report requests
- title push
- title pop

This slice stops at semantic dispatch. It does not implement terminal-side
responses yet.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/csi.zig`

## MoonBit target files

- `src/terminal/csi.mbt`
- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- Builds on the current `P5.1` stream driver and earlier `P5.A` ESC/CSI slices.
- Introduces a request-side `SizeReportStyle` matching upstream `csi.zig`
  instead of overloading `size_report.Style`, which is encoder-facing and lacks
  `csi_21_t`.
- Defers terminal-side execution of these requests to the later terminal bridge
  phase.

## Included semantic surface

- `CSI 14 t`
- `CSI 16 t`
- `CSI 18 t`
- `CSI 21 t`
- `CSI 22 ; 0|2 [; index] t`
- `CSI 23 ; 0|2 [; index] t`

## Acceptance criteria

- supported `CSI t` forms emit typed stream actions
- unsupported `CSI t` forms are ignored
- request-side report style matches upstream shape, including `csi_21_t`
- tests pass in the same change

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream.mbt` covers the newly added XTWINOPS and title-stack
  dispatch helpers.
- The only remaining uncovered lines in `src/terminal/stream.mbt` are the same
  two structural residuals already recorded in the previous `P5.A` slice:
  - `next_slice_capped` main-loop re-entry into `consume_until_ground`
  - `next_non_utf8` branch for `Some(Print(codepoint))`

## Commit scope

- `feat(stream)`

## Review findings

- Added a dedicated request-side `SizeReportStyle` that mirrors upstream
  `csi.zig` and includes `Csi21t`.
- Kept encoder-facing `size_report.Style` unchanged; request dispatch and
  outbound encoding remain separate, matching the upstream split between
  `csi.zig` and `size_report.zig`.
- `.mbti` changes are limited to the new `SizeReportStyle` type and the new
  `StreamAction` variants for this slice.

## Audit / result notes

- Validation run:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
- Result: implementation complete for this slice and ready to land as a green,
  atomic commit.
