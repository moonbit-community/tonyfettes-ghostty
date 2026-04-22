# P14.A System Hooks Surface

## Goal

Translate the package-global runtime hook surface from `src/terminal/c/sys.zig`
into a MoonBit-native system hook API, and wire the PNG decode hook into the
existing kitty-graphics load path so the surface has a real terminal consumer.

## Upstream files

- `upstream/ghostty/src/terminal/c/sys.zig`
- `upstream/ghostty/src/terminal/sys.zig`
- `upstream/ghostty/src/terminal/kitty/graphics_image.zig`

## MoonBit targets

- `src/terminal/terminal_system.mbt`
- `src/terminal/terminal_system_test.mbt`
- `src/terminal/terminal_system_wbtest.mbt`
- `src/terminal/kitty_graphics_state.mbt`
- `src/terminal/kitty_graphics_state_wbtest.mbt`
- `src/terminal/kitty_graphics_test.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p14-a-system-hooks-surface.md`

## Public surface

Intentional new public API:

- `SystemLogLevel`
- `SystemImage`
- `SystemImage::new()`
- `SystemImage::width()`
- `SystemImage::height()`
- `SystemImage::data()`
- `terminal_system_set_decode_png()`
- `terminal_system_clear_decode_png()`
- `terminal_system_set_log()`
- `terminal_system_clear_log()`
- `terminal_system_emit_log()`

No public mutable fields were introduced.

## Fidelity notes

- The MoonBit surface stays package-global, but it does not mirror the C
  `set(option, value)` ABI literally. The translated API uses typed functions
  instead of option dispatch and raw `userdata`.
- `userdata` is intentionally absent. MoonBit closures already carry captured
  state directly, so a separate userdata slot would be ABI baggage only.
- The log path preserves the upstream `logFn` chunking contract: messages are
  delivered in `2048`-byte chunks without heap formatting machinery.
- `log_stderr` is intentionally not translated in this slice. The current
  MoonBit reference surface used in this repo does not expose a stable stderr
  writer primitive comparable to the Zig helper, and adding a fake one here
  would not improve terminal semantics.
- PNG decode is now wired into kitty graphics finalization for the supported
  direct-medium, no-compression path:
  - no decoder installed => `UnsupportedFormat`
  - decoder returns invalid output => `InvalidData`
  - successful decode rewrites the image to RGBA and validates dimensions and
    payload length exactly like the RGB/RGBA path
- File, temporary-file, and shared-memory kitty graphics media remain
  unsupported in the translated terminal surface; this task does not widen that
  contract.

## Validation

Ran:

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage review

Touched-file coverage is complete for:

- `src/terminal/terminal_system.mbt`
- `src/terminal/terminal_system_test.mbt`
- `src/terminal/terminal_system_wbtest.mbt`
- `src/terminal/kitty_graphics_state.mbt`
- `src/terminal/kitty_graphics_state_wbtest.mbt`
- `src/terminal/kitty_graphics_test.mbt`

`moon coverage analyze` still reports pre-existing uncovered lines outside this
task in:

- `src/terminal/formatter.mbt`
- `src/terminal/key_encoder.mbt`
- `src/terminal/key_encoder_function_keys.mbt`
- `src/terminal/stream.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `tools/stream_terminal_perf/main.mbt`

Those residues were not widened by this slice.

## API review

Kept out of the public API on purpose:

- generic `system_set(option, value)` dispatch
- raw userdata plumbing
- internal decoder-installation flag and private decode helper
- allocator/free helpers
- synthetic stderr logger shim

The public surface is intentionally narrow: typed hook installation and one
typed log entrypoint.

## Notes

- Blackbox tests cover the public contracts: log callback installation,
  clearing, chunk splitting, exact chunk boundaries, and PNG transmit
  integration through `StreamTerminal`.
- A tiny whitebox test is used only for the internal decoder helper, so the
  package-global default decoder path stays covered without widening the public
  API.
- `P14.B` is the next dependency-ordered task.
