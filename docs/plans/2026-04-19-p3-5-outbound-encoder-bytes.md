# P3.5 Outbound Encoder Bytes

## Goal

Normalize the parser-adjacent outbound VT/PTY encoders from `String` to
`Bytes`, matching the upstream writer-oriented API shape more closely before
more Phase 4 protocol work lands on top of these helpers.

This task is intentionally narrow:

- change protocol encoder outputs to `Bytes`
- keep parser and semantic text payloads unchanged
- keep the write set inside the existing flat `src/terminal` package

## Upstream files

- `upstream/ghostty/src/terminal/size_report.zig`
- `upstream/ghostty/src/terminal/device_attributes.zig`
- `upstream/ghostty/src/terminal/modes.zig`

## MoonBit target files

- `src/terminal/bytes_encode.mbt`
- `src/terminal/size_report.mbt`
- `src/terminal/device_attributes.mbt`
- `src/terminal/modes.mbt`
- `src/terminal/size_report_wbtest.mbt`
- `src/terminal/device_attributes_wbtest.mbt`
- `src/terminal/modes_wbtest.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p3-5-outbound-encoder-bytes.md`

## Dependency notes

- This task depends on Phase 3 parser state-machine parity being done.
- It should land before broader Phase 4 semantic decoder work expands the OSC,
  DCS, and APC surfaces further.
- The refactor is restricted to outbound protocol encoders:
  - `size_report.encode`
  - `PrimaryDeviceAttributes::encode`
  - `SecondaryDeviceAttributes::encode`
  - `TertiaryDeviceAttributes::encode`
  - `DeviceAttributes::encode`
  - `Report::encode`
- Semantic text payloads remain `String`, including existing OSC command data
  like window titles and reported paths.

## Acceptance criteria

- The listed outbound encoders return `Bytes`.
- The implementation uses byte-oriented construction, not dynamic string
  interpolation.
- Tests are updated to assert byte sequences directly.
- No unrelated parser, OSC payload, or semantic API surface changes are mixed
  into this task.

## Validation commands

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage findings for touched files

- `src/terminal/size_report.mbt`: fully covered after the byte-output refactor.
- `src/terminal/device_attributes.mbt`: fully covered after the byte-output
  refactor and helper checks.
- `src/terminal/modes.mbt`: fully covered for the touched report-encoding path
  after extending the `mode_bit_index` coverage checks.
- Residual repo-wide uncovered lines remain in untouched files:
  - `src/terminal/color.mbt`: 1 uncovered fallback arm
  - `src/terminal/osc.mbt`: 8 uncovered defensive/error arms

## Commit scope

- `refactor(parser-foundation): return bytes from outbound encoders`

## Review findings

- Main-agent review: no correctness regressions found in the new byte-oriented
  builders; output shapes still match the upstream writer-based encoders.
- Reviewer subagent `Peirce`: no correctness or fidelity issues found in the
  refactor boundary; remaining risk is the intentional public API change from
  `String` to `Bytes` for these encoder functions.

## Audit / result notes

- Added `src/terminal/bytes_encode.mbt` to centralize ASCII decimal and fixed
  width hex emission for protocol encoders.
- Updated `src/terminal/moon.pkg` to import `moonbitlang/core/buffer`.
- Changed outbound encoder return types from `String` to `Bytes` in:
  - `src/terminal/size_report.mbt`
  - `src/terminal/device_attributes.mbt`
  - `src/terminal/modes.mbt`
- Updated white-box tests to assert `Bytes` literals directly.
- `src/terminal/pkg.generated.mbti` now records the intentional public API
  shift to `Bytes`.
- Validation completed successfully in this task:
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
  - `moon fmt`
