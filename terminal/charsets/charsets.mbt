///|
pub(all) enum Slots {
  G0
  G1
  G2
  G3
} derive(Eq, Debug)

///|
pub(all) enum ActiveSlot {
  Gl
  Gr
} derive(Eq, Debug)

///|
pub(all) enum Charset {
  Utf8
  Ascii
  British
  DecSpecial
} derive(Eq, Debug)

///|
pub type CharsetTable = ReadOnlyArray[UInt16]

///|
pub fn table(set : Charset) -> CharsetTable {
  match set {
    British => british_table
    DecSpecial => dec_special_table
    Ascii => ascii_table
    Utf8 => abort("Utf8 does not use a mapping table")
  }
}

///|
pub extend Slots with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Slots with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Slots with @debug.Debug::{to_repr}

///|
pub extend ActiveSlot with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ActiveSlot with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ActiveSlot with @debug.Debug::{to_repr}

///|
pub extend Charset with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Charset with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Charset with @debug.Debug::{to_repr}
