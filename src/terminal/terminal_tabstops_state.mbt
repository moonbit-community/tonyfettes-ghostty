///|
const UnitBits : Int = 8

///|
const DefaultTabstopInterval : CellCountInt = 8

///|
struct TerminalTabstopsState {
  cols : Int
  stops : Array[Byte]
} derive(Eq, Debug)

///|
pub fn TerminalTabstopsState::new(cols : CellCountInt) -> TerminalTabstopsState {
  let cols_int = cols.to_int()
  let state = { cols: cols_int, stops: Array::make(entry_count(cols_int), 0) }
  state.reset(DefaultTabstopInterval)
  state
}

///|
pub fn TerminalTabstopsState::get(
  self : TerminalTabstopsState,
  col : CellCountInt,
) -> Bool {
  let col_int = col.to_int()
  guard self.in_bounds(col_int) else { return false }

  let i = entry(col_int)
  let idx = index(col_int)
  let mask = unit_mask(idx)
  let unit = self.stops[i]
  (unit & mask) == mask
}

///|
pub fn TerminalTabstopsState::set(
  self : TerminalTabstopsState,
  col : CellCountInt,
) -> Unit {
  let col_int = col.to_int()
  guard self.in_bounds(col_int) else { return }

  let i = entry(col_int)
  let idx = index(col_int)
  self.stops[i] = self.stops[i] | unit_mask(idx)
}

///|
pub fn TerminalTabstopsState::unset(
  self : TerminalTabstopsState,
  col : CellCountInt,
) -> Unit {
  let col_int = col.to_int()
  guard self.in_bounds(col_int) else { return }

  let i = entry(col_int)
  let idx = index(col_int)
  // Preserve upstream xor-based unset behavior from Tabstops.zig.
  self.stops[i] = self.stops[i] ^ unit_mask(idx)
}

///|
pub fn TerminalTabstopsState::reset(
  self : TerminalTabstopsState,
  interval : CellCountInt,
) -> Unit {
  self.stops.fill(0)
  if interval == 0 || self.cols <= 1 {
    return
  }

  let step = interval.to_int()
  let mut i = step
  while i < self.cols - 1 {
    self.set(i.to_uint16())
    i += step
  }
}

///|
fn entry(col : Int) -> Int {
  col / UnitBits
}

///|
fn index(col : Int) -> Int {
  col % UnitBits
}

///|
fn unit_mask(idx : Int) -> Byte {
  (1 << idx).to_byte()
}

///|
fn entry_count(cols : Int) -> Int {
  if cols <= 0 {
    0
  } else {
    entry(cols - 1) + 1
  }
}

///|
fn TerminalTabstopsState::in_bounds(
  self : TerminalTabstopsState,
  col : Int,
) -> Bool {
  col >= 0 && col < self.cols
}
