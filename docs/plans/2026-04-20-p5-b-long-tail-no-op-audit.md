# P5.B6 Long-Tail No-Op Audit

## Goal

Close `P5.B6` by auditing every translated OSC command that upstream
`stream.zig` still logs without emitting a typed stream action, and make that
silence explicit in tests and docs rather than leaving phase-placeholder
language behind.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/osc.zig`

## MoonBit target files

- `src/terminal/stream_test.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-19-p5-b-roadmap.md`
- `docs/plans/2026-04-20-p5-b-long-tail-no-op-audit.md`

## Audited no-op surface

- `ConEmuSleep`
- `ConEmuShowMessageBox`
- `ConEmuChangeTabTitle`
- `ConEmuWaitInput`
- `ConEmuGuiMacro`
- `ConEmuRunProcess`
- `ConEmuOutputEnvironmentVariable`
- `ConEmuXtermEmulation`
- `ConEmuComment`
- `KittyClipboardProtocol`
- `ContextSignal`
- `KittyTextSizing`

## Acceptance criteria

- every remaining translated OSC callback that upstream stream handling leaves
  logging-only is explicitly accounted for in the audit
- stream tests describe these callbacks as intentional no-ops, not unfinished
  future work
- no new typed `StreamAction` is added for callbacks upstream still leaves
  silent

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- no new source branches were introduced in this slice; it retitles existing
  no-op tests and closes the documentation audit
- repository coverage still reports the same single pre-existing uncovered line
  in `src/terminal/stream.mbt`:
  - `next_slice_capped` re-entering `consume_until_ground`
- this audit introduces no new uncovered lines

## Commit scope

- `docs`
- `test(stream)`

## Review findings

- no additional typed stream actions are justified here because upstream still
  treats this command set as logging-only
- the existing tests already cover the silent branches in three buckets:
  - `OSC 9` long-tail ConEmu callbacks
  - `OSC 5522` kitty clipboard protocol
  - `OSC 3008` context signal plus `OSC 66` kitty text sizing
- this audit intentionally keeps the public stream API unchanged

## Audit / result notes

- renamed the remaining OSC no-op stream tests so they now describe intentional
  upstream behavior instead of future phase placeholders
- recorded `P5.B6` as done in the Phase 5B roadmap
- marked `P5.B` complete in the main plan, leaving `P5.C` as the only pending
  Phase 5 implementation lane
- validation completed:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
