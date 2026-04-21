# P6.1 Stream-To-Terminal Bridge Roadmap

## Goal

Break `stream_terminal.zig` into green bridge slices that can land against the
 translated MoonBit state in dependency order, instead of waiting for the full
 terminal model to exist first.

## Upstream file

- `upstream/ghostty/src/terminal/stream_terminal.zig`

## Slice strategy

### P6.1.A Phase-6A-only state bridge

Status:

- done
- implementation audit:
  [2026-04-20-p6-1-a-phase6a-bridge.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-20-p6-1-a-phase6a-bridge.md)

Depends on:

- `P6.A1`
- `P6.A2`
- `P6.A3`

Scope:

- protected-mode actions
- active-status-display actions
- mouse-shape actions
- color-operation mutation actions

Why first:

- these actions already have translated state carriers
- they let us exercise the bridge shape before cursor and screen logic arrive

### P6.1.B Cursor, mode, and tab bridge

Status:

- done
- implementation audit:
  [2026-04-21-p6-1-b-cursor-mode-tab-bridge.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-1-b-cursor-mode-tab-bridge.md)

Depends on:

- `P6.B`

Scope:

- cursor movement and positioning that are representable with the translated
  cursor, mode, charset, input, and tabstop carriers
- cursor-style updates
- tab set/clear/movement
- margins and scroll-region metadata
- mode toggles and kitty-keyboard metadata

Deferred note:

- reverse-wrap-specific `cursorLeft` behavior depends on screen row soft-wrap
  state, so that branch stays with `P6.1.C` when the screen/page model lands

### P6.1.C Screen mutation bridge

Status:

- done
- implementation audit:
  [2026-04-21-p6-1-c-screen-mutation-bridge.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-1-c-screen-mutation-bridge.md)

Depends on:

- `P6.C`

Scope:

- print and repeat-print
- erase, insert, delete, and scroll mutations
- hyperlink and semantic-prompt state application
- DECALN and full reset integration

Delivered note:

- the bridge now applies printable text, line-motion mutations, erase and
  scroll mutations, semantic prompt state, hyperlink state, kitty color
  mutation commands, DECALN, and full reset against the translated terminal
  model
- a small coverage residue remains in invariant-only internal branches plus the
  pre-existing `stream.mbt:222` parser branch; those findings are recorded in
  the slice audit instead of being carried as open bugs

### P6.1.D Query and side-effect bridge

Status:

- done
- implementation audit:
  [2026-04-21-p6-1-d-query-and-side-effect-bridge.md](/Users/haoxiang/Workspace/moonbit/feihaoxiang/ghostty/docs/plans/2026-04-21-p6-1-d-query-and-side-effect-bridge.md)

Depends on:

- `P6.1.A`
- `P6.1.B`
- `P6.1.C`

Scope:

- bell, title, clipboard, and notification effects
- device attributes and device status responses
- enquiry, XTWINOPS size reports, and XTVERSION
- APC/DCS effect paths that remain intentionally no-op for terminal state

Delivered note:

- the bridge now routes host-visible effects through an explicit effects record
  so PTY writes, bell delivery, title change notifications, and host queries
  stay outside the terminal state model
- device attributes, device status, mode reports, ENQ, XTWINOPS, XTVERSION,
  window title mutation, and kitty-keyboard query actions are all handled
  directly by the translated bridge
- clipboard, notification, APC, and DCS pass-through actions are handled as
  intentional no-op terminal mutations, matching the upstream split between
  terminal state and host-side side effects

## Current mapping notes

- `setProtectedMode`, `status_display`, `mouse_shape`, and `colors` are the
  only direct `stream_terminal.zig` mutations whose state is already translated
- the bridge must preserve the upstream split between terminal-owned state
  (`status_display`, `mouse_shape`, color wrappers) and screen-owned state
  (`protected_mode`, cursor protection, style)
- query/effect handling should stay callback-based so we can keep the terminal
  model pure where upstream just emits PTY responses or host-side effects

## Commit guidance

- commit each bridge slice independently with its validation and audit in the
  same commit
- do not start `P6.1.B` or `P6.1.C` by inventing placeholder terminal
  structures for missing `P6.B` or `P6.C` dependencies
