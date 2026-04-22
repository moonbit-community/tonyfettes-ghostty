# P13.C2 Kitty Graphics Host Surface

## Goal

Translate the public MoonBit owner/query surface for kitty graphics and close
the remaining graphics-dependent terminal query hooks from
`src/terminal/c/kitty_graphics.zig` and the deferred graphics fields from
`src/terminal/c/terminal.zig`.

## Upstream files

- `upstream/ghostty/src/terminal/c/kitty_graphics.zig`
- `upstream/ghostty/src/terminal/c/terminal.zig`

## MoonBit targets

- `src/terminal/build_info.mbt`
- `src/terminal/build_info_test.mbt`
- `src/terminal/kitty_graphics.mbt`
- `src/terminal/kitty_graphics_test.mbt`
- `src/terminal/kitty_graphics_wbtest.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p13-c2-kitty-graphics-host-surface.md`

## Public surface

Intentional new public API:

- `BuildInfo::kitty_graphics() == true`
- `StreamTerminal::kitty_graphics()`
- `KittyGraphics`
- `KittyPlacementIterator`
- `KittyPlacement`
- `KittyImage`
- `KittyGraphicsFormat`
- `KittyGraphicsCompression`
- `KittyPlacementLayer`
- `KittyPlacementPixelSize`
- `KittyPlacementGridSize`
- `KittyPlacementSourceRect`
- `KittyPlacementViewportPosition`
- `KittyPlacementRenderInfo`

No public mutable fields were introduced.

## Fidelity notes

- The host surface is MoonBit-owned rather than C-dispatch-shaped: images,
  placements, and geometry are exposed through typed accessors instead of
  `get/get_multi` wrappers.
- `StreamTerminal::kitty_graphics()` is screen-scoped. A handle captures the
  target screen, and later queries continue to read that screen even after the
  active screen changes.
- Placement geometry stays faithful to the translated substrate:
  `rect`, `pixel_size`, `grid_size`, `viewport_position`, `source_rect`, and
  `render_info` all derive from the translated placement/image state rather
  than duplicating geometry logic in the public wrapper.
- `BuildInfo::kitty_graphics()` flips to `true` in this phase because the
  public host graphics surface is now materially present.

## Validation

Ran:

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage review

Touched-file coverage is complete for the reachable behavior in:

- `src/terminal/build_info.mbt`
- `src/terminal/build_info_test.mbt`
- `src/terminal/kitty_graphics_test.mbt`
- `src/terminal/kitty_graphics_wbtest.mbt`

`moon coverage analyze` still reports one uncovered line in
`src/terminal/kitty_graphics.mbt`, and it is acceptable residue:

- `src/terminal/kitty_graphics.mbt:301`

Why it remains:

- `kitty_graphics.mbt:301` is the `None => None` arm after `rect()` clamps
  `end_x` and `end_y` through `kitty_min_int` before calling
  `scrollback.grid_ref(...)`. Under valid translated grid/scrollback state,
  that `grid_ref` call cannot miss without violating the storage invariants.
  Whitebox coverage already exercises the other impossible-state guards in this
  file; this last branch is a defensive fallback only.

Remaining uncovered lines outside this task stay tracked in earlier audits.

## API review

Intentional `.mbti` growth is limited to the new kitty-graphics owner/query
surface listed above.

Kept out of the public API on purpose:

- internal kitty-graphics storage maps
- APC command and delete-model internals
- synthetic or invalid-state constructors used only for whitebox coverage

## Notes

- Blackbox tests cover the real public contracts: empty/default owner state,
  typed image lookup, source-rect and virtual-placement behavior, stale
  placement invalidation, inactive-screen handles, viewport behavior, and RGBA
  image/query geometry.
- Whitebox tests are used only for invariant-only cases that cannot be
  constructed through the public API: missing-image placement skipping,
  exhaustive helper conversion coverage, and the zero-row defensive guard.
