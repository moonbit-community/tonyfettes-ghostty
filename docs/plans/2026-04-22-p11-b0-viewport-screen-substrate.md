# P11.B0 Viewport And Screen Substrate

## Goal

Land the `terminal.zig` substrate that `P11.A` deliberately deferred:
multi-screen storage, scrollback-backed viewport reads, pixel dimensions,
typed resize, and the row-identity groundwork needed before faithful grid refs
and richer typed host queries.

## Upstream files

- `upstream/ghostty/src/terminal/c/terminal.zig`

Focused upstream coverage in this slice:

- `resize`
- `scrollViewport`
- `activeScreen`
- `totalRows`
- `scrollbackRows`
- viewport-facing row/cell reads that now need scrollback awareness

## MoonBit target files

- `src/terminal/stream_terminal.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/terminal_screen_state.mbt`
- `src/terminal/stream_terminal_test.mbt`
- `src/terminal/stream_terminal_bridge_wbtest.mbt`
- `src/terminal/terminal_screen_state_wbtest.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p11-b0-viewport-screen-substrate.md`

## Dependency notes

- This slice still stays inside the existing single `src/terminal` package and
  extends the existing owner modules rather than mirroring `src/terminal/c`.
- It adds screen/storage substrate and row identity tracking, but it does not
  expose public grid-pin objects yet. That remains `P11.B`.
- It adds typed viewport controls and host-readable counts, which unblock
  `P11.C` without forcing a generic `get`/`set` API.

## Acceptance criteria

- `StreamTerminal` exposes:
  - `resize`
  - `scroll_viewport_top`
  - `scroll_viewport_bottom`
  - `scroll_viewport_delta`
  - `rows`
  - `columns`
  - `active_screen`
  - `total_rows`
  - `scrollback_rows`
  - `width_px`
  - `height_px`
- Alternate-screen mode changes (`47`, `1047`, `1049`) switch storage
  correctly, including cursor-copy behavior where upstream expects it.
- Scroll and viewport operations update row/cell snapshots through the new
  scrollback substrate.
- Page-pin groundwork exists internally as stable visible-row identifiers, but
  no premature public grid-ref API is introduced.
- No public mutable fields are introduced.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream_terminal.mbt`: covered through blackbox host-surface
  tests for resize, viewport movement, and scrollback accounting
- `src/terminal/terminal_screen_state.mbt`: fully covered by
  `terminal_screen_state_wbtest.mbt`
- `src/terminal/stream_terminal_bridge.mbt`: the new screen-switch,
  scrollback, and resize paths are covered by blackbox and whitebox tests;
  one remaining uncovered branch is the `None => return` fallback in
  `cursor_left`, which is currently invariant-only because cursor positioning
  is clamped before that row lookup
- `src/terminal/stream_terminal_bridge_wbtest.mbt` and
  `src/terminal/stream_terminal_test.mbt`: added specifically to close the new
  bridge/state behavior

## Commit scope

- `feat(c-terminal)`

## Review findings

- The public API expansion is deliberate and typed: `TerminalScreen` plus the
  new `StreamTerminal` resize/viewport/query methods. No internal storage or
  row-pin helper types leak into `pkg.generated.mbti`.
- `screen_row_snapshot` and `screen_cell_snapshot` now read through viewport
  state instead of directly indexing the active grid, which matches the host
  wrapper role better than inventing duplicate viewport APIs later.
- The new row-identity tracking is intentionally internal for now. Upstream
  `grid_ref.zig` needs it, but exposing it before `P11.B` would freeze the
  wrong shape.

## Audit/result notes

- `P11.B0` gives `StreamTerminal` a real multi-screen and scrollback substrate.
  `P11.B` can now build faithful grid-pin helpers on top of stable row IDs
  instead of ad hoc indices.
- `resize` currently resets both screen storages to the new dimensions rather
  than preserving or reflowing content. That is acceptable for this substrate
  slice because the new public API only requires typed resize/result behavior,
  size reporting, and host-visible dimension/query parity. Content-preserving
  resize remains follow-up work if upstream parity demands it later.
- The remaining touched-file coverage exception is documented and justified; it
  should not be used as precedent for leaving ordinary branches uncovered.
