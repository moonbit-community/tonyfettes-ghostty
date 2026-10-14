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
pub extend Glyph with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Glyph with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Glyph with @debug.Debug::{to_repr}
