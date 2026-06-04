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

`set_codepoint()` is always called with `grapheme=false`, so `content_tag`
is always `Codepoint`, never `CodepointGrapheme`. `has_grapheme()` is
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

Add `mut grapheme_extras : Array[UInt]?` to `PageCellState`. `None` when
`content_tag != CodepointGrapheme`; `Some(cps)` holds the additional combining
codepoints beyond the base `codepoint()` field.

Allocation is lazy — most cells are pure codepoints; the `Some` branch only
appears when a zero-width codepoint is received after a printable one.

### Combining rule

When the bridge's `print()` receives a zero-width codepoint (`width == 0`):

1. Find the preceding logical cell:
   - If `cursor.pending_wrap`: the cell is at `(cursor.y, cursor.x)` — the
     cursor has not yet advanced.
   - Otherwise: the cell is at `(cursor.y, cursor.x - 1)`.
   - If that cell is `SpacerTail`, step back one more to reach the `Wide` base.
2. If the preceding cell `has_text()`: call `cell.append_grapheme(cp)`.
   - `append_grapheme` sets `content_tag = CodepointGrapheme` and appends to
     `grapheme_extras`.
3. Mark the row dirty and set `PageRowState::grapheme = true`.
4. If there is no preceding cell (cursor at column 0, no pending_wrap), discard
   the codepoint — same as upstream.

### Public API addition

```
pub fn PageCellState::grapheme_codepoints(Self) -> Array[UInt]
```

Returns the additional combining codepoints when `has_grapheme()` is true.
Returns `[]` when `content_tag != CodepointGrapheme`. The returned array is
the internal storage (not a defensive copy) — callers must not mutate it.

## Files Changed

| File | Change |
|------|--------|
| `terminal/page_state.mbt` | Add `grapheme_extras` field; add `append_grapheme`, `grapheme_codepoints`, update `new`, `full_reset`, `set_codepoint` |
| `terminal/terminal_screen_state.mbt` | Update `copy_scrollback_cell` to copy `grapheme_extras` |
| `terminal/screen_grid_state.mbt` | Add `ScreenGridState::append_grapheme()` |
| `terminal/stream_terminal_bridge.mbt` | Route `width == 0` to `append_grapheme` instead of early-return |
| `terminal/pkg.generated.mbti` | Add `pub fn PageCellState::grapheme_codepoints(Self) -> Array[UInt]` |
| `terminal/page_state_test.mbt` | Extend codepoint-grapheme test; add append_grapheme round-trip test |

## Validation

```sh
moon -C terminal check
moon -C terminal test --filter 'grapheme'
moon -C terminal test
moon fmt --check
moon info
```
