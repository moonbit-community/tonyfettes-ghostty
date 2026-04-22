# P11.A Host Control Surface

## Goal

Extend the existing `StreamTerminal` owner with the non-viewport host-control
surface from upstream `src/terminal/c/terminal.zig`: runtime callback
replacement and clearing, typed mode control, reset, and host metadata
setters.

## Upstream files

- `upstream/ghostty/src/terminal/c/terminal.zig`

Focused upstream coverage in this slice:

- `new/free`
- `vt_write`
- callback setter/clear tests
- `mode_get and mode_set`
- `set and get title`
- `set and get pwd`

## MoonBit target files

- `src/terminal/stream_terminal.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/stream_terminal_parity_test.mbt`
- `src/terminal/terminal_metadata_state.mbt`
- `src/terminal/terminal_metadata_state_test.mbt`
- `src/terminal/modes.mbt`
- `src/terminal/modes_test.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p11-a-host-control-surface.md`

## Dependency notes

- This slice stays inside the existing single-screen model.
- It deliberately does not attempt `resize`, `scroll_viewport`, `active_screen`,
  `total_rows`, `scrollback_rows`, or pin-backed grid refs. Those now belong to
  `P11.B0` and later tasks because the current model lacks page-list and
  scrollback substrate.
- Callback replacement/clearing is safe to land now because the bridge already
  owns all host effects behind one object.

## Acceptance criteria

- `StreamTerminal` supports runtime replacement and clearing for:
  - `write_pty`
  - `bell`
  - `color_scheme`
  - `device_attributes`
  - `enquiry`
  - `size`
  - `title_changed`
  - `xtversion`
- `StreamTerminal` exposes typed host controls for:
  - `reset`
  - `mode_get`
  - `mode_set`
  - `set_title`
  - `pwd`
  - `set_pwd`
- Blackbox tests cover callback replacement/clearing on the same terminal
  object and reset/mode/metadata behavior.
- No public mutable fields are introduced.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream_terminal.mbt`: covered through blackbox parity tests
- `src/terminal/stream_terminal_bridge.mbt`: touched callback/control paths are
  covered through public `StreamTerminal` tests; the pre-existing invariant-only
  uncovered branches outside this slice remain documented from Phase 6 and 7
- `src/terminal/terminal_metadata_state.mbt`: fully covered by direct tests and
  host-surface parity tests
- `src/terminal/modes.mbt`: the new reset aliasing fix is covered by a direct
  regression test

## Commit scope

- `feat(c-terminal)`

## Review findings

- The new reset host test exposed a pre-existing aliasing bug in `ModeState`:
  `values` and `default` shared the same packed storage, so resetting after a
  mutation could restore a mutated "default". This slice fixes that directly in
  `src/terminal/modes.mbt` and adds a regression test.
- `userdata` remains intentionally absent from the MoonBit surface. Closures
  carry captured state directly, so an explicit userdata slot would be ABI-only
  baggage.
- The public API expansion is deliberate and typed. There is no generic
  `set(option, value)` escape hatch.

## Audit/result notes

- `StreamTerminal` now has a credible host-control surface for the parts of
  `terminal.zig` that do not depend on scrollback or page pins.
- `pwd` now lives in the metadata state beside `title`, which matches the host
  wrapper role better than inventing a separate ad hoc holder.
- `P11.B0` is the next real dependency gate. The remaining terminal host work
  needs new substrate, not more callback plumbing.
