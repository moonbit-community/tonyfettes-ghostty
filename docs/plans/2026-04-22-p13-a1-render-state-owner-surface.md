# P13.A1 Render State Owner Surface

## Goal

Translate the global-state slice of `src/terminal/c/render.zig` into a
MoonBit-owned render snapshot surface before row iteration and row-cell work
begin.

## Upstream files

- `upstream/ghostty/src/terminal/c/render.zig`
- `upstream/ghostty/src/terminal/render.zig` global snapshot logic

## MoonBit targets

- `src/terminal/render_state.mbt`
- `src/terminal/render_state_test.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p13-a1-render-state-owner-surface.md`

## Public surface

- `RenderDirty`
- `RenderState`

The public owner API stays typed and MoonBit-owned:

- `RenderState::new()`
- `RenderState::update(StreamTerminal)`
- typed getters for dimensions, global colors, cursor state, palette, and
  cursor viewport snapshot
- `RenderState::set_dirty(RenderDirty)` for renderer-side acknowledgement

## Fidelity notes

- This task closes the global render snapshot only. Row iteration, row-cell
  snapshots, and renderer-side row dirtiness remain in `P13.A2`.
- `RenderDirty::Partial` is preserved in the public API because upstream render
  state exposes it, but `RenderState::update` intentionally produces only
  `Full` or `False` in this slice. `Partial` becomes producer-visible only once
  row tracking lands in `P13.A2`.
- Background and foreground colors follow the upstream reverse-color rule by
  swapping the resolved values when `Mode::ReverseColors` is enabled.
- `cursor_password_input` currently stays `false`. The current translated
  `src/terminal/c` host surface has no input source for that flag, and the
  upstream C wrapper also reads it from terminal internals rather than from a C
  setter. That gap is recorded here rather than hidden.
- Cursor viewport visibility is derived through the existing `GridRef` and
  `point_from_grid_ref(..., Tag::Viewport)` path so the render owner stays on
  top of the translated terminal surface rather than duplicating viewport math.

## Validation

Ran:

- `moon check`
- `moon test`
- `moon test src/terminal/render_state_test.mbt`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage review

Touched-file coverage is complete after the full task gate:

- `src/terminal/render_state.mbt`
- `src/terminal/render_state_test.mbt`

The remaining uncovered lines reported by `moon coverage analyze` are
pre-existing outside this task:

- `src/terminal/key_encoder.mbt`
- `src/terminal/key_encoder_function_keys.mbt`
- `src/terminal/stream.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `tools/stream_terminal_perf/main.mbt`

The render-state tests cover:

- default snapshot state
- manual dirty overrides
- reverse-color snapshot resolution
- cursor style and blinking capture
- palette cloning
- stable-update clean state
- mutation-driven full dirty
- cursor viewport visibility across viewport scrolling

## API review

Intentional new public surface:

- `RenderDirty`
- `RenderState`

Kept out of the public API on purpose:

- enum-keyed `Data`/`SetOption` dispatch
- C-style output-pointer query helpers
- row iterators and row-cell wrappers
- direct access to terminal/page internals

## Notes

- The current render owner depends only on existing translated terminal queries.
  It does not add new terminal public API.
