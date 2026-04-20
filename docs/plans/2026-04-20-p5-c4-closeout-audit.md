# P5.C4 Closeout Audit

## Goal

Close `P5.C` and Phase 5 by auditing the final DCS/APC passthrough surface,
confirming that placeholder handlers are gone, and recording the resulting
public stream API as intentional.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-20-p5-c-roadmap.md`
- `docs/plans/2026-04-20-p5-c4-closeout-audit.md`

## Audit checklist

- no APC or DCS passthrough placeholders remain in `src/terminal/stream.mbt`
- APC lifecycle is surfaced as:
  - `StreamApcStart`
  - `StreamApcPut(Byte)`
  - `StreamApcEnd`
- DCS lifecycle is surfaced as:
  - `StreamDcsHook(DcsHookPayload)`
  - `StreamDcsPut(Byte)`
  - `StreamDcsUnhook`
- `DcsHookPayload` stays opaque and accessor-based
- coverage / formatting / generated interface state remain green after the last
  implementation slice

## Review findings

- passthrough placeholder methods in `Stream` are gone; APC and DCS now both
  emit typed `StreamAction` values
- the final public passthrough additions are minimal and justified:
  - APC uses only byte lifecycle actions
  - DCS uses one opaque header payload plus byte lifecycle actions
- no public mutable fields were introduced during `P5.C`

## Coverage findings

- the repository still has the same single pre-existing uncovered line in
  `src/terminal/stream.mbt`:
  - `next_slice_capped` re-entering `consume_until_ground`
- `P5.C` introduced no new uncovered lines

## Result

- `P5.C` is complete
- Phase 5 is complete
- `P6.0` is now the next planned task
