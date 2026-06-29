// The CPU side of the cell renderer: turn a terminal RenderState snapshot into
// the flat per-cell instance data a GPU draws with one instanced draw call.
//
// This is the MoonBit analog of Ghostty's renderer/cell.zig (the `Contents`
// container + `CellText`/`CellBg` instances). It does NOT touch the GPU — it
// only produces arrays. The screen→data mapping lives here so it can be tested
// offline; uploading those arrays to a shader is a separate, thin binding layer.

///|
/// 8-bit RGBA, the form a color takes in the GPU instance buffer.
pub struct Rgba {
  r : Byte
  g : Byte
  b : Byte
  a : Byte
} derive(Eq, Debug)

///|
/// A terminal RGB color as opaque RGBA (alpha = 255).
pub fn Rgba::from_rgb(c : @color.RGB) -> Rgba {
  { r: c.r(), g: c.g(), b: c.b(), a: 255 }
}

///|
/// Which atlas a glyph's bitmap lives in: grayscale (text) or color (emoji).
pub(all) enum AtlasKind {
  Grayscale
  Color
} derive(Eq, Debug)

///|
/// One instance of a textured glyph quad. `grid_col`/`grid_row` place it on the
/// terminal grid (the shader scales by the cell size); the `glyph_*` fields
/// locate and size its bitmap in the atlas; `bearing_*` offset the quad off the
/// cell origin; `color` is the foreground.
pub struct CellText {
  grid_col : Int
  grid_row : Int
  glyph_x : Int
  glyph_y : Int
  glyph_w : Int
  glyph_h : Int
  bearing_x : Int
  bearing_y : Int
  color : Rgba
  atlas : AtlasKind
} derive(Eq, Debug)

///|
/// The per-cell instance data for one frame: a dense background-color grid
/// (`rows * cols`, row-major) and a sparse list of glyph quads (one per inked
/// cell). Background is dense because every cell has one; foreground is sparse
/// because blanks contribute no glyph.
///
/// Opaque: read through the accessors below, which is how the GPU uploader
/// consumes a frame.
struct Contents {
  cols : Int
  rows : Int
  text : Array[CellText]
  bg : Array[Rgba]
}

///|
/// Grid width in cells.
pub fn Contents::cols(self : Contents) -> Int {
  self.cols
}

///|
/// Grid height in cells.
pub fn Contents::rows(self : Contents) -> Int {
  self.rows
}

///|
/// The sparse glyph-quad instances (one per inked cell).
pub fn Contents::text(self : Contents) -> Array[CellText] {
  self.text
}

///|
/// The dense background-color grid (`rows * cols`, row-major), as the GPU
/// uploads it.
pub fn Contents::bg(self : Contents) -> Array[Rgba] {
  self.bg
}

///|
/// The background color at `(col, row)` from the dense background grid.
pub fn Contents::bg_at(self : Contents, col : Int, row : Int) -> Rgba {
  self.bg[row * self.cols + col]
}
