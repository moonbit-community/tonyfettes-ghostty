# P8.0 `src/terminal/c` Surface Inventory

## Goal

Inventory the full upstream `src/terminal/c` wrapper surface, assign every file
to a MoonBit target module and test location, and lock the dependency clusters
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

## MoonBit target files

All translated `src/terminal/c` wrappers stay in the existing
`src/terminal` package. The file naming rule is:

- implementation: `src/terminal/c_<name>.mbt`
- blackbox tests: `src/terminal/c_<name>_test.mbt`
- whitebox tests only when internal wrapper state needs package-private access:
  `src/terminal/c_<name>_wbtest.mbt`

Planned file map:

| upstream | MoonBit target | test target | phase |
|---|---|---|---|
| `allocator.zig` | `src/terminal/c_allocator.mbt` | `src/terminal/c_allocator_test.mbt` | `P9.A` |
| `build_info.zig` | `src/terminal/c_build_info.mbt` | `src/terminal/c_build_info_test.mbt` | `P9.A` |
| `result.zig` | `src/terminal/c_result.mbt` | `src/terminal/c_result_test.mbt` | `P9.A` |
| `color.zig` | `src/terminal/c_color.mbt` | `src/terminal/c_color_test.mbt` | `P9.B` |
| `focus.zig` | `src/terminal/c_focus.mbt` | `src/terminal/c_focus_test.mbt` | `P9.B` |
| `modes.zig` | `src/terminal/c_modes.mbt` | `src/terminal/c_modes_test.mbt` | `P9.B` |
| `paste.zig` | `src/terminal/c_paste.mbt` | `src/terminal/c_paste_test.mbt` | `P9.B` |
| `size_report.zig` | `src/terminal/c_size_report.mbt` | `src/terminal/c_size_report_test.mbt` | `P9.B` |
| `style.zig` | `src/terminal/c_style.mbt` | `src/terminal/c_style_test.mbt` | `P9.B` |
| `selection.zig` | `src/terminal/c_selection.mbt` | `src/terminal/c_selection_test.mbt` | `P9.C` |
| `row.zig` | `src/terminal/c_row.mbt` | `src/terminal/c_row_test.mbt` | `P9.C` |
| `cell.zig` | `src/terminal/c_cell.mbt` | `src/terminal/c_cell_test.mbt` | `P9.C` |
| `osc.zig` | `src/terminal/c_osc.mbt` | `src/terminal/c_osc_test.mbt` | `P10.A` |
| `sgr.zig` | `src/terminal/c_sgr.mbt` | `src/terminal/c_sgr_test.mbt` | `P10.B` |
| `terminal.zig` | `src/terminal/c_terminal.mbt` | `src/terminal/c_terminal_test.mbt` | `P11.A`, `P11.C` |
| `grid_ref.zig` | `src/terminal/c_grid_ref.mbt` | `src/terminal/c_grid_ref_test.mbt` | `P11.B` |
| `key_event.zig` | `src/terminal/c_key_event.mbt` | `src/terminal/c_key_event_test.mbt` | `P12.A` |
| `mouse_event.zig` | `src/terminal/c_mouse_event.mbt` | `src/terminal/c_mouse_event_test.mbt` | `P12.A` |
| `key_encode.zig` | `src/terminal/c_key_encode.mbt` | `src/terminal/c_key_encode_test.mbt` | `P12.B` |
| `mouse_encode.zig` | `src/terminal/c_mouse_encode.mbt` | `src/terminal/c_mouse_encode_test.mbt` | `P12.B` |
| `render.zig` | `src/terminal/c_render.mbt` | `src/terminal/c_render_test.mbt` | `P13.A` |
| `formatter.zig` | `src/terminal/c_formatter.mbt` | `src/terminal/c_formatter_test.mbt` | `P13.B` |
| `kitty_graphics.zig` | `src/terminal/c_kitty_graphics.mbt` | `src/terminal/c_kitty_graphics_test.mbt` | `P13.C` |
| `sys.zig` | `src/terminal/c_sys.mbt` | `src/terminal/c_sys_test.mbt` | `P14.A` |
| `types.zig` | `src/terminal/c_types.mbt` | `src/terminal/c_types_test.mbt` | `P14.B` |
| `main.zig` | `src/terminal/c_main.mbt` | `src/terminal/c_main_test.mbt` | `P14.C` |

## Dependency notes

The wrapper surface falls into seven dependency clusters.

### Cluster 1: Stateless foundation

Files:

- `result.zig`
- `allocator.zig`
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
- `types.zig` and `main.zig` are aggregate layers and should stay last. Trying
  to land them early would either freeze unstable names or force churn across
  every later wrapper task.
- `kitty_graphics.zig` should stay isolated as the last task inside the render
  cluster because it closes both its own wrapper and the remaining graphics
  fields in `terminal.zig`.

## Audit/result notes

- No new package boundary is introduced for the `src/terminal/c` translation.
  The existing single `src/terminal` package remains the owner of the full
  terminal surface, and the `c_*.mbt` prefix is the only new naming rule.
- The follow-on phases now have a concrete denominator: 26 upstream wrapper
  files, mapped one-by-one, with `types.zig` and `main.zig` explicitly treated
  as aggregate-closeout work rather than normal leaf wrappers.
