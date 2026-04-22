# P14.B: Terminal Surface Registry

## Goal

Translate `upstream/ghostty/src/terminal/c/types.zig` into a MoonBit-native
metadata surface that describes the implemented `src/terminal/c` parity layer
without carrying forward ABI-layout concerns that only existed for C and WASM
consumers.

## Upstream files

- `upstream/ghostty/src/terminal/c/types.zig`

## MoonBit targets

- `src/terminal/terminal_surface_registry.mbt`
- `src/terminal/terminal_surface_registry_test.mbt`

## Dependencies

- `P13.A2` render owner surface
- `P13.B` formatter surface
- `P13.C2` kitty graphics host surface
- `P12.B1` / `P12.B2` input encoder surfaces
- `P11.C` grid-ref and page query surface
- `P9.C` selection surface

## Design

- Keep the upstream type list and ordering so the registry still traces back to
  `types.zig`.
- Replace size/align/offset metadata with MoonBit translation metadata:
  - direct type mappings
  - native MoonBit replacements
  - absorbed owner-surface replacements
- Use the registry as the primary surface; do not export JSON unless a real
  consumer appears.

## Acceptance criteria

- every upstream `types.zig` entry is represented in the translated registry
- direct, native, and absorbed mappings are explicit in the public API
- the registry stays small and does not invent fake C-shaped wrapper modules
- tests cover ordering, lookup, and representative direct/native/absorbed cases

## Validation

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Audit notes

- `GhosttyString` is intentionally translated as a native MoonBit result shape
  (`String` / `Bytes`) instead of a standalone wrapper type.
- `GhosttyTerminalOptions`, `GhosttyTerminalScrollViewport`, and
  `GhosttyRenderStateColors` are intentionally marked as absorbed into owner
  surfaces because their C wrappers only existed to package method arguments or
  grouped getters.
- JSON stays out of the public API for now. If tooling needs it later, it
  should be derived from the typed registry rather than replacing it.
