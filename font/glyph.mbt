///|
/// A single loaded glyph positioned in a future atlas.
pub(all) struct Glyph {
  width : UInt
  height : UInt
  offset_x : Int
  offset_y : Int
  atlas_x : UInt
  atlas_y : UInt
} derive(Eq, Debug)
