# P11.B Grid Ref Surface

## Goal

Translate the `src/terminal/c/grid_ref.zig` host surface into a MoonBit-aligned
opaque grid-ref value plus typed terminal-owned query helpers, while preserving
the upstream pin/point semantics closely enough to unblock the remaining
terminal host query work.

## Upstream files

- `upstream/ghostty/src/terminal/c/grid_ref.zig`
- `upstream/ghostty/src/terminal/c/terminal.zig`

Focused upstream coverage in this slice:

- `grid_ref`
- `point_from_grid_ref`
- cell/row/style/hyperlink/grapheme query helpers

## MoonBit target files

- `src/terminal/grid_ref.mbt`
- `src/terminal/stream_terminal.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/terminal_screen_state.mbt`
- `src/terminal/stream_terminal_grid_ref_test.mbt`
- `src/terminal/terminal_screen_state_wbtest.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p11-b-grid-ref-surface.md`

## Dependency notes

- This slice builds directly on the row-identity groundwork from `P11.B0`.
- `GridRef` stays opaque and immutable; the terminal remains the public owner
  of point resolution and live row/cell/style/hyperlink lookups.
- `point_from_grid_ref` only resolves through the current active screen, which
  matches the upstream `terminal.zig` behavior.

## Acceptance criteria

- `StreamTerminal` exposes:
  - `grid_ref`
  - `point_from_grid_ref`
  - `grid_ref_row`
  - `grid_ref_cell`
  - `grid_ref_style`
  - `grid_ref_graphemes`
  - `grid_ref_hyperlink_uri`
- `GridRef` is public but opaque. No public mutable fields are introduced.
- Point roundtrips for active, viewport, screen, and history-backed refs stay
  safe and match upstream no-value behavior rather than aborting.
- Row/cell/style/hyperlink/grapheme queries stay safe when refs become
  unresolvable in the current active coordinate space.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/grid_ref.mbt`: fully covered through blackbox terminal tests
- `src/terminal/stream_terminal.mbt`: new public grid-ref methods are covered
  through blackbox tests
- `src/terminal/stream_terminal_bridge.mbt`: the new grid-ref branches are
  covered; the only remaining uncovered line is the pre-existing invariant-only
  `cursor_left` fallback at `None => return`
- `src/terminal/terminal_screen_state.mbt`: fully covered after direct wbtests
  for row-id lookup, point conversion, and viewport/source mapping helpers

## Commit scope

- `feat(c-terminal)`

## Review findings

- The public API expansion is deliberate and small: one opaque `GridRef` type
  plus seven typed `StreamTerminal` methods. There is no C-shaped output-buffer
  or enum-keyed dispatch layer.
- `point_from_grid_ref` is intentionally terminal-owned and active-screen
  scoped, matching upstream `terminal.zig` rather than exposing page-list style
  traversal directly.
- Row/cell/style query helpers use the ref's screen storage so inactive-screen
  refs remain safe to query when the backing storage still exists.

## Audit/result notes

- `P11.B` closes the grid-pin/query half of Phase 11 and unblocks the typed
  terminal query lane in `P11.C`.
- The current translated screen model does not yet retain supplemental
  multi-codepoint grapheme payloads beyond the primary stored codepoint, so
  `grid_ref_graphemes` currently returns the stored codepoint sequence, which
  is at most one element in this translation stage. That limitation is real
  and should be revisited when full grapheme-storage parity becomes necessary.
- Safe no-value behavior on stale or inactive refs is now covered explicitly:
  out-of-bounds, inactive-screen point reconstruction, and trimmed/unmapped row
  cases all return `None` instead of aborting.
