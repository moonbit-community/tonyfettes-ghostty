# Phase 1.C Point and Size Report

## Goal

Translate the small shared geometry and size-report support files needed by the
parser stack:

- `point.zig`
- `size_report.zig`
- the minimum `size.zig` surface required by those files

This task must remain green on its own.

## Upstream files

- `upstream/ghostty/src/terminal/point.zig`
- `upstream/ghostty/src/terminal/size_report.zig`
- `upstream/ghostty/src/terminal/size.zig`

## MoonBit target files

- `src/terminal/size.mbt`
- `src/terminal/point.mbt`
- `src/terminal/point_wbtest.mbt`
- `src/terminal/size_report.mbt`
- `src/terminal/size_report_wbtest.mbt`
- `docs/plans/2026-04-18-p1-c-point-size-report.md`

## Dependencies and invariants

- Keep this lane self-contained inside `src/terminal`.
- Do not introduce a shared helper abstraction for `lib.zig`; use direct
  MoonBit enums and structs for this slice.
- Only carry over the `size.zig` surface that `point` and `size_report` need.
- Preserve the existing report encodings and the point/coordinate data
  contracts.

## Acceptance criteria

- `CellCountInt` exists with the expected width for `point` and `size_report`.
- `Point`, `Tag`, and `Coordinate` are available with direct tests.
- Terminal size report encoding matches upstream behavior for the covered cases.
- `moon check`, `moon test`, `moon fmt`, and `moon info` pass.

## Validation commands

- `moon check`
- `moon test`
- `moon fmt`
- `moon info`

## Commit scope

- `feat(parser-foundation)`: add point and size-report support types

## Review findings

- Main-agent review: this lane stayed within the planned `size`, `point`, and
  `size_report` write set.
- The upstream public contracts preserved here are:
  - `CellCountInt`
  - `Tag`, `Coordinate`, `Point`, and `Point::coord`
  - `Style`, `Size`, and `encode`
- Local adaptation:
  - replaced Zig `lib.Enum`/`lib.Struct` helpers with direct MoonBit enums and
    structs
  - reduced `size.zig` to the minimum `CellCountInt` surface needed by this
    lane
  - returned encoded size-report strings directly instead of writing through a
    Zig-style writer abstraction
- Residual warning note:
  - `moon check`/`moon info` still report non-fatal unused-constructor and
    struct-never-constructed warnings for these newly exported support types

## Audit/result notes

- Added:
  - `src/terminal/size.mbt`
  - `src/terminal/point.mbt`
  - `src/terminal/point_wbtest.mbt`
  - `src/terminal/size_report.mbt`
  - `src/terminal/size_report_wbtest.mbt`
- Validation completed successfully:
  - `moon check`
  - `moon test`
  - `moon fmt`
  - `moon info`
- Validation results:
  - `moon test`: 8 passed, 0 failed
  - `moon check` and `moon info` both passed with 14 non-fatal warnings from
    currently unused exported constructors/records in this early foundation
    slice
