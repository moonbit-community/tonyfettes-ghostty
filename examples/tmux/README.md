# Mini Tmux PTY Demo

This native demo is a small tmux-like multiplexer built with
`moonbit-community/pty`, `moonbit-community/tty`, and Ghostty's translated
`StreamTerminal`.

It does not shell out to the system `tmux` binary. The default command is a
client that attaches to a small background server. The server owns panes, PTYs,
and terminal models, so detaching the client does not kill pane shells.

The demo renders pane borders, tracks the active pane, and maps the active pane
cursor back to the outer TTY. The outer multiplexer UI is colorized while pane
contents remain controlled by each pane's terminal stream.

Run it from the repository root:

```sh
moon -C examples run --target native tmux
```

The examples module contains both JS-only and native-only packages, so keep the
explicit `--target native` for this demo.

To stop the background session from outside the UI:

```sh
moon -C examples run --target native tmux kill-session
```

## Key Bindings

```text
Ctrl-b c   create a pane
Ctrl-b n   next pane
Ctrl-b o   next pane
Ctrl-b p   previous pane
Ctrl-b b   send literal Ctrl-b to the active pane
Ctrl-b q   display pane ids
Ctrl-b d   detach this client
Ctrl-b x   kill the active pane
Ctrl-b Q   kill the whole session
```

## Discovery

The client discovers the server through a user-local state directory:

- Linux/Unix: `$XDG_RUNTIME_DIR`, `$XDG_STATE_HOME`, then `$HOME/.local/state`
- macOS: `$HOME/Library/Application Support`
- Windows: `%LOCALAPPDATA%`

The demo stores `server.lock`, `server.json`, and `server.log` in a
`ghostty-mini-tmux` directory under that root. `server.json` contains the
server PID, lifecycle state, and localhost TCP port.
