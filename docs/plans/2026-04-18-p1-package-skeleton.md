# Phase 1.0 Package Skeleton

## Goal

Create the initial MoonBit package skeleton for the parser translation under a
single package root:

- `src/terminal`

This task is limited to layout and package boundaries. It must remain green.

## Upstream files

- Phase 0 control-plane mapping in
  `docs/plans/2026-04-18-p0-control-plane.md`

## MoonBit target files

- `src/terminal/moon.pkg`
- any minimal package readme/placeholder files strictly required to keep the
  packages valid
- this subplan file

## Dependencies and invariants

- Do not add failing placeholder tests.
- Do not add speculative implementation files for later phases.
- The resulting package skeleton must keep `moon check`, `moon test`,
  `moon fmt`, and `moon info` green.

## Acceptance criteria

- The `src/terminal` package directory exists and matches the Phase 0 mapping.
- The package boundary file exists.
- The repository remains green under the required MoonBit checks.

## Validation commands

- `moon check`
- `moon test`
- `moon fmt`
- `moon info`

## Commit scope

- `feat(parser)`: add parser package skeleton

## Review findings

- The earlier split-package sketch was rejected after dependency analysis.
- The updated target is one package under `src/terminal`, with worker ownership
  handled by file boundaries rather than package boundaries.
- No implementation or placeholder tests should land in this task.
- Main-agent review: the landed package boundary is exactly one
  `src/terminal/moon.pkg` file, with no speculative source files yet.

## Audit/result notes

- Created `src/terminal/moon.pkg`.
- Validation completed successfully:
  - `moon check`
  - `moon test`
  - `moon fmt`
  - `moon info`
- `moon test` reported `0` tests, which is expected for this layout-only step.
- `moon info` generated interface summaries for:
  - the root package: `pkg.generated.mbti`
  - the new terminal package: `src/terminal/pkg.generated.mbti`
