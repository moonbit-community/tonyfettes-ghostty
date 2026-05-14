///|
pub(all) enum CursorVisualStyle {
  Block
  Bar
  Underline
} derive(Eq, Debug)

///|
struct TerminalCursorState {
  mut rows : CellCountInt
  mut columns : CellCountInt
  mut x : CellCountInt
  mut y : CellCountInt
  mut visual_style : CursorVisualStyle
  mut pending_wrap : Bool
  mut top_margin : CellCountInt
  mut bottom_margin : CellCountInt
  mut left_margin : CellCountInt
  mut right_margin : CellCountInt
} derive(Eq, Debug)

///|
pub fn TerminalCursorState::new(
  rows : CellCountInt,
  columns : CellCountInt,
) -> TerminalCursorState {
  let actual_rows = nonzero_dimension(rows)
  let actual_columns = nonzero_dimension(columns)
  {
    rows: actual_rows,
    columns: actual_columns,
    x: 0,
    y: 0,
    visual_style: CursorVisualStyle::Block,
    pending_wrap: false,
    top_margin: 0,
    bottom_margin: actual_rows - 1,
    left_margin: 0,
    right_margin: actual_columns - 1,
  }
}

///|
pub fn TerminalCursorState::x(self : TerminalCursorState) -> CellCountInt {
  self.x
}

///|
pub fn TerminalCursorState::y(self : TerminalCursorState) -> CellCountInt {
  self.y
}

///|
pub fn TerminalCursorState::visual_style(
  self : TerminalCursorState,
) -> CursorVisualStyle {
  self.visual_style
}

///|
pub fn TerminalCursorState::pending_wrap(self : TerminalCursorState) -> Bool {
  self.pending_wrap
}

///|
pub fn TerminalCursorState::top_margin(
  self : TerminalCursorState,
) -> CellCountInt {
  self.top_margin
}

///|
pub fn TerminalCursorState::bottom_margin(
  self : TerminalCursorState,
) -> CellCountInt {
  self.bottom_margin
}

///|
pub fn TerminalCursorState::left_margin(
  self : TerminalCursorState,
) -> CellCountInt {
  self.left_margin
}

///|
pub fn TerminalCursorState::right_margin(
  self : TerminalCursorState,
) -> CellCountInt {
  self.right_margin
}

///|
pub fn TerminalCursorState::set_pending_wrap(
  self : TerminalCursorState,
  pending_wrap : Bool,
) -> Unit {
  self.pending_wrap = pending_wrap
}

///|
pub fn TerminalCursorState::apply_cursor_style(
  self : TerminalCursorState,
  style : CursorStyle,
) -> Bool {
  match style {
    Default => {
      self.visual_style = CursorVisualStyle::Block
      false
    }
    BlinkingBlock => {
      self.visual_style = CursorVisualStyle::Block
      true
    }
    SteadyBlock => {
      self.visual_style = CursorVisualStyle::Block
      false
    }
    BlinkingUnderline => {
      self.visual_style = CursorVisualStyle::Underline
      true
    }
    SteadyUnderline => {
      self.visual_style = CursorVisualStyle::Underline
      false
    }
    BlinkingBar => {
      self.visual_style = CursorVisualStyle::Bar
      true
    }
    SteadyBar => {
      self.visual_style = CursorVisualStyle::Bar
      false
    }
  }
}

///|
pub fn TerminalCursorState::set_cursor_pos(
  self : TerminalCursorState,
  row_req : CellCountInt,
  col_req : CellCountInt,
  origin_mode : Bool,
) -> Unit {
  let row = one_indexed_request(row_req)
  let col = one_indexed_request(col_req)
  let x_offset = if origin_mode { self.left_margin.to_int() } else { 0 }
  let y_offset = if origin_mode { self.top_margin.to_int() } else { 0 }
  let x_max = if origin_mode {
    self.right_margin.to_int() + 1
  } else {
    self.columns.to_int()
  }
  let y_max = if origin_mode {
    self.bottom_margin.to_int() + 1
  } else {
    self.rows.to_int()
  }

  self.pending_wrap = false
  self.x = bounded_one_indexed_position(col, x_offset, x_max)
  self.y = bounded_one_indexed_position(row, y_offset, y_max)
}

///|
pub fn TerminalCursorState::set_top_and_bottom_margin(
  self : TerminalCursorState,
  top_req : CellCountInt,
  bottom_req : CellCountInt,
  origin_mode : Bool,
) -> Unit {
  let top = one_indexed_request(top_req)
  let bottom = clamped_bottom_margin(bottom_req, self.rows)
  if top >= bottom {
    return
  }

  self.top_margin = (top - 1).to_uint16()
  self.bottom_margin = (bottom - 1).to_uint16()
  self.set_cursor_pos(1, 1, origin_mode)
}

///|
pub fn TerminalCursorState::set_left_and_right_margin(
  self : TerminalCursorState,
  enabled : Bool,
  left_req : CellCountInt,
  right_req : CellCountInt,
  origin_mode : Bool,
) -> Unit {
  if !enabled {
    return
  }

  let left = one_indexed_request(left_req)
  let right = clamped_bottom_margin(right_req, self.columns)
  if left >= right {
    return
  }

  self.left_margin = (left - 1).to_uint16()
  self.right_margin = (right - 1).to_uint16()
  self.set_cursor_pos(1, 1, origin_mode)
}

///|
pub fn TerminalCursorState::full_reset(self : TerminalCursorState) -> Unit {
  self.x = 0
  self.y = 0
  self.visual_style = CursorVisualStyle::Block
  self.pending_wrap = false
  self.top_margin = 0
  self.bottom_margin = self.rows - 1
  self.left_margin = 0
  self.right_margin = self.columns - 1
}

///|
fn TerminalCursorState::resize(
  self : TerminalCursorState,
  rows : CellCountInt,
  columns : CellCountInt,
) -> Unit {
  let actual_rows = nonzero_dimension(rows)
  let actual_columns = nonzero_dimension(columns)
  self.rows = actual_rows
  self.columns = actual_columns
  self.x = min_cursor_coordinate(self.x, actual_columns)
  self.y = min_cursor_coordinate(self.y, actual_rows)
  self.top_margin = 0
  self.bottom_margin = actual_rows - 1
  self.left_margin = 0
  self.right_margin = actual_columns - 1
  if self.x < actual_columns - 1 {
    self.pending_wrap = false
  }
}

///|
fn nonzero_dimension(value : CellCountInt) -> CellCountInt {
  if value == 0 {
    1
  } else {
    value
  }
}

///|
fn one_indexed_request(value : CellCountInt) -> Int {
  if value == 0 {
    1
  } else {
    value.to_int()
  }
}

///|
fn clamped_bottom_margin(request : CellCountInt, limit : CellCountInt) -> Int {
  if request == 0 || request > limit {
    limit.to_int()
  } else {
    request.to_int()
  }
}

///|
fn bounded_one_indexed_position(
  value : Int,
  offset : Int,
  limit : Int,
) -> CellCountInt {
  let adjusted = value + offset
  let bounded = if adjusted > limit { limit } else { adjusted }
  (bounded - 1).to_uint16()
}

///|
fn min_cursor_coordinate(
  value : CellCountInt,
  limit : CellCountInt,
) -> CellCountInt {
  if value >= limit {
    limit - 1
  } else {
    value
  }
}
