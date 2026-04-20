# P5.B4 Clipboard And Kitty Color Dispatch

## Goal

Land the `P5.B4` stream slice by wiring translated clipboard and kitty color
OSC commands into typed `StreamAction` values, matching upstream `stream.zig`
forwarding.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/clipboard_operation.zig`
- `upstream/ghostty/src/terminal/osc/parsers/kitty_color.zig`
- `upstream/ghostty/src/terminal/osc/parsers/iterm2.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p5-b-roadmap.md`
- `docs/plans/2026-04-20-p5-b-clipboard-kitty-color-dispatch.md`

## Dependency notes

- This slice depends on the `P4.D` parser outputs for:
  - `Command::ClipboardContents`
  - `Command::KittyColorProtocol`
- Compatibility bridges that already parse to `ClipboardContents`, especially
  `OSC 1337 Copy`, should reuse the same new clipboard stream action once this
  slice lands.
- Notification and progress-report routing remain in `P5.B5`.

## Acceptance criteria

- clipboard OSC commands emit a typed clipboard stream action
- kitty color OSC commands emit a typed kitty-color stream action
- `OSC 1337 Copy` reuses the clipboard stream action because the parser already
  bridges it to `ClipboardContents`
- `OSC 777` remains silent in this slice because notification routing belongs
  to `P5.B5`
- stream blackbox tests verify payloads through public accessors and confirm
  later printable text still resumes

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
- the new clipboard and kitty-color dispatch branches are covered by blackbox
  tests
- this slice introduces no new uncovered lines

## Commit scope

- `feat(stream)`

## Review findings

- `StreamClipboardContents(ClipboardContents)` is an intentional public stream
  action: downstream consumers need the clipboard selection kind plus payload,
  while `ClipboardContents` itself remains opaque and accessor-based.
- `StreamKittyColorReport(KittyColorOsc)` is also intentional: downstream
  consumers need the parsed kitty color request list and terminator without
  reparsing raw strings.
- The bridge behavior for `OSC 1337 Copy` is preserved naturally by reusing the
  existing `Command::ClipboardContents` semantic surface instead of inventing a
  second stream action for the same meaning.

## Audit / result notes

- wired `Command::ClipboardContents` through `Stream::osc_dispatch`
- wired `Command::KittyColorProtocol` through `Stream::osc_dispatch`
- replaced the temporary silent stream tests with blackbox assertions over the
  emitted typed actions
- updated the mixed `OSC 777` / `OSC 1337 Copy` test so only the notification
  path stays silent while the clipboard bridge emits
- validation completed:
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon fmt`
  - `moon info`
