///|
struct TerminalScrollbar {
  total : UInt
  offset : UInt
  len : UInt
} derive(Eq, Debug)

///|
pub fn TerminalScrollbar::new(
  total : UInt,
  offset : UInt,
  len : UInt,
) -> TerminalScrollbar {
  { total, offset, len }
}

///|
pub fn TerminalScrollbar::total(self : TerminalScrollbar) -> UInt {
  self.total
}

///|
pub fn TerminalScrollbar::offset(self : TerminalScrollbar) -> UInt {
  self.offset
}

///|
pub fn TerminalScrollbar::len(self : TerminalScrollbar) -> UInt {
  self.len
}
