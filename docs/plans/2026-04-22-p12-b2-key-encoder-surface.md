# P12.B2 Audit

## Goal

Translate `upstream/ghostty/src/terminal/c/key_encode.zig` into a MoonBit owner
surface that preserves the upstream key-encoding semantics without the C
out-buffer API.

## Upstream files

- `upstream/ghostty/src/terminal/c/key_encode.zig`
- `upstream/ghostty/src/input/key_encode.zig`
- `upstream/ghostty/src/input/function_keys.zig`
- `upstream/ghostty/src/input/kitty.zig`
- `upstream/ghostty/src/input/config.zig`

## MoonBit targets

- `src/terminal/key_encoder.mbt`
- `src/terminal/key_encoder_function_keys.mbt`
- `src/terminal/key_encoder_kitty_table.mbt`
- `src/terminal/key_encoder_test.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p12-b2-key-encoder-surface.md`

## Public surface

- `OptionAsAlt`
- `KeyEncoder`

The public API stays typed and MoonBit-owned:

- `KeyEncoder::encode(...) -> Bytes`
- `KeyEncoder::sync_from_terminal(...)`
- typed getters and setters for cursor-key mode, keypad mode, keypad-numlock
  behavior, alt-prefix mode, modify-other-keys state 2, kitty flags, macOS
  option-as-alt policy, backarrow mode, and host-platform policy

The C wrapper's out-buffer and `out_of_space` behavior is intentionally
absorbed into owned `Bytes` results because native C ABI parity is out of
scope.

## Fidelity notes

- `sync_from_terminal` follows upstream `setopt_from_terminal` and only copies
  terminal-derived state. `macos_option_as_alt` and `host_is_macos` remain
  caller-owned because the translated MoonBit package must stay target-neutral.
- kitty protocol handling covers release/report-all/report-events gates,
  alternates, associated text, special-key finals, and legacy-compatible
  fallbacks for enter/tab/backspace.
- legacy handling covers PC-style function-key tables, keypad application
  tables, control-sequence mapping, modify-other-keys state 2, and macOS
  option-as-alt filtering.
- the kitty key table and function-key table stay internal to the package.

## Validation

Ran:

- `moon check`
- `moon test src/terminal/key_encoder_test.mbt`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage review

Touched-file coverage is functionally complete through the public `KeyEncoder`
surface.

`moon coverage analyze` still reports the following touched-file residue:

- `src/terminal/key_encoder.mbt:219`
- `src/terminal/key_encoder.mbt:649`
- `src/terminal/key_encoder.mbt:669`
- `src/terminal/key_encoder.mbt:835`
- `src/terminal/key_encoder_function_keys.mbt:72`
- `src/terminal/key_encoder_function_keys.mbt:90`
- `src/terminal/key_encoder_function_keys.mbt:99`
- `src/terminal/key_encoder_function_keys.mbt:123`
- `src/terminal/key_encoder_function_keys.mbt:129`
- `src/terminal/key_encoder_function_keys.mbt:165`
- `src/terminal/key_encoder_function_keys.mbt:219`
- `src/terminal/key_encoder_function_keys.mbt:261`
- `src/terminal/key_encoder_function_keys.mbt:277`
- `src/terminal/key_encoder_function_keys.mbt:293`

These split into two classes:

- invariant-only internal branches:
  - `key_encoder.mbt:219` is the private `encode_kitty -> encode_legacy`
    fallback, which the public `KeyEncoder::encode` entry point cannot reach
    because zero kitty flags route directly to legacy mode before entering the
    kitty helper
  - `key_encoder.mbt:835` is the `KittySequenceEvent::None` arm in the
    internal event-code helper; the helper is only called from branches that
    already require a non-`None` event
  - `key_encoder_function_keys.mbt:123,165,219,261,277,293` are
    selector-table fallback arms that are ruled out by the surrounding key-mod
    normalization or by earlier guards
- selector-arm residue:
  - `key_encoder.mbt:649,669`
  - `key_encoder_function_keys.mbt:72,90,99,129`

Those selector-arm lines are exercised through blackbox tests (`backspace`
legacy-compatible kitty fallback, `ctrl+1`, `ctrl+f`, `ArrowLeft`, `F2`,
`F8`, `Numpad4`, `NumpadRight`) but remain reported by `moon coverage analyze`
at the individual arm lines. The surrounding behavior is covered and asserted
through the public API.

Remaining uncovered lines outside this task are pre-existing:

- `src/terminal/stream.mbt:222`
- `src/terminal/stream_terminal_bridge.mbt:2427`
- `tools/stream_terminal_perf/main.mbt`

## API review

Intentional new public surface:

- `OptionAsAlt`
- `KeyEncoder`

No public mutable fields were introduced.

Kept out of the public API on purpose:

- the kitty table entries
- the PC-style function-key helpers
- intermediate kitty-sequence structs and event enums
- C-style buffer/result wrappers

## Notes

- `host_is_macos` is explicit on `KeyEncoder` rather than inferred from a
  native platform package. That keeps the translated package compatible with
  the existing `moon check` target matrix while still preserving the upstream
  macOS branches.
