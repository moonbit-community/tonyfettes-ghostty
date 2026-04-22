///|
struct RenderRowIterator {
  state : RenderState
  mut y : Int
}

///|
struct RenderRowCells {
  state : RenderState
  row : Int
  mut x : Int
}

///|
pub fn RenderState::row_iterator(self : RenderState) -> RenderRowIterator {
  { state: self, y: -1 }
}

///|
pub fn RenderRowIterator::next(self : RenderRowIterator) -> Bool {
  let next_y = self.y + 1
  if next_y >= self.state.row_states.length() {
    false
  } else {
    self.y = next_y
    true
  }
}

///|
pub fn RenderRowIterator::y(self : RenderRowIterator) -> CellCountInt? {
  if self.y < 0 || self.y >= self.state.row_states.length() {
    None
  } else {
    Some(self.y.to_uint16())
  }
}

///|
pub fn RenderRowIterator::row(self : RenderRowIterator) -> PageRowState? {
  render_row_at(self.state, self.y)
}

///|
pub fn RenderRowIterator::dirty(self : RenderRowIterator) -> Bool? {
  render_row_dirty_at(self.state, self.y)
}

///|
pub fn RenderRowIterator::set_dirty(
  self : RenderRowIterator,
  value : Bool,
) -> Bool {
  render_set_row_dirty_at(self.state, self.y, value)
}

///|
pub fn RenderRowIterator::cells(self : RenderRowIterator) -> RenderRowCells? {
  if self.y < 0 || self.y >= self.state.row_states.length() {
    None
  } else {
    Some({ state: self.state, row: self.y, x: -1 })
  }
}

///|
pub fn RenderRowCells::next(self : RenderRowCells) -> Bool {
  let next_x = self.x + 1
  if self.row < 0 ||
    self.row >= self.state.row_cells.length() ||
    next_x >= self.state.row_cells[self.row].length() {
    false
  } else {
    self.x = next_x
    true
  }
}

///|
pub fn RenderRowCells::select(self : RenderRowCells, x : CellCountInt) -> Bool {
  let x_idx = x.to_int()
  if self.row < 0 ||
    self.row >= self.state.row_cells.length() ||
    x_idx < 0 ||
    x_idx >= self.state.row_cells[self.row].length() {
    false
  } else {
    self.x = x_idx
    true
  }
}

///|
pub fn RenderRowCells::x(self : RenderRowCells) -> CellCountInt? {
  if self.row < 0 ||
    self.row >= self.state.row_cells.length() ||
    self.x < 0 ||
    self.x >= self.state.row_cells[self.row].length() {
    None
  } else {
    Some(self.x.to_uint16())
  }
}

///|
pub fn RenderRowCells::cell(self : RenderRowCells) -> PageCellState? {
  render_cell_at(self.state, self.row, self.x)
}

///|
pub fn RenderRowCells::background_color(self : RenderRowCells) -> RGB? {
  render_cell_background_color_at(self.state, self.row, self.x)
}

///|
pub fn RenderRowCells::foreground_color(self : RenderRowCells) -> RGB? {
  render_cell_foreground_color_at(self.state, self.row, self.x)
}
