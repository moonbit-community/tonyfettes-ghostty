///|
const UnitBits : Int32 = 8

///|
const DefaultTabstopInterval : @size.CellCountInt = 8

///|
struct TerminalTabstopsState {
  cols : Int32
  // One bit per column, packed 8-to-a-byte. Fixed `entry_count(cols)` wide —
  // never grown, only `fill`/indexed in place — so a `FixedArray` is the bare
  // contiguous buffer without the growable `Array` wrapper.
  stops : FixedArray[Byte]
} derive(Eq, Debug)

///|
pub fn TerminalTabstopsState::new(
  cols : @size.CellCountInt,
) -> TerminalTabstopsState {
  let cols_int = cols.to_int()
  let state = {
    cols: cols_int,
    stops: FixedArray::make(entry_count(cols_int), 0),
  }
  state.reset(DefaultTabstopInterval)
  state
}

///|
pub fn TerminalTabstopsState::get(
  self : TerminalTabstopsState,
  col : @size.CellCountInt,
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
  col : @size.CellCountInt,
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
  col : @size.CellCountInt,
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
  interval : @size.CellCountInt,
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
fn entry(col : Int32) -> Int32 {
  col / UnitBits
}

///|
fn index(col : Int32) -> Int32 {
  col % UnitBits
}

///|
fn unit_mask(idx : Int32) -> Byte {
  (1 << idx).to_byte()
}

///|
fn entry_count(cols : Int32) -> Int32 {
  if cols <= 0 {
    0
  } else {
    entry(cols - 1) + 1
  }
}

///|
fn TerminalTabstopsState::in_bounds(
  self : TerminalTabstopsState,
  col : Int32,
) -> Bool {
  col >= 0 && col < self.cols
}

///|
pub extend TerminalTabstopsState with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend TerminalTabstopsState with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend TerminalTabstopsState with @debug.Debug::{to_repr}
