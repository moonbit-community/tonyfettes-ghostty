# P5.A9 Execute / ESC / CSI Closeout Parity Audit

## Goal

Close `P5.A` by verifying that upstream `execute`, `escDispatch`, and
`csiDispatch` semantic branches are either translated into MoonBit stream
actions or intentionally left silent where upstream behavior is only logging or
unsupported-control handling.

## Upstream files reviewed

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/kitty/key.zig`

## MoonBit files reviewed

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plans/2026-04-19-p5-a-roadmap.md`
- prior `P5.A*` audit files

## Dependency notes

This is the closeout audit for the execute / ESC / CSI lane only.

Out of scope here:

- OSC dispatch wiring (`P5.B`)
- DCS / APC passthrough (`P5.C`)
- terminal-side application of stream actions (`Phase 6`)

## Findings

### `execute` parity

- C0 controls with direct terminal semantics are represented:
  - `ENQ`
  - `BEL`
  - `BS`
  - `HT`
  - `LF`
  - `VT`
  - `FF`
  - `CR`
  - `SO`
  - `SI`
- Ignored controls such as `NUL`, `SOH`, and `STX` remain silent.
- Invalid control cases are also silent, matching the effective upstream
  behavior where unsupported forms only log and do not emit semantic actions.

### `escDispatch` parity

- Character-set configuration and invocation are translated.
- Cursor save / restore are translated.
- `DECALN`, `IND`, `NEL`, `RI`, and `HTS` are translated.
- Protected-mode toggles, `DECID`, and full reset are translated.
- `ST` remains a no-op at the stream semantic layer.
- Unsupported forms stay silent.

### `csiDispatch` parity

- Cursor movement and positioning commands are translated.
- Erase, editing, tab, scrolling, and blank-insert commands are translated.
- Mode set / reset and mode save / restore are translated.
- SGR and modify-key-format are translated.
- Device attributes, device status, request-mode, active-status-display, and
  XT version reporting are translated.
- Margin-setting, cursor-style, protected-mode, XTWINOPS, and title-stack
  related actions are translated where they belong to the execute / ESC / CSI
  lane.
- Kitty keyboard protocol (`CSI u`) is translated with typed actions and tests.
- Unsupported or logging-only invalid forms stay silent.

## Public API audit

- `StreamAction` intentionally exposes the execute / ESC / CSI semantic surface
  needed by current blackbox consumers.
- `SgrAttribute`, `SgrUnderline`, `SgrUnknown`, and related value types remain
  public because they are part of emitted stream actions.
- `KittyKeyboardFlags` is intentionally public because it appears in public
  `StreamAction` variants.
- The generated interface still includes the compiler-generated deprecated
  tuple-struct accessor for `KittyKeyboardFlags`. That is accepted as part of
  MoonBit's tuple-struct surface and does not justify widening any additional
  API.

## Coverage review

Latest `moon coverage analyze` output for the current code leaves the same two
pre-existing structural residuals in `src/terminal/stream.mbt`:

- the inner `consume_until_ground` path in `next_slice_capped`
- the `Some(Print(codepoint))` path in `next_non_utf8`

No new execute / ESC / CSI coverage regressions were introduced while closing
`P5.A`.

## Validation

Latest validating run for the final `P5.A` code slice:

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

Result: pass.

## Result

`P5.A` is complete.

Remaining Phase 5 work:

- `P5.B` OSC dispatch wiring
- `P5.C` DCS / APC passthrough
