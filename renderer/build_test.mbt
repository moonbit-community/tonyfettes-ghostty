// Builder tests. They drive the whole stack: a real terminal's text -> harfbuzz
// outline -> raster -> atlas/cache -> instance data. Glyph and Rgba are
// read-only across packages, so the builder's output is checked by reading
// fields rather than reconstructing expected values.
//
// All test text uses glyphs present in the embedded subset font: A a e g o.

///|
/// A render state holding `text` typed into a fresh `cols` x `rows` terminal.
fn render_state_of(
  text : Bytes,
  cols : Int,
  rows : Int,
) -> @terminal.RenderState {
  let t = @terminal.StreamTerminal::new()
  t.resize(cols.to_uint16(), rows.to_uint16(), 8U, 16U) |> ignore
  t.next_slice(text)
  let state = @terminal.RenderState::new()
  state.update(t)
  state
}

///|
/// A glyph resolver backed by the embedded font: rasterize each codepoint via
/// harfbuzz + raster and place it in the cache, memoized.
fn real_resolver(
  face : @face.Face,
  cache : @glyph.GlyphCache,
  px : Int,
) -> (UInt) -> @glyph.Glyph? raise {
  cp => {
    match face.glyph_index(cp) {
      Some(gid) => {
        let cov = face.rasterize(gid, px, 32, 32, 2.0, 26.0)
        Some(cache.render({ font: 0, glyph: cp.reinterpret_as_int(), px }, cov))
      }
      None => None
    }
  }
}

///|
test "one glyph per inked cell; background dense over the whole grid" {
  let state = render_state_of(b"ao", 4, 1)
  let face = @face.Face::load(@face.inconsolata_subset)
  let cache = @glyph.GlyphCache::new(256, Grayscale)
  let contents = build(state, real_resolver(face, cache, 24))
  assert_eq(contents.cols(), 4)
  assert_eq(contents.rows(), 1)
  // 'a' and 'o' produce glyphs; the two trailing blanks do not.
  assert_eq(contents.text().length(), 2)
  let a = contents.text()[0]
  let o = contents.text()[1]
  assert_eq(a.grid_col, 0)
  assert_eq(a.grid_row, 0)
  assert_eq(o.grid_col, 1)
  // Real bitmaps: non-empty, within the rasterization canvas.
  assert_true(a.glyph_w > 0 && a.glyph_h > 0)
  assert_true(a.glyph_w <= 32 && a.glyph_h <= 32)
  // Packed at distinct atlas positions, and the cache holds exactly the two.
  assert_true(a.glyph_x != o.glyph_x || a.glyph_y != o.glyph_y)
  assert_eq(cache.count(), 2)
  // Background is dense: one color per cell.
  assert_eq(contents.bg().length(), 4)
}

///|
test "spaces and empty cells contribute no glyph" {
  let state = render_state_of(b"a o", 3, 1)
  let face = @face.Face::load(@face.inconsolata_subset)
  let cache = @glyph.GlyphCache::new(256, Grayscale)
  let contents = build(state, real_resolver(face, cache, 24))
  // 'a' and 'o' only; the space between them is skipped.
  assert_eq(contents.text().length(), 2)
  assert_eq(contents.text()[0].grid_col, 0)
  assert_eq(contents.text()[1].grid_col, 2)
}

///|
test "a resolver returning None draws no foreground" {
  let state = render_state_of(b"ao", 4, 1)
  let contents = build(state, _cp => None)
  assert_eq(contents.text().length(), 0)
  // Background is still produced for the whole grid.
  assert_eq(contents.bg().length(), 4)
}

///|
test "SGR inverse swaps a cell's foreground and background" {
  // ESC[7m turns on inverse video; the cell still relies on the terminal's
  // default fg (white) / bg (black), so the swap must surface as black glyph on
  // a white cell — proving inverse is resolved against the defaults, not dropped.
  let state = render_state_of(b"\x1B[7ma", 2, 1)
  let face = @face.Face::load(@face.inconsolata_subset)
  let cache = @glyph.GlyphCache::new(256, Grayscale)
  let contents = build(state, real_resolver(face, cache, 24))
  let fg = contents.text()[0].color
  assert_eq(fg.r, 0)
  assert_eq(fg.g, 0)
  assert_eq(fg.b, 0)
  let bg = contents.bg_at(0, 0)
  assert_eq(bg.r, 255)
  assert_eq(bg.g, 255)
  assert_eq(bg.b, 255)
}

///|
test "SGR invisible cells draw background but emit no glyph" {
  // ESC[8m conceals the text (password fields, etc.): 'a' would normally ink a
  // glyph, but invisible cells must contribute background only — matching xterm
  // and Ghostty's renderer, which skips the foreground for invisible cells.
  let state = render_state_of(b"\x1B[8ma", 2, 1)
  let face = @face.Face::load(@face.inconsolata_subset)
  let cache = @glyph.GlyphCache::new(256, Grayscale)
  let contents = build(state, real_resolver(face, cache, 24))
  // No foreground glyph for the concealed 'a'.
  assert_eq(contents.text().length(), 0)
  // Background is still produced densely over the grid.
  assert_eq(contents.bg().length(), 2)
}

///|
test "default foreground/background fill the instance colors" {
  let state = render_state_of(b"a", 2, 1)
  let face = @face.Face::load(@face.inconsolata_subset)
  let cache = @glyph.GlyphCache::new(256, Grayscale)
  let contents = build(state, real_resolver(face, cache, 24))
  // Default terminal colors: white foreground on black background.
  let fg = contents.text()[0].color
  assert_eq(fg.r, 255)
  assert_eq(fg.g, 255)
  assert_eq(fg.b, 255)
  assert_eq(fg.a, 255)
  let bg = contents.bg_at(0, 0)
  assert_eq(bg.r, 0)
  assert_eq(bg.g, 0)
  assert_eq(bg.b, 0)
  assert_eq(bg.a, 255)
}
