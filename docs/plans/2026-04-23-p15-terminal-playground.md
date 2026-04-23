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

- `tools/terminal_playground_core/moon.pkg.json`
- `tools/terminal_playground_core/playground_core.mbt`
- `tools/terminal_playground_core/playground_core_test.mbt`

Web shell:

- `demo/terminal_playground/index.html`
- `demo/terminal_playground/styles.css`
- `demo/terminal_playground/src/main.ts`
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
