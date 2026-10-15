# tonyfettes/ghostty

A MoonBit translation of the Ghostty terminal parser stack and terminal surface.

This repository is not a Ghostty frontend. It focuses on the terminal parsing,
state, formatting, input encoding, and host-facing terminal APIs that sit behind
Ghostty's UI. The upstream source of truth is vendored as a submodule under
`upstream/ghostty`. Architecture and package guides live in `docs/`.

## Scope

The current project goal is a faithful MoonBit translation of Ghostty's parser
and terminal model layers:

- DEC ANSI parser state machine and parse table
- UTF-8 stream handling with Ghostty-compatible retry/replacement behavior
- CSI, OSC, DCS, SGR, and related semantic decoders
- `StreamTerminal` terminal state application
- formatter/render-state helpers for plain, VT, and HTML output
- input encoders, mouse helpers, selections, colors, palette state, and Kitty
  graphics metadata needed by the terminal surface

The approved extension into pure font and headless renderer code is underway.
The `font/` package currently contains font values, metrics, codepoint mapping,
atlas storage, and the pure sprite-font substrate. Face contracts, shaping, and
headless renderer helpers are not yet implemented; platform font backends,
system font discovery, GPU rendering, and external rasterizer/image-decoder
adapters are outside the current implementation scope.

Out of scope for now:

- GTK, macOS, or other Ghostty frontend code
- native C ABI/export parity
- full PTY/runtime integration beyond examples and host callbacks
- packaging a complete terminal emulator application

For the detailed upstream-to-MoonBit architecture, read
[`docs/architecture.md`](docs/architecture.md). For a map of how the
`terminal` package and its sub-packages are organized (what lives where and how
to read it), see [`docs/terminal-package.md`](docs/terminal-package.md).

## Package

The main public package is:

```text
tonyfettes/ghostty/terminal
```

In a MoonBit package, import it from `moon.pkg`:

```moonbit
import {
  "tonyfettes/ghostty/terminal"
  "moonbitlang/core/encoding/utf8"
}
```

Minimal usage:

```moonbit
///|
fn render_plain(input : Bytes) -> String {
  let terminal = @terminal.StreamTerminal::new()
  ignore(terminal.resize(80, 24, 8U, 16U))
  terminal.next_slice(input)
  let formatter = @terminal.Formatter::new_terminal(
    terminal,
    @terminal.FormatterOptions::new(
      Plain,
      trim=true,
      extra=@terminal.FormatterTerminalExtra::none(),
    ),
  )
  @utf8.decode_lossy(formatter.format())
}
```

The generated public interface lives at
[`terminal/pkg.generated.mbti`](terminal/pkg.generated.mbti).

## Repository Layout

```text
terminal/                      MoonBit terminal parser and model package
font/                          Pure font values, atlas, and sprite-font substrate
docs/architecture.md           Parser stack architecture notes
docs/terminal-package.md       Current terminal package navigation
examples/rabbita_asciinema/    Browser asciinema player using StreamTerminal
examples/terminal_playground/  Browser terminal playground (web shell + wasm-gc core/)
examples/tmux/                 Native mini tmux-like PTY multiplexer demo
bench/                         StreamTerminal benchmarks (moon bench) + per-workload profiling mains
upstream/ghostty/              Upstream Ghostty submodule
```

## Development

Install MoonBit, then from the repository root use the checks run by the
library's Ubuntu/Wasm CI:

```sh
moon check --target wasm
moon test --target wasm
moon fmt
moon info
```

Choose additional targets (`native`, `js`, or `wasm-gc`) when the change affects
their behavior. For changes that need a coverage review, collect coverage with
`moon test --target wasm --enable-coverage`, then inspect it with
`moon coverage analyze -- -f summary`. Review generated `.mbti` changes when
the public interface changes. Documentation-only edits need a content and link
check, rather than a MoonBit test run.

The examples live in a separate MoonBit module under `examples/` and contain
mixed target packages. Choose the target relevant to the example being changed:

```sh
moon -C examples check --target js
moon -C examples test --target js
moon -C examples check --target native
moon -C examples test --target native
```

## Examples

- [Rabbita asciinema player](examples/rabbita_asciinema/README.md)
- [Mini tmux PTY demo](examples/tmux/README.md)

## Translation Notes

The translation is intentionally conservative:

- parser state transitions stay table-driven
- `Parser.next` action ordering is preserved
- OSC and DCS parsing remain separate semantic layers
- terminal state and host callbacks are kept distinct
- public MoonBit APIs are reviewed through generated `.mbti` files

Keep validation focused on the behavior and targets affected by the change.

## License

This repository is licensed under Apache-2.0. The upstream Ghostty source under
`upstream/ghostty` is a submodule; consult that project for its own license and
source history.
