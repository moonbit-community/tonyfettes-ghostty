# P5.A Device Report And ESC Controls

## Goal

Land the next bounded `P5.A` slice for ESC control/reset dispatch and CSI
device/report/protected-mode dispatch in the stream layer.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- Builds on the existing `P5.A` CSI and ESC dispatch surface.
- Reuses already-landed typed values from:
  - `ansi.mbt`
  - `device_attributes.mbt`
  - `device_status.mbt`
  - `modes.mbt`
- Intentionally excludes:
  - SGR / `CSI m`
  - kitty keyboard protocol / `CSI u`
  - OSC / DCS / APC semantic wiring

## Included semantic surface

- ESC:
  - `D` index
  - `E` next line
  - `H` tab set
  - `M` reverse index
  - `V` ISO protected mode
  - `W` protected mode off
  - `Z` primary device attributes request
  - `c` full reset
  - `#8` DECALN
- CSI:
  - `c` device attributes request selection
  - `n` device status requests and `CSI > n` modify-key reset form
  - `p` request mode / request mode unknown
  - `q` protected mode and `XTVERSION`
  - `}` active status display

## Acceptance criteria

- supported ESC controls emit typed stream actions
- supported CSI report/protected-mode forms emit typed stream actions
- unknown request-mode ids are preserved as raw tagged values
- invalid or unsupported forms stay silent
- tests pass in the same change

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream.mbt`
  - new ESC control/reset branches are covered by the added subset test
  - new CSI device/report/protected-mode branches are covered by the added
    subset and invalid-form tests
  - only the same `2` pre-existing structural residuals remain in
    `next_slice_capped` and `next_non_utf8`
- `src/terminal/stream_test.mbt`
  - new tests cover supported forms, unknown mode request preservation, and
    silent invalid forms for this slice

## Commit scope

- `feat(stream)`

## Review findings

- the new stream surface reuses existing public value types
  (`ModeTag`, `ModifyKeyFormat`, `DeviceAttributeRequest`,
  `DeviceStatusRequest`, `StatusDisplay`) instead of adding redundant wrapper
  records
- protected-mode CSI dispatch is kept narrow to the forms that upstream
  actually emits here, avoiding an uncovered helper arm for ISO mode
- `pkg.generated.mbti` changes are limited to the intended stream action
  additions for ESC controls, device reports, protected modes, and request mode
  queries

## Audit / result notes

- `moon fmt` passed
- `moon check` passed with the existing warning baseline
- `moon test` passed (`182` tests)
- `moon coverage analyze` reported the same `2` pre-existing uncovered lines in
  `src/terminal/stream.mbt`
- `moon info` completed and the interface diff matched the intended stream
  action additions
