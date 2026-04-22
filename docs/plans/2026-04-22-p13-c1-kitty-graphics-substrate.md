# P13.C1 Kitty Graphics Substrate

## Goal

Translate the internal kitty-graphics model and command-application substrate
needed behind `src/terminal/c/kitty_graphics.zig`, without exposing the host
graphics surface yet.

## Upstream files

- `upstream/ghostty/src/terminal/c/kitty_graphics.zig`
- `upstream/ghostty/src/terminal/apc.zig`
- `upstream/ghostty/src/terminal/Screen.zig`
- `upstream/ghostty/src/terminal/kitty/graphics_command.zig`
- `upstream/ghostty/src/terminal/kitty/graphics_storage.zig`
- `upstream/ghostty/src/terminal/kitty/graphics_exec.zig`

## MoonBit targets

- `src/terminal/apc.mbt`
- `src/terminal/apc_wbtest.mbt`
- `src/terminal/kitty_graphics_command.mbt`
- `src/terminal/kitty_graphics_command_wbtest.mbt`
- `src/terminal/kitty_graphics_state.mbt`
- `src/terminal/kitty_graphics_state_wbtest.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/stream_terminal_bridge_wbtest.mbt`
- `src/terminal/terminal_screen_state.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p13-c1-kitty-graphics-substrate.md`

## Public surface

None.

This slice is intentionally internal-only. The kitty-graphics command types,
storage types, and bridge helpers stay package-private, and `pkg.generated.mbti`
does not grow any new public graphics surface in this phase.

## Fidelity notes

- APC now parses kitty graphics into a typed internal command model rather than
  leaving it as raw bytes.
- Screen-owned kitty-graphics storage now tracks images, placements, loading
  state, image-id allocation, and transmit sequencing.
- The terminal bridge now applies kitty graphics query, transmit,
  transmit-and-display, display, and delete actions directly against the
  translated screen state.
- Active-screen store/load and full reset now preserve or clear kitty-graphics
  state in the same places the upstream screen/terminal flow does.
- `BuildInfo::kitty_graphics()` deliberately stays `false` in this phase,
  because the public host graphics surface from `src/terminal/c/kitty_graphics.zig`
  is still deferred to `P13.C2`.

## Validation

Ran:

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage review

Touched-file coverage is complete for the reachable kitty-graphics behavior in:

- `src/terminal/apc.mbt`
- `src/terminal/kitty_graphics_command.mbt`
- `src/terminal/kitty_graphics_state.mbt`
- `src/terminal/terminal_screen_state.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/apc_wbtest.mbt`
- `src/terminal/kitty_graphics_command_wbtest.mbt`
- `src/terminal/kitty_graphics_state_wbtest.mbt`
- `src/terminal/stream_terminal_bridge_wbtest.mbt`

`moon coverage analyze` still reports two uncovered lines in
`src/terminal/stream_terminal_bridge.mbt`, and both are acceptable residue:

- `src/terminal/stream_terminal_bridge.mbt:2374`
- `src/terminal/stream_terminal_bridge.mbt:2820`

Why they remain:

- `stream_terminal_bridge.mbt:2374` is the `Virtual => ()` arm in
  `apply_kitty_graphics_cursor_movement`. The function already returns when the
  placement is virtual, so the later `Virtual` arm is an internal safety
  fallback that cannot be reached through consistent state.
- `stream_terminal_bridge.mbt:2820` is the `None => return` arm in
  `cursor_left`. That reverse-wrap row-missing fallback predates this task and
  is not introduced by the kitty-graphics substrate work.

Remaining uncovered lines outside this task stay tracked in earlier audits.

## API review

Intentional public API result:

- no new public items

Kept out of the public API on purpose:

- kitty-graphics command structs and enums
- kitty-graphics image and placement storage
- loading-state internals
- bridge execution helpers
- host-facing image/query/iterator wrappers

## Notes

- Whitebox tests are used here to keep the substrate private while still
  covering parser and bridge helpers that are not reachable from the current
  public host surface.
