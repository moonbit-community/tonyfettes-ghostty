// A font face: the real glyph-outline source. Wraps harfbuzz (a pure-MoonBit
// HarfBuzz port) to turn font bytes + a glyph id into a flattened outline, then
// rasterizes it into a coverage buffer via font/raster.
//
// This is the MoonBit analog of Ghostty's font/face/freetype.zig — except the
// rasterization is our own pure rasterizer, not FreeType. It is the producer
// that feeds font/glyph's render_glyph / GlyphCache real glyphs.
//
// Font bytes come from the caller (embedded or loaded), so this layer touches no
// filesystem and stays target-agnostic.

///|
/// A loaded font face plus its units-per-em (needed to scale font units to
/// pixels).
struct Face {
  font : @font.Font
  upem : Int
}

///|
/// Load a face from in-memory font bytes (`.ttf`/`.otf`).
pub fn Face::load(bytes : Bytes) -> Face raise {
  let hb_face = @hb_face.Face::from_bytes(bytes)
  let upem = read_units_per_em(hb_face)
  { font: @font.Font::new(hb_face), upem }
}

///|
/// Units-per-em, for callers that need the pixel scale (`px / upem`).
pub fn Face::upem(self : Face) -> Int {
  self.upem
}

///|
/// Read `unitsPerEm` from the `head` table (uint16 at byte offset 18).
/// `Face::get_upem` is only populated lazily by other calls, so read the table
/// directly for a reliable value up front.
fn read_units_per_em(face : @hb_face.Face) -> Int raise {
  let head = @common.Tag::from_chars('h', 'e', 'a', 'd')
  let blob = match face.reference_table(head) {
    Ok(b) => b
    Err(_) => fail("missing head table")
  }
  let hi = match blob.get(18) {
    Some(b) => b.to_int()
    None => fail("head table too short")
  }
  let lo = match blob.get(19) {
    Some(b) => b.to_int()
    None => fail("head table too short")
  }
  (hi << 8) | lo
}

///|
/// Glyph index for a Unicode codepoint via the font's cmap, or `None` if the
/// font has no glyph for it.
pub fn Face::glyph_index(self : Face, codepoint : UInt) -> UInt? raise {
  match self.font.glyph_for_codepoint(codepoint) {
    Ok(g) => g
    Err(_) => fail("cmap lookup failed for codepoint \{codepoint}")
  }
}

///|
/// Rasterize glyph `gid` into a `width` x `height` coverage buffer at `px` em
/// size. `origin_x` / `baseline_y` place the glyph's pen origin (on the
/// baseline) in canvas pixels. Font units are y-up; the canvas is y-down, hence
/// the y flip.
pub fn Face::rasterize(
  self : Face,
  gid : UInt,
  px : Int,
  width : Int,
  height : Int,
  origin_x : Double,
  baseline_y : Double,
  tolerance? : Double = 0.2,
) -> @raster.Coverage raise {
  let scale = px.to_double() / self.upem.to_double()
  let tx = fn(v : Double) -> Double { origin_x + v * scale }
  let ty = fn(v : Double) -> Double { baseline_y - v * scale }
  let pb = @raster.PathBuilder::new(tolerance~)
  let funcs : @draw.DrawFuncs[@raster.PathBuilder] = @draw.DrawFuncs::new()
  funcs.set_move_to(Some((pb, _st, x, y) => pb.move_to(tx(x), ty(y))))
  funcs.set_line_to(Some((pb, _st, x, y) => pb.line_to(tx(x), ty(y))))
  funcs.set_quadratic_to(
    Some((pb, _st, cx, cy, x, y) => {
      pb.quadratic_to(tx(cx), ty(cy), tx(x), ty(y))
    }),
  )
  funcs.set_cubic_to(
    Some((pb, _st, c1x, c1y, c2x, c2y, x, y) => {
      pb.cubic_to(tx(c1x), ty(c1y), tx(c2x), ty(c2y), tx(x), ty(y))
    }),
  )
  funcs.set_close_path(Some((pb, _st) => pb.close()))
  match self.font.draw_glyph_or_fail(gid, funcs, pb) {
    Err(_) => fail("draw failed for glyph \{gid}")
    Ok(_) => ()
  }
  @raster.render(pb.build(), width, height, NonZero)
}
