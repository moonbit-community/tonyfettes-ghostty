# P6.0 Terminal Dependency Checklist

## Goal

Record the exact minimum model and effect boundary needed to translate
`stream_terminal.zig` so Phase 6 implementation can be split into green,
non-cyclic terminal-state slices.

## Upstream files

- `upstream/ghostty/src/terminal/stream_terminal.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`
- `upstream/ghostty/src/terminal/Screen.zig`
- `upstream/ghostty/src/terminal/modes.zig`

## Direct handler-owned state

`stream_terminal.zig`’s handler owns only three things:

- `terminal: *Terminal`
- `effects`
- `apc_handler`

This means Phase 6 should keep APC-specific decode state local to the handler
and avoid dragging unrelated host/runtime concerns into the core terminal model.

## Minimal terminal-state dependency groups

### Core terminal mutation surface

Needed directly by `vtFallible`:

- print / print-repeat
- carriage return / linefeed / index / reverse index / next line
- cursor motion and absolute positioning
- erase / insert / delete / scroll primitives
- tab stop movement and tab-stop tables
- save / restore cursor
- margins and scrolling region
- DECALN / full reset / DECCOLM / screen switching
- charset invocation and configuration
- SGR / protected-mode updates
- hyperlink start / end
- semantic prompt application

### Terminal sub-state reached through fields

`stream_terminal.zig` mutates several nested state areas directly:

- `screens.active.cursor`
- `screens.active.kitty_keyboard`
- `scrolling_region`
- `modes`
- `flags`
- `colors`
- `status_display`
- `mouse_shape`

This argues for keeping Phase 6 split by state ownership rather than by escape
family.

### Query / effect boundary

These stream actions do not mutate terminal state directly and instead need
effect callbacks or PTY writes:

- bell
- enquiry
- device attributes
- device status
- mode reports
- size reports
- xtversion
- title-changed notification

Minimum effect callbacks upstream expects:

- `write_pty`
- `bell`
- `color_scheme`
- `device_attributes`
- `enquiry`
- `size`
- `title_changed`
- `xtversion`

### Intentional no-terminal-effect actions

Upstream `stream_terminal.zig` explicitly leaves these without terminal-state
mutation:

- DCS passthrough actions
- report-pwd
- desktop notification
- progress report
- clipboard contents
- title push / title pop

These should remain outside the minimal terminal model unless a later phase
explicitly gives them meaning.

## Phase 6 subplan boundaries

### P6.A Style + attributes

Own:

- terminal style/current attribute storage
- protected-mode handling
- color operation state
- kitty color replies
- status display
- mouse shape

Avoid:

- cursor positioning
- scrollback/screen/page mutations
- PTY response plumbing except what color/query actions strictly require

### P6.B Cursor / tabstops / modes

Own:

- cursor state and saved cursor
- tab stop state
- terminal mode store and reports
- scrolling-region bounds
- kitty keyboard mode stack
- mouse reporting flags / modify-other-keys flags
- screen-switch / DECCOLM mode toggles

Avoid:

- cell contents and line-editing behavior
- color/style storage

### P6.C Screen / page / hyperlink state

Own:

- printable cell writes
- erase/insert/delete/scroll behavior
- hyperlink spans
- title storage
- semantic prompt state
- screen/page backing storage needed by the editing and scrolling actions

Avoid:

- PTY response encoding
- host-side clipboard/notification behavior

### P6.1 Terminal application bridge

Integrate the stream handler after `P6.A`, `P6.B`, and `P6.C` exist:

- connect `StreamAction` handling to the terminal model
- add effect callback plumbing
- keep APC local to the handler
- continue ignoring DCS at terminal-mutating level, matching upstream

## Dependency risks to watch

- `setMode` is a cross-cutting hotspot: it touches cursor state, scrolling
  region, screen switching, DECCOLM, and mouse/keyboard flags
- color operations and kitty color replies need terminal color storage plus
  response encoding paths
- size reports, mode reports, and device reports all depend on `write_pty`
  existing before the bridge is considered complete
- APC handling depends on terminal allocation access (`gpa`) but not on the
  broader terminal mutation surface

## Result

- `P6.0` is complete
- the next planned implementation lanes are `P6.A`, `P6.B`, and `P6.C`
