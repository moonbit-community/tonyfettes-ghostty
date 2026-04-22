# P12.A Input Event Owner Types

## Goal

- Translate `src/terminal/c/key_event.zig` and `src/terminal/c/mouse_event.zig`
  into MoonBit owner surfaces that preserve the reachable semantics without
  carrying over allocator-style wrapper APIs.

## Upstream files

- `upstream/ghostty/src/terminal/c/key_event.zig`
- `upstream/ghostty/src/terminal/c/mouse_event.zig`
- `upstream/ghostty/src/input/key.zig`
- `upstream/ghostty/src/input/key_mods.zig`
- `upstream/ghostty/src/input/mouse.zig`
- `upstream/ghostty/src/input/mouse_encode.zig`

## MoonBit target files

- `src/terminal/key_event.mbt`
- `src/terminal/mouse_input_event.mbt`
- `src/terminal/key_event_test.mbt`
- `src/terminal/mouse_input_event_test.mbt`

## Dependency notes

- This task depends on `P9.A` only at the plan level, but practically it needs
  a small input-domain substrate because the upstream C wrappers are thin
  projections over `input/key.zig`, `input/key_mods.zig`, `input/mouse.zig`,
  and `input/mouse_encode.zig`.
- `P12.B` depends on this substrate, so `KeyMods` keeps the upstream packed-bit
  semantics and side metadata instead of collapsing down to only four booleans.
- The MoonBit target stays owner-oriented:
  `KeyEvent` and `MouseInputEvent` are persistent values with typed getters and
  setters, not allocator-tracked handles.

## Acceptance criteria

- Land typed MoonBit owner surfaces for key and mouse input events.
- Preserve the upstream event fields, defaults, and mutator semantics.
- Preserve the reachable upstream modifier bit semantics required by the
  upcoming encoder phase.
- Keep the public surface limited to externally meaningful value types and
  methods.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- Touched files are covered after the final `Key::codepoint` refactor back to
  an upstream-shaped codepoint table plus linear scan.
- Package-wide residual uncovered lines are pre-existing and unchanged:
  - `src/terminal/stream.mbt:222`
  - `src/terminal/stream_terminal_bridge.mbt:2427`
  - `tools/stream_terminal_perf/main.mbt`

## Commit scope

- `feat(c-input)`

## Review findings

- Kept the MoonBit surface owner-oriented and dropped allocator/free wrappers.
- Preserved the upstream packed modifier semantics, including left/right side
  metadata, because `P12.B` depends on that behavior.
- The `Key::codepoint` implementation was reshaped from a large match back to
  a static codepoint table so the logic stays closer to upstream `key.zig` and
  coverage remains reviewable.
- Public API review of `pkg.generated.mbti` is intentional:
  - exported semantic value enums: `Key`, `KeyAction`, `KeyModSide`,
    `MouseAction`, `MouseButton`
  - opaque owner/state types: `KeyMods`, `KeyEvent`, `MousePosition`,
    `MouseInputEvent`
  - no public mutable fields
  - no allocator-handle or `free`-style API carried into MoonBit

## Audit/result notes

- Added `KeyMods` as a tuple-struct bitmask wrapper with typed builders,
  getters, `binding`, `unset`, and `without_locks`.
- Added `KeyEvent` as the typed MoonBit owner for upstream key event state,
  including UTF-8 bytes payload and unshifted codepoint storage.
- Added `MouseInputEvent` and `MousePosition` as the typed MoonBit owner
  surface for upstream mouse-event state.
- Validation passed:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
