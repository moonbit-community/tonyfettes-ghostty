# P5.B1 Current Translated OSC Core

## Goal

Land the first bounded `P5.B` slice by wiring the OSC commands already
translated in `src/terminal/osc.mbt` into typed `StreamAction` values.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/osc.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p5-b-roadmap.md`
- `docs/plans/2026-04-19-p5-b-current-osc-core.md`

## Dependency notes

- This slice is intentionally limited to the current translated `osc.Command`
  variants:
  - `ChangeWindowTitle`
  - `ChangeWindowIcon`
  - `ReportPwd`
  - `MouseShape`
  - `ColorOperation`
  - `Invalid`
- Future `P4.C` and `P4.D` parser expansion will require later `P5.B*`
  dispatch slices instead of widening this one after the fact.

## Acceptance criteria

- title OSCs emit typed title stream actions
- report-pwd OSCs emit typed report stream actions
- mouse-shape OSCs emit typed mouse-shape stream actions only for recognized
  names
- color-operation OSCs emit typed color-operation stream actions
- window-icon OSC remains an intentional no-op
- invalid / unsupported OSC forms remain silent
- stream blackbox tests cover the routed subset and ignored cases

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` returns the same two pre-existing structural
  residuals in `src/terminal/stream.mbt`:
  - the inner `consume_until_ground` path in `next_slice_capped`
  - the `Some(Print(codepoint))` path in `next_non_utf8`
- the new OSC dispatch branch coverage introduced by this slice is covered by
  blackbox tests; no new residual line remains in the touched OSC dispatch
  logic

## Commit scope

- `feat(stream)`

## Review findings

- public API review:
  - `StreamWindowTitle(String)` is intentional because external stream
    consumers need the translated title payload directly
  - `StreamReportPwd(String)` is intentional for the same reason
  - `StreamMouseShape(MouseShape)` reuses the existing typed mouse-shape enum
    instead of leaking raw strings to consumers
  - `StreamColorOperation(ColorCommand)` reuses the existing typed OSC color
    payload instead of reparsing downstream
- behavioral review:
  - `ChangeWindowIcon` stays silent, matching upstream stream behavior
  - `Invalid` stays silent as an internal no-op path
  - unknown mouse-shape strings stay silent, matching upstream rejection of
    unsupported shapes

## Audit / result notes

- Implemented:
  - title OSC routing
  - report-pwd OSC routing
  - mouse-shape OSC routing for recognized names
  - color-operation OSC routing
  - explicit no-op handling for icon / invalid forms
- Added blackbox stream tests for:
  - BEL and ST title dispatch with later printable text
  - report-pwd, mouse-shape, and color-operation dispatch
  - ignored icon, invalid prefix, and unknown mouse-shape forms
- Validation result:
  - `moon fmt`: pass
  - `moon check`: pass
  - `moon test`: pass (`190` tests)
  - `moon coverage analyze`: pass, no new touched-line residuals
  - `moon info`: pass
- Result:
  - `P5.B1` is complete
  - overall `P5.B` remains active for `P5.B2` and `P5.B3`
