# Phase 1.B Color, Mouse, and Device Foundations

## Goal

Translate the parser-facing foundation files:

- `color.zig`
- `x11_color.zig`
- `mouse.zig`
- `device_attributes.zig`
- `device_status.zig`

This lane must stay green on its own and keep the scope limited to values,
encoders, and parsers that the Ghostty parser stack depends on.

## Upstream files

- `upstream/ghostty/src/terminal/color.zig`
- `upstream/ghostty/src/terminal/x11_color.zig`
- `upstream/ghostty/src/terminal/mouse.zig`
- `upstream/ghostty/src/terminal/device_attributes.zig`
- `upstream/ghostty/src/terminal/device_status.zig`
- `upstream/ghostty/src/terminal/res/rgb.txt`

## MoonBit target files

- `src/terminal/color.mbt`
- `src/terminal/x11_color.mbt`
- `src/terminal/x11_color_tables.mbt`
- `src/terminal/mouse.mbt`
- `src/terminal/device_attributes.mbt`
- `src/terminal/device_status.mbt`
- `src/terminal/color_wbtest.mbt`
- `src/terminal/x11_color_wbtest.mbt`
- `src/terminal/mouse_wbtest.mbt`
- `src/terminal/device_attributes_wbtest.mbt`
- `src/terminal/device_status_wbtest.mbt`
- `tools/gen_x11_color_data.py`
- `docs/plans/2026-04-18-p1-b-color-mouse-device.md`

## Dependencies and invariants

- Keep the lane self-contained inside `src/terminal`.
- Preserve the exact DA and DSR numeric encodings and lookup behavior.
- Preserve mouse event/format inventories and cursor-shape string mappings.
- Preserve the parser-facing color contracts:
  - standard named color defaults via `Name`
  - OSC special and dynamic color indices
  - `RGB.parse` support for `#...`, `rgb:...`, `rgbi:...`, and X11 names
- Use generated static X11 color data from `rgb.txt`; do not build the name
  table dynamically at runtime.
- Defer `Palette`, `DynamicPalette`, `DynamicRGB`, `LAB`,
  `generate256Color`, and other rendering/theme-generation logic from
  `color.zig`; they are not needed to unblock the parser stack.

## Acceptance criteria

- `mouse`, `device_attributes`, and `device_status` contracts match the
  upstream parser-facing behavior in covered tests.
- `color` includes the parser-facing enums, default named colors, X11 lookup,
  and `RGB.parse`.
- The generated X11 dataset is reproducible from `rgb.txt`.
- `moon check`, `moon test`, `moon fmt`, and `moon info` pass.

## Validation commands

- `python3 tools/gen_x11_color_data.py`
- `moon check`
- `moon test`
- `moon fmt`
- `moon info`

## Commit scope

- `feat(parser-foundation)`: add color, mouse, and device foundations

## Review findings

- Explorer findings narrowed the lane to the parser-facing slice of
  `color.zig` plus full `mouse`, `device_attributes`, and `device_status`.
- Main-agent review checked the MoonBit code against the upstream Zig files
  and kept the scope intentionally short of palette/theme-generation logic.
- No remaining correctness issues were found in the landed scope after the
  green validation pass. Residual risk is limited to later work that will
  need the deferred `color.zig` palette-generation path.

## Audit/result notes

- Added `src/terminal/color.mbt` with `ColorParseError`, `RGB`, named color
  defaults, xterm special/dynamic color indices, and `RGB.parse`.
- Added `src/terminal/x11_color.mbt` and generated
  `src/terminal/x11_color_tables.mbt` from upstream `rgb.txt` using
  `tools/gen_x11_color_data.py`.
- Added `src/terminal/mouse.mbt` with mouse event/format enums and the full
  cursor-shape synonym table from upstream.
- Added `src/terminal/device_attributes.mbt` with DA request routing, primary,
  secondary, and tertiary encoders, conformance levels, device types, and
  feature codes.
- Added `src/terminal/device_status.mbt` with the packed tag layout,
  request-to-tag mapping, and request lookup.
- Added whitebox tests in `src/terminal/color_wbtest.mbt`,
  `src/terminal/x11_color_wbtest.mbt`, `src/terminal/mouse_wbtest.mbt`,
  `src/terminal/device_attributes_wbtest.mbt`, and
  `src/terminal/device_status_wbtest.mbt`.
- Validation:
  - `python3 tools/gen_x11_color_data.py`
  - `moon check` passed
  - `moon test` passed: 32 passed, 0 failed
  - `moon fmt` ran clean
  - `moon info` ran clean
- Current warnings are expected unused-constructor / never-constructed
  warnings on foundational types that are not wired into later parser layers
  yet.
