# Foundation Coverage Sweep

## Goal

Improve coverage for the smaller foundational parser-helper modules flagged by
`moon coverage analyze`, using targeted white-box tests instead of
implementation changes wherever possible.

## Upstream files

- `upstream/ghostty/src/terminal/ansi.zig`
- `upstream/ghostty/src/terminal/charsets.zig`
- `upstream/ghostty/src/terminal/color.zig`
- `upstream/ghostty/src/terminal/device_attributes.zig`
- `upstream/ghostty/src/terminal/device_status.zig`
- `upstream/ghostty/src/terminal/modes.zig`
- `upstream/ghostty/src/terminal/parse_table.zig`
- `upstream/ghostty/src/terminal/point.zig`

## MoonBit target files

- `src/terminal/ansi_wbtest.mbt`
- `src/terminal/charsets_wbtest.mbt`
- `src/terminal/color_wbtest.mbt`
- `src/terminal/device_attributes_wbtest.mbt`
- `src/terminal/device_status_wbtest.mbt`
- `src/terminal/modes_wbtest.mbt`
- `src/terminal/parser_core_types_wbtest.mbt`
- `src/terminal/point_wbtest.mbt`
- `src/terminal/x11_color_wbtest.mbt`
- `src/terminal/parse_table_wbtest.mbt`
- `docs/plans/2026-04-19-foundation-coverage-sweep.md`

## Dependencies and invariants

- Follow `AGENTS.md`, `docs/architecture.md`, and `docs/plan.md`.
- Keep the work confined to foundational helper modules already translated in
  Phases 1 and 2.
- Preserve current module boundaries and semantics; prefer white-box tests over
  implementation edits.
- Exercise meaningful enum mapping arms, helper conversions, error/rejection
  paths, and defensive abort-only branches where white-box tests can reach them
  directly.

## Acceptance criteria

- Owned helper-module wbtests cover previously missed mapping and conversion
  branches in `ansi`, `charsets`, `color`, `device_attributes`,
  `device_status`, `modes`, `parse_table`, `parser_core_types`, `point`, and
  `x11_color`.
- The sweep remains atomic and green under the repository quality gate:
  `moon check`, `moon test`, `moon coverage analyze`, `moon fmt`, and
  `moon info`.
- Coverage findings for every touched target file are recorded here, including
  any intentionally untested abort-only branches that remain.

## Validation commands

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` ran successfully after the final wbtest sweep.
- Touched target coverage status:
  - `src/terminal/ansi.mbt`: no uncovered lines reported.
  - `src/terminal/charsets.mbt`: no uncovered lines reported. The
    `Charset::Utf8` abort-only `table()` branch is exercised by a panic test.
  - `src/terminal/color.mbt`: 1 uncovered line remains at
    `parse_hex_component`'s `_ => 1` divisor fallback. This branch is
    structurally unreachable because the preceding width guard restricts the
    match to `1..=4`.
  - `src/terminal/device_attributes.mbt`: no uncovered lines reported.
  - `src/terminal/device_status.mbt`: no uncovered lines reported.
  - `src/terminal/modes.mbt`: coverage still reports 2 mapping arms in
    `mode_bit_index` (`MouseEventAny` and `SynchronizedOutput`) as uncovered.
    These are low-risk constant-return arms adjacent to covered cases; the wbts
    now call `mode_bit_index` directly across the surrounding mode range.
  - `src/terminal/parser_core_types.mbt`: no uncovered lines reported.
  - `src/terminal/point.mbt`: no uncovered lines reported.
  - `src/terminal/x11_color.mbt`: no uncovered lines reported.
  - `src/terminal/parse_table.mbt`: no uncovered lines reported. Invalid
    packed-state/action decode aborts are exercised by panic tests.
- `src/terminal/osc.mbt` still has uncovered lines in the repo-wide report, but
  it is outside this task's owned write set and was not modified here.

## Commit scope

- `test(parser-foundation): expand helper coverage`

## Review findings

- Kept the slice inside the owned white-box test files plus this subplan.
- Added white-box coverage for enum/value roundtrips, helper conversions,
  rejection paths, and panic-path defensive branches instead of changing
  helper-module implementations.
- Added a dedicated `parser_core_types_wbtest.mbt` because that helper module
  previously had no white-box coverage at all.

## Audit/result notes

- Added targeted coverage tests in:
  - `src/terminal/ansi_wbtest.mbt`
  - `src/terminal/charsets_wbtest.mbt`
  - `src/terminal/color_wbtest.mbt`
  - `src/terminal/device_attributes_wbtest.mbt`
  - `src/terminal/device_status_wbtest.mbt`
  - `src/terminal/modes_wbtest.mbt`
  - `src/terminal/parser_core_types_wbtest.mbt`
  - `src/terminal/point_wbtest.mbt`
  - `src/terminal/x11_color_wbtest.mbt`
  - `src/terminal/parse_table_wbtest.mbt`
- Validation completed successfully:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
- Validation passes with existing repo warnings about unused constructors in
  implementation files; no new errors were introduced.
