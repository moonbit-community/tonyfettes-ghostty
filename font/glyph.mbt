///|
/// A single loaded glyph positioned in a future atlas.
struct Glyph {
  width : UInt
  height : UInt
  offset_x : Int
  offset_y : Int
  atlas_x : UInt
  atlas_y : UInt
} derive(Eq, Debug)

///|
pub fn Glyph::new(
  width : UInt,
  height : UInt,
  offset_x : Int,
  offset_y : Int,
  atlas_x : UInt,
  atlas_y : UInt,
) -> Glyph {
  { width, height, offset_x, offset_y, atlas_x, atlas_y }
}

///|
pub fn Glyph::width(self : Glyph) -> UInt {
  self.width
}

///|
pub fn Glyph::height(self : Glyph) -> UInt {
  self.height
}

///|
pub fn Glyph::offset_x(self : Glyph) -> Int {
  self.offset_x
}

///|
pub fn Glyph::offset_y(self : Glyph) -> Int {
  self.offset_y
}

///|
pub fn Glyph::atlas_x(self : Glyph) -> UInt {
  self.atlas_x
}

///|
pub fn Glyph::atlas_y(self : Glyph) -> UInt {
  self.atlas_y
}
