# Mini Tmux PTY Demo

This native demo is a small tmux-like multiplexer built with
`moonbit-community/pty`, `moonbit-community/tty`, and Ghostty's translated
`StreamTerminal`.

It does not shell out to the system `tmux` binary. Each pane owns its own PTY
and terminal model. The demo renders pane borders, tracks the active pane, and
maps the active pane cursor back to the outer TTY. The outer multiplexer UI is
colorized while pane contents remain controlled by each pane's terminal stream.

Run it from the repository root:

```sh
moon -C examples run --target native tmux
```

The examples module contains both JS-only and native-only packages, so keep the
explicit `--target native` for this demo.

## Key Bindings

```text
Ctrl-b c   create a pane
Ctrl-b n   next pane
Ctrl-b o   next pane
Ctrl-b p   previous pane
Ctrl-b b   send literal Ctrl-b to the active pane
Ctrl-b q   quit
Ctrl-b x   quit
```
