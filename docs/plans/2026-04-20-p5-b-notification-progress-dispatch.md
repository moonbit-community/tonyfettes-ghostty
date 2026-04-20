# P5.B5 Notification And Progress Dispatch

## Goal

Land the `P5.B5` stream slice by wiring desktop notifications and ConEmu
progress reports into typed `StreamAction` values, matching upstream
`stream.zig` forwarding while leaving the rest of the OSC 9 long tail for the
explicit no-op audit.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/osc9.zig`
- `upstream/ghostty/src/terminal/osc/parsers/rxvt_extension.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p5-b-roadmap.md`
- `docs/plans/2026-04-20-p5-b-notification-progress-dispatch.md`

## Dependency notes

- This slice depends on the already translated parser outputs for:
  - `Command::ShowDesktopNotification`
  - `Command::ConEmuProgressReport`
- Both `OSC 9` desktop notifications and `OSC 777` rxvt notifications parse to
  the same `ShowDesktopNotification` command surface and should therefore reuse
  one stream action.
- Remaining `OSC 9` branches such as sleep, message box, tab title, wait
  input, GuiMacro, run process, output environment variable, xterm emulation,
  and comment stay intentionally silent until `P5.B6`.

## Acceptance criteria

- `ShowDesktopNotification` emits a typed desktop-notification stream action
- `ConEmuProgressReport` emits a typed progress-report stream action
- `OSC 9` and `OSC 777` notification spellings both reuse the same desktop
  notification stream action
- tests continue to prove that the rest of the long-tail `OSC 9` commands stay
  silent for now
- later printable text still resumes after each dispatched command

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` still reports the same single pre-existing uncovered
  line in `src/terminal/stream.mbt`:
  - `next_slice_capped` re-entering `consume_until_ground`
- the new desktop-notification and progress-report dispatch branches are
  covered by blackbox tests
- this slice introduces no new uncovered lines

## Commit scope

- `feat(stream)`

## Review findings

- `StreamShowDesktopNotification(DesktopNotification)` is an intentional
  public stream action because downstream consumers need the already parsed
  title/body pair rather than reparsing raw OSC payloads.
- `StreamProgressReport(ConEmuProgressReport)` is also intentional because the
  progress state plus optional numeric progress form the semantic downstream
  contract upstream exposes.
- No parser-internal structs or mutable fields are newly exposed; both payload
  types remain accessor-based.

## Audit / result notes

- wired `Command::ShowDesktopNotification` through `Stream::osc_dispatch`
- wired `Command::ConEmuProgressReport` through `Stream::osc_dispatch`
- added focused blackbox stream tests for:
  - `OSC 9` desktop notification dispatch
  - `OSC 777` desktop notification dispatch
  - `OSC 9` ConEmu progress dispatch
  - remaining `OSC 9` long-tail no-op behavior that still belongs to `P5.B6`
- validation completed:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
