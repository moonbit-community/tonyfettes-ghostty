# The `terminal` Package — Navigation Map

This is a reading guide for `tonyfettes/ghostty/terminal` and its sub-packages.
For the upstream parser architecture and invariants, see
[`architecture.md`](architecture.md). This document maps the current MoonBit
code; the [README](../README.md#scope) describes project scope.

## Big picture: one data flow

```text
host bytes
    │
    ▼
StreamTerminal::next_slice                 terminal/stream_terminal.mbt
    │
    ▼
@stream.Stream                            terminal/stream/stream.mbt
    ├── ground-state UTF-8 ──────────────▶ @utf8_decoder
    └── control parser ──────────────────▶ @parser (embeds @osc)
    │   CSI / ESC / OSC semantics; SGR attributes decoded by @sgr
    ▼
StreamTerminalHandler → bridge            terminal/stream_terminal_bridge.mbt
    ├── terminal state ──────────────────▶ @grid · @pagelist · state packages
    └── host effects ────────────────────▶ callbacks (PTY writes, bell, title…)

terminal state → Formatter (plain/VT/HTML) · RenderState
input events + terminal modes → key/mouse encoders → bytes
```

The top-level `terminal` package integrates the parser, state packages, host
callbacks, and output helpers. Sub-packages own both decoder layers and reusable
state or encoding components.

## Sub-packages

Paths below are relative to `terminal/`. Package imports in each `moon.pkg` are
the source of truth for dependencies; the table is grouped by responsibility,
not import order.

| Package | Role |
|---|---|
| [`ascii`](../terminal/ascii/), [`ansi`](../terminal/ansi/) | ASCII parsing/writing and terminal control constants |
| [`utf8_decoder`](../terminal/utf8_decoder/) | Ground-state UTF-8 decoding and control-byte boundaries |
| [`parser`](../terminal/parser/) | DEC ANSI state machine, transition table, and structural actions |
| [`osc`](../terminal/osc/) | OSC parsing, including colors, clipboard, semantic prompt, and context signals |
| [`sgr`](../terminal/sgr/), [`seplist`](../terminal/seplist/) | SGR attributes and CSI parameter-separator representation |
| [`stream`](../terminal/stream/), [`csi`](../terminal/csi/) | Byte-stream orchestration, semantic action dispatch, and CSI helpers |
| [`page`](../terminal/page/), [`grid`](../terminal/grid/) | Cell/row values, graphemes, and active-grid mutations |
| [`pagelist`](../terminal/pagelist/) | Scrollback, viewport, pins, resize/reflow, and saved-cursor state |
| [`cursor`](../terminal/cursor/), [`tabstops`](../terminal/tabstops/), [`mode`](../terminal/mode/) | Cursor geometry, tab stops, and terminal modes |
| [`style`](../terminal/style/), [`color`](../terminal/color/) | Cell styles and style interning, RGB/palette state, and X11 color names |
| [`charsets`](../terminal/charsets/) | VT character-set tables and slots |
| [`hyperlink`](../terminal/hyperlink/), [`hyperlink_state`](../terminal/hyperlink_state/) | Hyperlink storage and current OSC-8 state |
| [`semantic`](../terminal/semantic/), [`metadata`](../terminal/metadata/) | Semantic prompt state and title/working-directory metadata |
| [`protected`](../terminal/protected/), [`display_state`](../terminal/display_state/) | Protected cells and display-related state |
| [`selection`](../terminal/selection/), [`point`](../terminal/point/), [`size`](../terminal/size/) | Selection pins and geometry values |
| [`input`](../terminal/input/) | Key and mouse event data models |
| [`key_encoder`](../terminal/key_encoder/), [`mouse_encoder`](../terminal/mouse_encoder/) | Input-event encoding, configured from terminal modes by the facade |
| [`device`](../terminal/device/), [`size_report`](../terminal/size_report/) | Device and terminal-size report values/encoders |
| [`focus`](../terminal/focus/), [`paste`](../terminal/paste/) | Focus reports and bracketed-paste encoding |
| [`result_code`](../terminal/result_code/) | Terminal operation result codes |
| [`internal/bridge_effects`](../terminal/internal/bridge_effects/) | Host callback plumbing used by the terminal bridge |

For example, `stream` imports the parser and decoders; `parser` imports `osc`
and `seplist`. The state path has a separate dependency chain: `pagelist`
uses `grid`, which uses cell, cursor, style, and hyperlink values. These are
separate packages rather than one linear decoder dependency chain.

## The hub: `terminal/` files, grouped by job

The files below live directly in `terminal/`; related state and decoder code
lives in the sub-packages above.

### Facade and action application

- [`stream_terminal.mbt`](../terminal/stream_terminal.mbt) defines
  `StreamTerminal`, its stream handler, and public methods such as `new`,
  `next`, `next_slice`, and `resize`. It also synchronizes terminal modes into
  the separate key and mouse encoders.
- [`stream_terminal_bridge.mbt`](../terminal/stream_terminal_bridge.mbt)
  applies stream actions to terminal state and emits host effects. Start here
  to follow cursor movement, printing, SGR application, or a query response.
- [`apc.mbt`](../terminal/apc.mbt) handles the APC lifecycle and payload.

### Integrated state

- [`terminal_screen_storage.mbt`](../terminal/terminal_screen_storage.mbt)
  groups the grid, cursor, saved cursor, scrollback, graphics, and semantic
  state for primary/alternate screens.
- [`terminal_input_state.mbt`](../terminal/terminal_input_state.mbt) holds
  terminal input flags and Kitty keyboard state.
- [`selection_reexport.mbt`](../terminal/selection_reexport.mbt) exposes the
  selection package through the facade package.

### Output and graphics

- [`formatter.mbt`](../terminal/formatter.mbt) formats terminal contents as
  plain text, VT, or HTML.
- [`render_state.mbt`](../terminal/render_state.mbt) and
  [`render_row_iterator.mbt`](../terminal/render_row_iterator.mbt) provide
  render snapshots and row iteration.
- [`kitty_graphics_command.mbt`](../terminal/kitty_graphics_command.mbt),
  [`kitty_graphics_state.mbt`](../terminal/kitty_graphics_state.mbt), and
  [`kitty_graphics.mbt`](../terminal/kitty_graphics.mbt) cover graphics command
  parsing, image/placement state, and terminal integration.

### Host services and package metadata

- [`terminal_system.mbt`](../terminal/terminal_system.mbt) provides host hooks
  such as PNG decoding and logging.
- [`terminal_surface_registry.mbt`](../terminal/terminal_surface_registry.mbt)
  records the translated C-surface type registry.
- [`build_info.mbt`](../terminal/build_info.mbt),
  [`build_info_optimize_debug.mbt`](../terminal/build_info_optimize_debug.mbt),
  and [`build_info_optimize_release.mbt`](../terminal/build_info_optimize_release.mbt)
  expose build information; `moon.pkg` selects debug/release variants.

## Where to start reading

1. **Bytes → actions:** `stream_terminal.mbt` → `stream/stream.mbt` →
   `parser/parser.mbt`; follow `osc/` or `sgr/` for sequence-specific decoding.
2. **Actions → state:** `stream_terminal_bridge.mbt` → the relevant state
   package, such as `grid/`, `pagelist/`, or `style/`.
3. **State → output:** `formatter.mbt` or `render_state.mbt`.
4. **Input → bytes:** `input/` → `key_encoder/` or `mouse_encoder/`, with
   `StreamTerminal::sync_key_encoder` / `sync_mouse_encoder` supplying modes.

The generated interface in [`terminal/pkg.generated.mbti`](../terminal/pkg.generated.mbti)
is the public facade reference. Each sub-package also has its own generated
interface and `moon.pkg` import list.
