# P8.0 `src/terminal/c` Surface Inventory

## Goal

Inventory the full upstream `src/terminal/c` wrapper surface, assign every file
to a MoonBit owner surface and test location, and lock the dependency clusters
that determine the follow-on phases.

## Upstream files

- `upstream/ghostty/src/terminal/c/allocator.zig`
- `upstream/ghostty/src/terminal/c/build_info.zig`
- `upstream/ghostty/src/terminal/c/cell.zig`
- `upstream/ghostty/src/terminal/c/color.zig`
- `upstream/ghostty/src/terminal/c/focus.zig`
- `upstream/ghostty/src/terminal/c/formatter.zig`
- `upstream/ghostty/src/terminal/c/grid_ref.zig`
- `upstream/ghostty/src/terminal/c/key_encode.zig`
- `upstream/ghostty/src/terminal/c/key_event.zig`
- `upstream/ghostty/src/terminal/c/kitty_graphics.zig`
- `upstream/ghostty/src/terminal/c/main.zig`
- `upstream/ghostty/src/terminal/c/modes.zig`
- `upstream/ghostty/src/terminal/c/mouse_encode.zig`
- `upstream/ghostty/src/terminal/c/mouse_event.zig`
- `upstream/ghostty/src/terminal/c/osc.zig`
- `upstream/ghostty/src/terminal/c/paste.zig`
- `upstream/ghostty/src/terminal/c/render.zig`
- `upstream/ghostty/src/terminal/c/result.zig`
- `upstream/ghostty/src/terminal/c/row.zig`
- `upstream/ghostty/src/terminal/c/selection.zig`
- `upstream/ghostty/src/terminal/c/sgr.zig`
- `upstream/ghostty/src/terminal/c/size_report.zig`
- `upstream/ghostty/src/terminal/c/style.zig`
- `upstream/ghostty/src/terminal/c/sys.zig`
- `upstream/ghostty/src/terminal/c/terminal.zig`
- `upstream/ghostty/src/terminal/c/types.zig`

## MoonBit owner surfaces

All translated `src/terminal/c` wrappers stay in the existing
`src/terminal` package.

Planning rule:

- prefer existing owner modules when the C wrapper only projects behavior that
  already belongs there
- create new files only for coherent new MoonBit owner surfaces
- use test files near the chosen owner surface rather than forcing a mirrored
  `c_*.mbt` file layout

Planned file map:

| upstream | MoonBit owner surface | test target | phase |
|---|---|---|---|
| `allocator.zig` | no standalone module; absorb into MoonBit-owned return semantics | no standalone test file | `P8.A` policy |
| `build_info.zig` | new build-info surface in `src/terminal` | build-info surface tests | `P9.A` |
| `result.zig` | shared result surface in `src/terminal` | result surface tests | `P9.A` |
| `color.zig` | extend existing `color.mbt` owner module | color surface tests | `P9.B` |
| `focus.zig` | small focus helper surface in `src/terminal` | focus helper tests | `P9.B` |
| `modes.zig` | extend existing `modes.mbt` owner module | modes surface tests | `P9.B` |
| `paste.zig` | small paste helper surface in `src/terminal` | paste helper tests | `P9.B` |
| `size_report.zig` | extend existing `size_report.mbt` owner module | size-report surface tests | `P9.B` |
| `style.zig` | extend existing style owner modules | style surface tests | `P9.B` |
| `selection.zig` | selection view/helper surface | selection surface tests | `P9.C` |
| `row.zig` | page/row view helper surface | row view tests | `P9.C` |
| `cell.zig` | page/cell view helper surface | cell view tests | `P9.C` |
| `osc.zig` | extend existing `osc.mbt` with host-facing helper surface | OSC host-surface tests | `P10.A` |
| `sgr.zig` | extend existing `sgr.mbt` with host-facing helper surface | SGR host-surface tests | `P10.B` |
| `terminal.zig` | expand `stream_terminal.mbt` and adjacent terminal helpers | terminal host-surface tests | `P11.A`, `P11.C` |
| `grid_ref.zig` | grid pin/query helper surface | grid pin/query tests | `P11.B` |
| `key_event.zig` | input event owner surface | key-event tests | `P12.A` |
| `mouse_event.zig` | input event owner surface | mouse-event tests | `P12.A` |
| `key_encode.zig` | input encoder surface | key-encoder tests | `P12.B` |
| `mouse_encode.zig` | input encoder surface | mouse-encoder tests | `P12.B` |
| `render.zig` | render-state surface | render-state tests | `P13.A` |
| `formatter.zig` | formatter surface | formatter tests | `P13.B` |
| `kitty_graphics.zig` | kitty-graphics surface | kitty-graphics tests | `P13.C` |
| `sys.zig` | system callback/config surface | system surface tests | `P14.A` |
| `types.zig` | typed surface registry | surface-registry tests | `P14.B` |
| `main.zig` | absorbed into package-surface closeout; no standalone module required | package-surface smoke tests | `P14.C` |

## Dependency notes

The wrapper surface falls into seven dependency clusters.

### Cluster 1: Stateless foundation

Files:

- `result.zig`
- `build_info.zig`
- `color.zig`
- `style.zig`
- `modes.zig`
- `focus.zig`
- `size_report.zig`
- `paste.zig`

Characteristics:

- no persistent terminal object ownership
- mostly direct value conversion or encoding helpers
- establishes shared `Result`, data tags, and small wrapper types used
  downstream
- `allocator.zig` is intentionally excluded from this cluster as a standalone
  translation task; its only job is C-side buffer ownership for exported
  functions such as `format_alloc`

Phase mapping:

- `P9.A`
- `P9.B`

### Cluster 2: Row/cell/selection queries

Files:

- `selection.zig`
- `row.zig`
- `cell.zig`

Characteristics:

- depends on translated page/row/cell/style state
- feeds `grid_ref.zig`, `render.zig`, and `formatter.zig`
- still independent from the terminal host wrapper itself

Phase mapping:

- `P9.C`

### Cluster 3: Parser object wrappers

Files:

- `osc.zig`
- `sgr.zig`

Characteristics:

- wrap already translated parser subobjects as independent host-facing objects
- low dependency on the later terminal host surface

Phase mapping:

- `P10.A`
- `P10.B`

### Cluster 4: Terminal host object

Files:

- `terminal.zig`
- `grid_ref.zig`

Characteristics:

- first major stateful wrapper layer
- owns the persistent stream plus terminal state
- `grid_ref.zig` depends on `terminal.zig` and the row/cell/style helpers
- non-graphics terminal data and callback behavior should close before render
  or formatter wrappers start

Phase mapping:

- `P11.0`
- `P11.A`
- `P11.B`
- `P11.C`

### Cluster 5: Input events and encoders

Files:

- `key_event.zig`
- `mouse_event.zig`
- `key_encode.zig`
- `mouse_encode.zig`

Characteristics:

- event objects are low-risk wrappers
- encoders depend on event objects plus terminal-derived defaults
- independent of render/formatter wrappers once terminal host queries exist

Phase mapping:

- `P12.A`
- `P12.B`

### Cluster 6: Render, formatter, and kitty graphics

Files:

- `render.zig`
- `formatter.zig`
- `kitty_graphics.zig`

Characteristics:

- broadest runtime dependency footprint inside `src/terminal/c`
- `render.zig` depends on terminal state snapshots plus row/cell/style helpers
- `formatter.zig` depends on terminal/grid/selection behavior
- `kitty_graphics.zig` is deferred last inside this cluster because
  `terminal.zig` exposes graphics-dependent queries that should close with it

Phase mapping:

- `P13.0`
- `P13.A`
- `P13.B`
- `P13.C`

### Cluster 7: Runtime metadata and aggregate surface

Files:

- `sys.zig`
- `types.zig`
- `main.zig`

Characteristics:

- `sys.zig` is conceptually independent but belongs late because it configures
  runtime-level callbacks consumed by the full surface
- `types.zig` must wait until the wrapper type set is materially complete
- `main.zig` is only an aggregate/export surface and therefore must land last

Phase mapping:

- `P14.A`
- `P14.B`
- `P14.C`

## Cross-package dependency findings

These are the notable non-`src/terminal/c` dependencies that affect phase
ordering or later subplans:

- `terminal.zig`
  - `Terminal.zig`
  - `stream_terminal.zig`
  - `PageList.zig`
  - `ScreenSet.zig`
  - `point.zig`
  - `size.zig`
  - `device_attributes.zig`
  - `device_status.zig`
  - `color.zig`
  - `kitty/key.zig`
  - `kitty_graphics.zig`
- `grid_ref.zig`
  - `page.zig`
  - `PageList.zig`
  - `point.zig`
  - `size.zig`
  - `style.zig`
  - `terminal.zig`
  - `row.zig`
  - `cell.zig`
- `render.zig`
  - `render.zig`
  - `cursor.zig`
  - `page.zig`
  - `terminal.zig`
  - `row.zig`
  - `style.zig`
- `formatter.zig`
  - `formatter.zig`
  - `Terminal.zig`
  - `terminal.zig`
  - `grid_ref.zig`
  - `selection.zig`
- `key_encode.zig`
  - `../../input/key_encode.zig`
  - `../../input/config.zig`
  - `../../terminal/kitty/key.zig`
  - `terminal.zig`
  - `key_event.zig`
- `mouse_encode.zig`
  - `../../input/mouse_encode.zig`
  - `../../renderer/size.zig`
  - `../../input/key.zig`
  - `terminal.zig`
  - `mouse_event.zig`
- `key_event.zig`
  - `../../input/key.zig`
- `mouse_event.zig`
  - `../../input/key.zig`
  - `../../input/mouse.zig`
  - `../../input/mouse_encode.zig`
- `kitty_graphics.zig`
  - `../kitty/graphics_storage.zig`
  - `../kitty/graphics_command.zig`
  - `../kitty/graphics_image.zig`
  - `terminal.zig`
  - `grid_ref.zig`
  - `selection.zig`
  - build option gating via `terminal_options`
- `sys.zig`
  - `../sys.zig`
  - runtime callback registry semantics
- `types.zig`
  - nearly every wrapper type declared in phases `P9` through `P13`
- `main.zig`
  - every wrapper module

## Acceptance criteria

- Every upstream file under `src/terminal/c` is assigned to:
  - one MoonBit implementation file
  - one test file
  - one owning phase/lane
- Cross-package dependencies that constrain ordering are recorded.
- The plan for `Phase 9` onward is mechanically derivable from this document
  rather than implied from memory.

## Validation

- doc review only

## Commit scope

- `docs`

## Review findings

- The current parser-stack translation already covers the hardest semantic
  substrate for `terminal.zig`, `osc.zig`, and `sgr.zig`; the remaining work is
  mostly wrapper breadth, state-query surface, and renderer/input adapter
  breadth.
- `allocator.zig` should not consume a standalone implementation phase in this
  pure-MoonBit plan. It is a C caller ownership helper, not a terminal
  behavior layer.
- `types.zig` and `main.zig` are aggregate layers and should stay last. Trying
  to land them early would either freeze unstable names or force churn across
  every later wrapper task.
- `kitty_graphics.zig` should stay isolated as the last task inside the render
  cluster because it closes both its own wrapper and the remaining graphics
  fields in `terminal.zig`.

## Audit/result notes

- No new package boundary is introduced for the `src/terminal/c` translation.
  The existing single `src/terminal` package remains the owner of the full
  terminal surface.
- The inventory now maps upstream wrappers to MoonBit owner surfaces, not to a
  mandatory one-file-per-wrapper mirror.
- `allocator.zig` remains in the upstream inventory but is treated as an
  intentionally absorbed helper: MoonBit-owned return values replace the
  exported C allocation/free protocol, so there is no planned `c_allocator`
  module.
- The follow-on phases now have a concrete denominator: 26 upstream wrapper
  files, with owner surfaces assigned one-by-one, one intentionally absorbed
  C-only helper, and with `types.zig` and `main.zig` explicitly treated as
  closeout work rather than normal leaf wrappers.
