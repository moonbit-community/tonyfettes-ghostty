///|
struct GridRef {
  screen : TerminalScreen
  row_id : UInt64
  x : CellCountInt
} derive(Eq, Debug)

///|
fn GridRef::new(
  screen : TerminalScreen,
  row_id : UInt64,
  x : CellCountInt,
) -> GridRef {
  { screen, row_id, x }
}

///|
fn GridRef::screen_key(self : GridRef) -> TerminalScreen {
  self.screen
}

///|
fn GridRef::row_id_value(self : GridRef) -> UInt64 {
  self.row_id
}

///|
fn GridRef::x_coord(self : GridRef) -> CellCountInt {
  self.x
}
