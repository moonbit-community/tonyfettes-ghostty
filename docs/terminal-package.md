# The `terminal` Package — Navigation Map

This is a reading guide for the `tonyfettes/ghostty/terminal` package and its
sub-packages. For the upstream-to-MoonBit parser architecture and invariants,
see [`architecture.md`](architecture.md); this document maps the *current*
MoonBit code so you know what lives where and how the pieces fit.

## Big picture: one data flow

```
host bytes
    │
    ▼
StreamTerminal::next_slice            (stream_terminal.mbt + stream_terminal_bridge.mbt)
    │   feeds bytes into…
    ▼
Stream  ── UTF-8 fast path ──────────▶ @utf8_decoder
    │   control bytes →
    ▼
@parser  (Parser.next → Action)        ANSI state machine (Layer 1)
    │   actions: CSI / OSC / DCS / ESC / print / execute
    ├── CSI · SGR ───────────────────▶ @sgr  (attribute parser)
    ├── OSC ─────────────────────────▶ @osc  (osc/kitty-color/clipboard/semantic…)
    └── colors / charsets ───────────▶ @color · @charsets
    │   the bridge applies each action to…
    ▼
Terminal state model                   (terminal_*_state.mbt, screen_*_state.mbt)
    │   screen buffer · cursor · styles · modes · kitty placements · …
    ▼
Output:  Formatter (plain/VT/HTML)  ·  RenderState  ·  encoders (key/mouse → bytes)
```

Everything below `@parser` in that diagram is an **extracted sub-package** (a
clean, faithful decoder layer). Everything from "apply actions" up is the
**hub** — the integrated terminal core that lives directly in `terminal/`.

## Sub-packages (the extracted layers)

These were split out so the layer boundaries from `architecture.md` are enforced
by the compiler. Each is imported by the hub (and by one another, in this order):

| Package | Role |
|---|---|
| `ascii` | low-level ASCII/byte parse+write helpers (`find_byte`, `parse_*_ascii`, `write_uint_ascii`) |
| `charsets` | VT character-set tables (`Charset`, `Slots`) |
| `color` | RGB, palette (`Name`/`Special`/`Dynamic`), `TerminalColors`, x11 names |
| `utf8_decoder` | ground-state UTF-8 decoder (`Utf8Decoder`) |
| `result_code` | `TerminalResultCode` status enum |
| `osc` | OSC semantic decoders (colors, kitty color/clipboard/text-sizing, semantic prompt, context signal) |
| `parser` | DEC ANSI state machine — `Parser`, `Action`, `Csi`/`Dcs`/`Esc` (embeds an `@osc.OscParser`) |
| `sgr` | SGR attribute parser (`SgrParser`, `SgrAttribute`) |
| `input` | input event **data model** (`Key`/`KeyEvent`, `Mouse*`) — the encoders stay in the hub |

Dependency order (no cycles): `ascii → utf8_decoder → osc → parser → sgr`, with
`color`/`charsets`/`result_code`/`input` as side leaves. The hub sits on top and
imports all of them.

## The hub: `terminal/` files, grouped by job

44 source files (~18k lines). MoonBit packages are a single directory, so the
grouping below is by **naming convention**, not folders.

### ① Facade / entry points
- `stream_terminal.mbt` — `StreamTerminal` struct + state accessors. The public
  entry: `new`, `next`, `next_slice`, `resize`.
- `stream_terminal_bridge.mbt` — the bulk of `StreamTerminal`'s methods: applies
  each parser action to the state model and produces host-facing effects
  (responses, callbacks). The single biggest file; start here to see how an
  action becomes a state change.

### ② Parse pipeline (bytes → actions)
- `stream.mbt` — `Stream`: UTF-8 ground-state fast path, drives `@parser`, and
  dispatches CSI/OSC/DCS/ESC actions. CSI semantics live here; SGR is delegated
  to `@sgr`.
- `ansi.mbt` — C0/C1 and escape-sequence constants and helpers.
- `csi.mbt`, `apc.mbt` — small CSI helper and the APC handler.

### ③ State model (the terminal's mutable data)
- `terminal_screen_state.mbt` — `TerminalScreen` + `PageList` (the scrollback
  buffer, a doubly-linked list of pages). Largest state file.
- `screen_grid_state.mbt` — `ScreenGridState`, the active cell grid.
- `page_state.mbt` — the cell model (`PageCellState`, `PageRowState`, wide-char).
- `terminal_cursor_state.mbt`, `terminal_saved_cursor_state.mbt` — cursor + DECSC.
- `terminal_style.mbt` — cell styling (uses `@color`, `@sgr`).
- `terminal_tabstops_state.mbt`, `terminal_input_state.mbt`,
  `terminal_metadata_state.mbt`, `terminal_protected_state.mbt`,
  `terminal_display_state.mbt`, `terminal_scrollbar.mbt` — focused state slices.
- `screen_semantic_state.mbt`, `screen_hyperlink_state.mbt` — semantic prompt
  zones and OSC-8 hyperlinks.
- `selection.mbt` — selection rectangles (depends on `TerminalScreen`).
- `point.mbt`, `size.mbt` — `Point`/`Coordinate`/`Size` geometry primitives.

### ④ Output (state → text/bytes)
- `formatter.mbt` — `Formatter`: renders the screen to Plain / VT / HTML
  (`Formatter::new_terminal`, `Formatter::format`).
- `render_state.mbt`, `render_row_iterator.mbt` — render snapshot + row walking.

### ⑤ Features (self-contained, hub-integrated)
- Kitty graphics: `kitty_graphics_command.mbt` (protocol parse),
  `kitty_graphics_state.mbt` (placement state on the screen),
  `kitty_graphics.mbt` (screen integration). Tied to the screen model, so it
  stays in the hub.
- Input encoders: `key_encoder.mbt`, `key_encoder_function_keys.mbt`,
  `key_encoder_kitty_table.mbt`, `mouse_encoder.mbt`. They read `StreamTerminal`
  state to encode `@input` events into bytes, so they stay in the hub.
- `modes.mbt` — DEC/ANSI mode state. `device_attributes.mbt`/`device_status.mbt`
  — DA/DSR query replies. `paste.mbt` — bracketed paste. `focus.mbt` — focus
  reporting. `size_report.mbt` — XTWINOPS-style size reports.
- `terminal_system.mbt` — host hooks (PNG decode, logging).
  `terminal_surface_registry.mbt` — C-surface type registry.

### ⑥ Build metadata
- `build_info.mbt` + `build_info_optimize_{debug,release}.mbt` — target/build
  flags (selected per target in `moon.pkg`).

## Where to start reading

1. **Entry → action**: `stream_terminal.mbt` (`next_slice`) → `stream.mbt`
   (parse loop) → see `@parser` for the state machine.
2. **Action → state**: pick any `StreamTerminal::…` method in
   `stream_terminal_bridge.mbt` (e.g. cursor movement, SGR apply) and follow it
   into the relevant `*_state.mbt` file.
3. **State → output**: `formatter.mbt`.

## Why the hub is not split further

The hub is the *integrated* terminal core, and three things make further
package extraction unprofitable or impossible:

- **Bidirectional coupling.** Kitty graphics holds the screen (`TerminalScreen`,
  `PageList`) *and* the screen state holds `KittyGraphicsState`. Splitting them
  would create an import cycle (forbidden) for no encapsulation gain.
- **Cross-package mutation.** The bridge builds many feature structs by mutating
  their fields directly; moving the types out would force `pub(all)` on all of
  them, exposing internals instead of hiding them.
- **The state model is one web.** `PageList` is not a generic list — it is the
  scrollback buffer welded to the cell grid, cursor, styles, and kitty state.
  It can only move as one large, deeply-interconnected `state` package, with a
  big public surface and marginal benefit (the hub's logic still sits on top).

So `terminal/` being large is expected: it is the cohesive terminal engine
behind the public `@terminal.StreamTerminal` / `@terminal.Formatter` API. The
decoder layers (`parser`, `osc`, `sgr`, …) are what factor out cleanly, and they
already have.
