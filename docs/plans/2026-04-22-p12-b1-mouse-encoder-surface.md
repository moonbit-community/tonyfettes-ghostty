# P12.B1 Audit

## Goal

Translate `upstream/ghostty/src/terminal/c/mouse_encode.zig` into a MoonBit
owner surface that preserves the upstream mouse-reporting semantics without the
C out-buffer API.

## Upstream files

- `upstream/ghostty/src/terminal/c/mouse_encode.zig`
- `upstream/ghostty/src/input/mouse_encode.zig`

## MoonBit targets

- `src/terminal/mouse_encoder.mbt`
- `src/terminal/mouse_encoder_test.mbt`

## Public surface

- `MouseEncoderSize`
- `MouseEncoder`

The public API stays typed and MoonBit-owned:

- `MouseEncoder::encode(...) -> Bytes`
- `MouseEncoder::sync_from_terminal(...)`
- typed getters and setters for event mode, format, size, button state, and
  motion dedupe tracking

The C wrapper's out-buffer and `out_of_space` behavior is intentionally
absorbed into owned `Bytes` results because native C ABI parity is out of
scope.

## Fidelity notes

- `sync_from_terminal` follows upstream `setopt_from_terminal` and only copies
  mouse event mode and format. Size remains caller-owned.
- motion dedupe is preserved through `track_last_cell` and `reset`
- X10, UTF-8, SGR, URXVT, and SGR-Pixels formats are all covered
- out-of-viewport motion follows upstream behavior: only motion-reporting modes
  may emit, and only while `any_button_pressed` is true

## Validation

- `moon check`
- `moon test src/terminal/mouse_encoder_test.mbt`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage review

The touched executable lines in `mouse_encoder.mbt` are intended to be covered
by the dedicated blackbox suite:

- constructor and typed option access
- terminal-derived defaults
- each reporting mode branch
- each output format branch
- motion dedupe and reset
- viewport boundary and unsupported-button cases

Any remaining uncovered lines after the full coverage run should be reviewed
against pre-existing residue outside this task.

## API review

- no public mutable fields
- no internal dedupe state leaks
- no new C-shaped buffer/result wrappers
