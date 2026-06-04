# Grapheme Codepoint Storage and Exposure

## Goal

Fix the zero-width codepoint drop in the terminal bridge and expose a public
`PageCellState::grapheme_codepoints() -> Array[UInt]` API so renderers can
produce correct output for combining diacritics, emoji skin-tone sequences,
emoji ZWJ sequences, and variant selectors.

## Background

Audit source: `tonyfettes/ghostty@0.2.0` terminal package compared against
upstream `~/Workspace/ghostty/src/font/shaper/run.zig`.

### The bug

`StreamTerminalBridgeState::print()` calls `codepoint_width(cp)` and returns
early when `width == 0`. All zero-width codepoints are silently discarded:

- Combining diacritics U+0300–U+036F (é, à, ñ, etc.)
- Emoji skin-tone modifiers U+1F3FB–U+1F3FF
- Zero-width joiner U+200D (ZWJ sequences: 👨‍👩‍👧, etc.)
- Variant selectors U+FE0E/U+FE0F (text vs emoji presentation)

`set_codepoint()` is always called with `grapheme=false`, so the cell content
is always a plain codepoint, never a grapheme cluster. `has_grapheme()` is
effectively dead code in v0.2.0.

Confirmed in the existing `rabbita_asciinema` example: `cell_text()` passes
`[cell.codepoint()]` unconditionally.

### Upstream reference

In upstream Ghostty Zig, `RenderState.Cell` has a parallel `grapheme:
[]const u21` field populated from the page grapheme side-table during
`RenderState.update()`. The `RunIterator` uses this field to produce correct
shaping input for HarfBuzz.

## Design

### Storage

Cell content is a single package-private `PageCellContent` enum on
`PageCellState` (replacing the former parallel `content_tag` + `codepoint` +
`palette_index` + `bg_rgb` fields). The grapheme combining codepoints live
inside the `CodepointGrapheme` variant:

```
enum PageCellContent {
  Codepoint(UInt)
  CodepointGrapheme(UInt, Array[UInt])   // base codepoint + combining extras
  BackgroundPalette(Byte)
  BackgroundRgb(@color.RGB)
}
```

This makes impossible states unrepresentable: switching a cell to a `Background`
variant structurally discards any grapheme payload, so combining marks can never
linger as stale data on a non-text cell.

Allocation is lazy — most cells are `Codepoint(_)`; the `CodepointGrapheme`
variant (and its `Array[UInt]`) only appears when a zero-width codepoint is
received after a printable one.

### Combining rule

When the bridge's `print()` receives a zero-width codepoint (`width <= 0`):

1. Find the preceding logical cell:
   - If `cursor.pending_wrap`: the cell is at `(cursor.y, cursor.x)` — the
     cursor has not yet advanced.
   - Otherwise: the cell is at `(cursor.y, cursor.x - 1)`.
   - If that cell is `SpacerTail`, step back one more to reach the `Wide` base.
2. If the preceding cell `has_text()`: call `cell.append_grapheme(cp)`.
   - `append_grapheme` upgrades `Codepoint(base)` to
     `CodepointGrapheme(base, [cp])`, or pushes onto the existing extras.
3. Mark the row dirty and set `PageRowState::grapheme = true`.
4. If there is no preceding cell (cursor at column 0, no pending_wrap), discard
   the codepoint — same as upstream.

This combining happens **regardless of DEC mode 2027 (`GraphemeCluster`)**.
Upstream Ghostty appends combining marks to the prior cell in both the legacy
(wcwidth) path and the 2027 grapheme-segmentation path; an early-return guarded
on 2027 would drop accents whenever an application enables the mode. (Full 2027
support would additionally cluster width>0 codepoints via Unicode grapheme
breaks — not yet implemented; tracked as a follow-up.)

### Formatted output

`formatter_write_cell_text` emits `cell.codepoint()` followed by every
`grapheme_codepoints()` entry, so copy/format (`Formatter`) and the VT
framebuffer (`RenderState::format_vt_framebuffer`) preserve combining marks.
The blank-cell predicates (`formatter_cell_is_blank` /
`formatter_history_cell_is_blank`) additionally exclude cells with grapheme data
so a space carrying combining marks (e.g. `" " + U+0301`) is treated as a real
grapheme rather than trimmable padding.

### Public API addition

```
pub fn PageCellState::grapheme_codepoints(Self) -> Array[UInt]
```

Returns the additional combining codepoints when `has_grapheme()` is true,
`[]` otherwise. The returned array is the cell's internal storage (not a
defensive copy), documented read-only — callers must not mutate it, and the
render hot path stays allocation-free. The `PageCellContent` enum and the
`content()` accessor are package-private; external callers use the existing
`codepoint()` / `palette_index()` / `background_rgb()` / `has_grapheme()` /
`grapheme_codepoints()` accessors, so the storage layout stays an
implementation detail.

## Files Changed

| File | Change |
|------|--------|
| `terminal/page_state.mbt` | Replace `content_tag`/`codepoint`/`palette_index`/`bg_rgb` flat fields with the `PageCellContent` enum; add `append_grapheme`, `grapheme_codepoints`, package-private `content()`; update `new`, `full_reset`, `set_codepoint`, `set_background_*` |
| `terminal/terminal_screen_state.mbt` | Update `copy_scrollback_cell` to deep-copy the `CodepointGrapheme` extras array |
| `terminal/screen_grid_state.mbt` | Add `ScreenGridState::append_grapheme()`; update `copy_page_cell` for the enum |
| `terminal/stream_terminal_bridge.mbt` | Route `width <= 0` to `append_grapheme` instead of early-return (no 2027 guard) |
| `terminal/formatter.mbt` | Emit `grapheme_codepoints()` after the base codepoint; exclude grapheme-bearing spaces from blank trimming |
| `terminal/render_state.mbt` | Match `PageCellContent` for background color resolution |
| `terminal/pkg.generated.mbti` | Add `pub fn PageCellState::grapheme_codepoints(Self) -> Array[UInt]`; `PageCellContent` appears only as an abstract type |
| `terminal/*_test.mbt` | Grapheme accumulation, mode-2027 combining, render-iterator visibility, formatter combining-mark + space-grapheme preservation |

## Validation

```sh
moon -C terminal check
moon -C terminal test --filter 'grapheme'
moon -C terminal test
moon fmt --check
moon info
```
