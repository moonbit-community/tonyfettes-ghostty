///|
struct TerminalScrollbar {
  total : UInt32
  offset : UInt32
  len : UInt32
} derive(Eq, Debug)

///|
pub fn TerminalScrollbar::new(
  total : UInt32,
  offset : UInt32,
  len : UInt32,
) -> TerminalScrollbar {
  { total, offset, len, }
}

///|
pub fn TerminalScrollbar::total(self : TerminalScrollbar) -> UInt32 {
  self.total
}

///|
pub fn TerminalScrollbar::offset(self : TerminalScrollbar) -> UInt32 {
  self.offset
}

///|
pub fn TerminalScrollbar::len(self : TerminalScrollbar) -> UInt32 {
  self.len
}

///|
pub extend TerminalScrollbar with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend TerminalScrollbar with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend TerminalScrollbar with @debug.Debug::{to_repr}
