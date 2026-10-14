///|
/// A single loaded glyph positioned in a future atlas.
pub(all) struct Glyph {
  width : UInt32
  height : UInt32
  offset_x : Int32
  offset_y : Int32
  atlas_x : UInt32
  atlas_y : UInt32
} derive(Eq, Debug)

///|
pub extend Glyph with Eq::{not_equal, equal}

///|
pub extend Glyph with @debug.Debug::{to_repr}
