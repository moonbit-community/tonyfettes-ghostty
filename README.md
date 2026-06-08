# tonyfettes/ghostty

A MoonBit translation of the Ghostty terminal parser stack and terminal surface.

This repository is not a Ghostty frontend. It focuses on the terminal parsing,
state, formatting, input encoding, and host-facing terminal APIs that sit behind
Ghostty's UI. The upstream source of truth is vendored as a submodule under
`upstream/ghostty`, and the translation plan is tracked in `docs/`.

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

Out of scope for now:

- GTK, macOS, or other Ghostty frontend code
- native C ABI/export parity
- full PTY/runtime integration beyond examples and host callbacks
- packaging a complete terminal emulator application

For the detailed upstream-to-MoonBit architecture, read
[`docs/architecture.md`](docs/architecture.md). For a map of how the
`terminal` package and its sub-packages are organized (what lives where and how
to read it), see [`docs/terminal-package.md`](docs/terminal-package.md). For the
execution plan and quality gates, read [`docs/plan.md`](docs/plan.md).

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
docs/architecture.md           Parser stack architecture notes
docs/plan.md                   Translation plan, scope, and quality gates
docs/plans/                    Task-specific implementation plans and audits
examples/rabbita_asciinema/    Browser asciinema player using StreamTerminal
examples/terminal_playground/  Browser terminal playground (web shell + wasm-gc core/)
examples/tmux/                 Native mini tmux-like PTY multiplexer demo
tools/stream_terminal_perf/    StreamTerminal performance harness
upstream/ghostty/              Upstream Ghostty submodule
```

## Development

Install MoonBit, then from the repository root run the core validation commands:

```sh
moon check --target native
moon test --target native
moon check --target js
moon test --target js
moon coverage analyze -- -f summary
moon fmt
moon info
```

The examples live in a separate MoonBit module under `examples/` and contain
mixed target packages. Use explicit targets:

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

When changing MoonBit source, run the validation commands above and review any
generated interface churn before committing.

## License

This repository is licensed under Apache-2.0. The upstream Ghostty source under
`upstream/ghostty` is a submodule; consult that project for its own license and
source history.
