# P15 Terminal Playground

## Goal

Build an instantly usable browser demo for the translated terminal surface.

The demo should:

- require no external trace or snapshot input
- use a MoonBit `wasm-gc` adapter, not the raw package surface
- keep the exported boundary intentionally small and JS-friendly
- use a TypeScript shell for DOM, presets, and rendering

## Boundary

MoonBit adapter responsibilities:

- own session lifecycle
- apply VT input to a `StreamTerminal`
- expose formatted HTML/plain/VT snapshots
- expose lightweight typed state and cell inspection
- capture terminal side effects such as bell count and PTY writes

TypeScript shell responsibilities:

- demo layout and interaction
- built-in scenarios and editable input
- escape-sequence parsing from the editor
- terminal viewport rendering and inspector panels
- browser loading, error handling, and local-serve UX

## Export policy

Do not export raw terminal internals across the browser boundary.

Prefer:

- integer session handles
- `String`
- `Int`
- `Bool`

Avoid:

- exposing `StreamTerminal` directly
- exporting internal structs/enums only to satisfy the web shell
- widening the main `src/terminal` public API for demo-only needs

## Planned files

MoonBit:

- `tools/terminal_playground_core/moon.pkg`
- `tools/terminal_playground_core/playground_core.mbt`
- `tools/terminal_playground_core/playground_core_test.mbt`

Web shell:

- `demo/terminal_playground/index.html`
- `demo/terminal_playground/styles.css`
- `demo/terminal_playground/src/main.ts`
- `demo/terminal_playground/dist/main.js`
- `demo/terminal_playground/tsconfig.json`
- local raster assets copied from upstream Ghostty art

## Acceptance

- browser demo starts with built-in scenarios and editable input
- main viewport reflects MoonBit terminal state, not mocked HTML
- presets cover styling, cursor/modes, scrollback, alternate screen,
  hyperlink/title behavior, and kitty graphics
- inspector surface is sufficient to understand what the terminal is doing
- local server startup path is straightforward

## Validation

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`
- `moon build --target wasm-gc tools/terminal_playground_core`
- `tsc -p demo/terminal_playground`
- local HTTP smoke check after build

## Audit notes

- Keep the main plan concise; implementation specifics live here.
- If `wasm-gc` interop forces awkward export shapes, prefer adapter flattening
  over widening core package APIs.
- `P15.A` landed as a separate adapter package under
  `tools/terminal_playground_core/`.
- Final adapter exports are:
  `playground_new`, `playground_free`, `playground_reset`,
  `playground_resize`, `playground_apply_text`, `playground_scroll_delta`,
  `playground_render_html`, `playground_render_plain`,
  `playground_render_vt`, `playground_state_json`,
  `playground_cell_json`, `playground_kitty_json`,
  `playground_pty_output`, and `playground_clear_pty_output`.
- Adapter validation passed:
  - `moon check tools/terminal_playground_core`
  - `moon test tools/terminal_playground_core`
  - `moon coverage analyze`
  - `moon fmt`
  - `moon info`
  - `moon build --target wasm-gc tools/terminal_playground_core`
- Built artifact path for the web shell:
  `_build/wasm-gc/debug/build/tools/terminal_playground_core/terminal_playground_core.wasm`
- Coverage residue for the touched adapter file is limited to 13 lines:
  enum/stringification helper branches for rarely-reached values
  (`CursorVisualStyle::Underline`, `RowSemanticPrompt::Prompt`,
  `SemanticContent::Input`, `PageCellContentTag::CodepointGrapheme`,
  `PageCellWide::SpacerHead`, `SgrUnderline::Double`,
  `KittyGraphicsFormat::Rgba`, `KittyGraphicsCompression::ZlibDeflate`)
  plus null/optional serialization helpers that are not worth widening the
  public demo surface to hit more directly.
- Node v23 did not honor the `js-string` builtin compile options during the
  local smoke check; the browser loader should use `WebAssembly.instantiate`
  or `WebAssembly.instantiateStreaming` with:
  - `importObject = { _: {} }`
  - `compileOptions = { builtins: ["js-string"], importedStringConstants: "_" }`
  and feature-detect support at runtime.
- `P15.B` ships the compiled `dist/main.js` alongside the TypeScript source so
  the demo can be served as static files without adding an npm build step.
- `P15.C` smoke check passed via:
  - `python3 -m http.server 12381 --bind 127.0.0.1`
  - `curl -sSf http://127.0.0.1:12381/demo/terminal_playground/`
  - `curl -sSIf http://127.0.0.1:12381/_build/wasm-gc/debug/build/tools/terminal_playground_core/terminal_playground_core.wasm`
- Local entry URL:
  `http://127.0.0.1:12381/demo/terminal_playground/`
- The served wasm artifact returned `200 OK` with `Content-Type:
  application/wasm`.
