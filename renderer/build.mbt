// Build per-cell instance data from a terminal RenderState snapshot.

///|
/// Walk the render snapshot row by row and produce the frame's instance data:
/// a dense background-color grid and a sparse list of glyph quads.
///
/// `glyph_of` resolves a codepoint to its placed glyph in the atlas, or `None`
/// when the cell should draw no glyph (no coverage, or the font lacks it); it
/// may raise if rasterizing on a cache miss fails.
///
/// Background is recorded for every cell. A foreground glyph is emitted only for
/// a non-blank cell whose resolved glyph has a non-empty bitmap — blanks and
/// spaces contribute background only, exactly as the GPU renderer expects.
pub fn build(
  state : @terminal.RenderState,
  glyph_of : (UInt) -> @glyph.Glyph? raise,
) -> Contents raise {
  let cols = state.columns().to_int()
  let rows = state.rows().to_int()
  let default_fg = Rgba::from_rgb(state.foreground_color())
  let default_bg = Rgba::from_rgb(state.background_color())
  let bg = Array::make(rows * cols, default_bg)
  let text : Array[CellText] = []
  let it = state.row_iterator()
  while it.next() {
    let y = match it.y() {
      Some(v) => v.to_int()
      None => continue
    }
    let cells = match it.cells() {
      Some(c) => c
      None => continue
    }
    while cells.next() {
      let x = match cells.x() {
        Some(v) => v.to_int()
        None => continue
      }
      let cell = match cells.cell() {
        Some(c) => c
        None => continue
      }
      guard x >= 0 && x < cols && y >= 0 && y < rows else { continue }

      // Background: every cell contributes one, falling back to the default.
      bg[y * cols + x] = match cells.background_color() {
        Some(c) => Rgba::from_rgb(c)
        None => default_bg
      }

      // Foreground: skip empty cells and spaces — they draw no glyph.
      let cp = cell.codepoint()
      if cp == 0 || cp == 0x20 {
        continue
      }
      if glyph_of(cp) is Some(g) && g.width > 0 && g.height > 0 {
        let fg = match cells.foreground_color() {
          Some(c) => Rgba::from_rgb(c)
          None => default_fg
        }
        text.push({
          grid_col: x,
          grid_row: y,
          glyph_x: g.atlas_x,
          glyph_y: g.atlas_y,
          glyph_w: g.width,
          glyph_h: g.height,
          bearing_x: g.offset_x,
          bearing_y: g.offset_y,
          color: fg,
          atlas: Grayscale,
        })
      }
    }
  }
  { cols, rows, text, bg }
}
