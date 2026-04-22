///|
pub(all) enum TerminalScreen {
  Primary
  Alternate
} derive(Eq, Debug)

///|
priv struct TerminalPinnedRow {
  row_id : UInt64
  row : PageRowState
  cells : Array[PageCellState]
} derive(Eq, Debug)

///|
priv enum TerminalVisibleRowSource {
  History(Int)
  Screen(Int)
} derive(Eq, Debug)

///|
priv struct TerminalScrollbackState {
  max_rows : Int
  mut history : Array[TerminalPinnedRow]
  mut visible_row_ids : Array[UInt64]
  mut next_row_id : UInt64
  mut viewport_offset : Int
} derive(Eq, Debug)

///|
priv struct TerminalScreenStorage {
  mut grid : ScreenGridState
  mut cursor : TerminalCursorState
  mut scrollback : TerminalScrollbackState
} derive(Eq, Debug)

///|
fn TerminalScrollbackState::new(
  rows : CellCountInt,
  max_rows : Int,
) -> TerminalScrollbackState {
  let state = {
    max_rows,
    history: [],
    visible_row_ids: [],
    next_row_id: 0UL,
    viewport_offset: 0,
  }
  state.reset_visible_row_ids(rows.to_int())
  state
}

///|
fn TerminalScrollbackState::scrollback_rows(
  self : TerminalScrollbackState,
) -> UInt {
  self.history.length().reinterpret_as_uint()
}

///|
fn TerminalScrollbackState::total_rows(
  self : TerminalScrollbackState,
  visible_rows : CellCountInt,
) -> UInt {
  visible_rows.to_uint() + self.scrollback_rows()
}

///|
fn TerminalScrollbackState::row(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  row : CellCountInt,
) -> PageRowState? {
  match self.visible_row_source(grid.rows.to_int(), row.to_int()) {
    Some(TerminalVisibleRowSource::History(index)) =>
      Some(copy_scrollback_row(self.history[index].row))
    Some(TerminalVisibleRowSource::Screen(index)) =>
      Some(copy_scrollback_row(grid.row_states[index]))
    None => None
  }
}

///|
fn TerminalScrollbackState::cell(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState? {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }

  match self.visible_row_source(grid.rows.to_int(), row.to_int()) {
    Some(TerminalVisibleRowSource::History(index)) =>
      Some(copy_scrollback_cell(self.history[index].cells[col_idx]))
    Some(TerminalVisibleRowSource::Screen(index)) =>
      Some(copy_scrollback_cell(grid.cells[grid.cell_index(index, col_idx)]))
    None => None
  }
}

///|
fn TerminalScrollbackState::scroll_top(self : TerminalScrollbackState) -> Unit {
  self.viewport_offset = self.history.length()
}

///|
fn TerminalScrollbackState::scroll_bottom(
  self : TerminalScrollbackState,
) -> Unit {
  self.viewport_offset = 0
}

///|
fn TerminalScrollbackState::scroll_delta(
  self : TerminalScrollbackState,
  delta : Int,
) -> Unit {
  self.viewport_offset = scrollback_clamp_int(
    self.viewport_offset - delta,
    0,
    self.history.length(),
  )
}

///|
fn TerminalScrollbackState::capture_full_screen_scroll_up(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  count_req : Int,
) -> Unit {
  let row_count = grid.rows.to_int()
  let count = scrollback_clamp_int(count_req, 0, row_count)
  if count == 0 {
    return
  }

  if self.max_rows > 0 {
    let mut row_idx = 0
    while row_idx < count {
      self.history.push(
        snapshot_scrollback_row(grid, row_idx, self.visible_row_ids[row_idx]),
      )
      row_idx += 1
    }

    if self.viewport_offset > 0 {
      self.viewport_offset += count
    }
    self.trim_history()
    self.viewport_offset = scrollback_clamp_int(
      self.viewport_offset,
      0,
      self.history.length(),
    )
  } else {
    self.viewport_offset = 0
  }

  self.shift_visible_row_ids_up(count)
}

///|
fn TerminalScrollbackState::capture_full_screen_scroll_down(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  count_req : Int,
) -> Unit {
  let count = scrollback_clamp_int(count_req, 0, grid.rows.to_int())
  if count == 0 {
    return
  }

  self.shift_visible_row_ids_down(count)
  self.viewport_offset = scrollback_clamp_int(
    self.viewport_offset,
    0,
    self.history.length(),
  )
}

///|
fn TerminalScrollbackState::full_reset(
  self : TerminalScrollbackState,
  rows : CellCountInt,
) -> Unit {
  self.history = []
  self.viewport_offset = 0
  self.reset_visible_row_ids(rows.to_int())
}

///|
fn TerminalScreenStorage::new(
  rows : CellCountInt,
  cols : CellCountInt,
  max_scrollback : Int,
) -> TerminalScreenStorage {
  {
    grid: ScreenGridState::new(rows, cols),
    cursor: TerminalCursorState::new(rows, cols),
    scrollback: TerminalScrollbackState::new(rows, max_scrollback),
  }
}

///|
fn TerminalScrollbackState::grid_ref(
  self : TerminalScrollbackState,
  screen : TerminalScreen,
  grid : ScreenGridState,
  point : Point,
) -> GridRef? {
  let x = point.coord().x()
  let x_idx = x.to_int()
  if x_idx < 0 || x_idx >= grid.cols.to_int() {
    return None
  }

  match self.row_source_for_point(grid, point) {
    Some(TerminalVisibleRowSource::History(index)) =>
      Some(GridRef::new(screen, self.history[index].row_id, x))
    Some(TerminalVisibleRowSource::Screen(index)) =>
      Some(GridRef::new(screen, self.visible_row_ids[index], x))
    None => None
  }
}

///|
fn TerminalScrollbackState::row_by_id(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  row_id : UInt64,
) -> PageRowState? {
  match self.row_source_by_id(row_id) {
    Some(TerminalVisibleRowSource::History(index)) =>
      Some(copy_scrollback_row(self.history[index].row))
    Some(TerminalVisibleRowSource::Screen(index)) =>
      Some(copy_scrollback_row(grid.row_states[index]))
    None => None
  }
}

///|
fn TerminalScrollbackState::cell_by_id(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  row_id : UInt64,
  col : CellCountInt,
) -> PageCellState? {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }

  match self.row_source_by_id(row_id) {
    Some(TerminalVisibleRowSource::History(index)) =>
      Some(copy_scrollback_cell(self.history[index].cells[col_idx]))
    Some(TerminalVisibleRowSource::Screen(index)) =>
      Some(copy_scrollback_cell(grid.cells[grid.cell_index(index, col_idx)]))
    None => None
  }
}

///|
fn TerminalScrollbackState::point_from_row_id(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  row_id : UInt64,
  x : CellCountInt,
  tag : Tag,
) -> Coordinate? {
  let x_idx = x.to_int()
  if x_idx < 0 || x_idx >= grid.cols.to_int() {
    return None
  }

  match tag {
    Tag::Active =>
      self
      .screen_index_of_row_id(row_id)
      .map(fn(index) { Coordinate::new(x, index.reinterpret_as_uint()) })
    Tag::Viewport =>
      self
      .viewport_index_of_row_id(grid, row_id)
      .map(fn(index) { Coordinate::new(x, index.reinterpret_as_uint()) })
    Tag::Screen =>
      match self.row_source_by_id(row_id) {
        Some(TerminalVisibleRowSource::History(index)) =>
          Some(Coordinate::new(x, index.reinterpret_as_uint()))
        Some(TerminalVisibleRowSource::Screen(index)) =>
          Some(
            Coordinate::new(
              x,
              (self.history.length() + index).reinterpret_as_uint(),
            ),
          )
        None => None
      }
    Tag::History =>
      self
      .history_index_of_row_id(row_id)
      .map(fn(index) { Coordinate::new(x, index.reinterpret_as_uint()) })
  }
}

///|
fn TerminalScrollbackState::visible_row_source(
  self : TerminalScrollbackState,
  visible_rows : Int,
  row_idx : Int,
) -> TerminalVisibleRowSource? {
  if row_idx < 0 || row_idx >= visible_rows {
    return None
  }

  let history_rows = self.history.length()
  let top_abs = scrollback_clamp_int(
    history_rows - self.viewport_offset,
    0,
    history_rows,
  )
  let absolute_row = top_abs + row_idx
  if absolute_row < history_rows {
    Some(TerminalVisibleRowSource::History(absolute_row))
  } else {
    Some(TerminalVisibleRowSource::Screen(absolute_row - history_rows))
  }
}

///|
fn TerminalScrollbackState::row_source_for_point(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  point : Point,
) -> TerminalVisibleRowSource? {
  let y = point.coord().y().reinterpret_as_int()
  match point {
    Point::Active(_) => self.active_row_source(grid, y)
    Point::Viewport(_) => self.visible_row_source(grid.rows.to_int(), y)
    Point::Screen(_) => self.screen_row_source(grid, y)
    Point::History(_) => self.history_row_source(y)
  }
}

///|
fn TerminalScrollbackState::active_row_source(
  _self : TerminalScrollbackState,
  grid : ScreenGridState,
  y : Int,
) -> TerminalVisibleRowSource? {
  if y < 0 || y >= grid.rows.to_int() {
    None
  } else {
    Some(TerminalVisibleRowSource::Screen(y))
  }
}

///|
fn TerminalScrollbackState::screen_row_source(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  y : Int,
) -> TerminalVisibleRowSource? {
  if y < 0 {
    return None
  }

  let history_rows = self.history.length()
  if y < history_rows {
    Some(TerminalVisibleRowSource::History(y))
  } else if y < history_rows + grid.rows.to_int() {
    Some(TerminalVisibleRowSource::Screen(y - history_rows))
  } else {
    None
  }
}

///|
fn TerminalScrollbackState::history_row_source(
  self : TerminalScrollbackState,
  y : Int,
) -> TerminalVisibleRowSource? {
  if y < 0 || y >= self.history.length() {
    None
  } else {
    Some(TerminalVisibleRowSource::History(y))
  }
}

///|
fn TerminalScrollbackState::row_source_by_id(
  self : TerminalScrollbackState,
  row_id : UInt64,
) -> TerminalVisibleRowSource? {
  match self.history_index_of_row_id(row_id) {
    Some(index) => Some(TerminalVisibleRowSource::History(index))
    None =>
      self
      .screen_index_of_row_id(row_id)
      .map(fn(index) { TerminalVisibleRowSource::Screen(index) })
  }
}

///|
fn TerminalScrollbackState::history_index_of_row_id(
  self : TerminalScrollbackState,
  row_id : UInt64,
) -> Int? {
  let mut index = 0
  while index < self.history.length() {
    if self.history[index].row_id == row_id {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn TerminalScrollbackState::screen_index_of_row_id(
  self : TerminalScrollbackState,
  row_id : UInt64,
) -> Int? {
  let mut index = 0
  while index < self.visible_row_ids.length() {
    if self.visible_row_ids[index] == row_id {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn TerminalScrollbackState::viewport_index_of_row_id(
  self : TerminalScrollbackState,
  grid : ScreenGridState,
  row_id : UInt64,
) -> Int? {
  let absolute_row = match self.row_source_by_id(row_id) {
    Some(TerminalVisibleRowSource::History(index)) => index
    Some(TerminalVisibleRowSource::Screen(index)) =>
      self.history.length() + index
    None => return None
  }

  let top = scrollback_clamp_int(
    self.history.length() - self.viewport_offset,
    0,
    self.history.length(),
  )
  let bottom = top + grid.rows.to_int()
  if absolute_row < top || absolute_row >= bottom {
    None
  } else {
    Some(absolute_row - top)
  }
}

///|
fn TerminalScrollbackState::reset_visible_row_ids(
  self : TerminalScrollbackState,
  row_count : Int,
) -> Unit {
  let ids : Array[UInt64] = []
  for _ in 0..<row_count {
    ids.push(self.next_row_id)
    self.next_row_id += 1UL
  }
  self.visible_row_ids = ids
}

///|
fn TerminalScrollbackState::trim_history(
  self : TerminalScrollbackState,
) -> Unit {
  if self.max_rows <= 0 {
    self.history = []
    return
  }

  let excess = self.history.length() - self.max_rows
  if excess <= 0 {
    return
  }

  let trimmed : Array[TerminalPinnedRow] = []
  for index in excess..<self.history.length() {
    trimmed.push(self.history[index])
  }
  self.history = trimmed
  self.viewport_offset = scrollback_clamp_int(
    self.viewport_offset - excess,
    0,
    self.history.length(),
  )
}

///|
fn TerminalScrollbackState::shift_visible_row_ids_up(
  self : TerminalScrollbackState,
  count : Int,
) -> Unit {
  let row_count = self.visible_row_ids.length()
  let shifted : Array[UInt64] = []
  for index in count..<row_count {
    shifted.push(self.visible_row_ids[index])
  }
  for _ in 0..<count {
    shifted.push(self.next_row_id)
    self.next_row_id += 1UL
  }
  self.visible_row_ids = shifted
}

///|
fn TerminalScrollbackState::shift_visible_row_ids_down(
  self : TerminalScrollbackState,
  count : Int,
) -> Unit {
  let row_count = self.visible_row_ids.length()
  let shifted : Array[UInt64] = []
  for _ in 0..<count {
    shifted.push(self.next_row_id)
    self.next_row_id += 1UL
  }
  let keep = row_count - count
  for index in 0..<keep {
    shifted.push(self.visible_row_ids[index])
  }
  self.visible_row_ids = shifted
}

///|
fn snapshot_scrollback_row(
  grid : ScreenGridState,
  row_idx : Int,
  row_id : UInt64,
) -> TerminalPinnedRow {
  let cells : Array[PageCellState] = []
  let mut col_idx = 0
  while col_idx < grid.cols.to_int() {
    cells.push(
      copy_scrollback_cell(grid.cells[grid.cell_index(row_idx, col_idx)]),
    )
    col_idx += 1
  }
  { row_id, row: copy_scrollback_row(grid.row_states[row_idx]), cells }
}

///|
fn copy_scrollback_row(row : PageRowState) -> PageRowState {
  {
    wrap: row.wrap,
    wrap_continuation: row.wrap_continuation,
    grapheme: row.grapheme,
    styled: row.styled,
    hyperlink: row.hyperlink,
    semantic_prompt: row.semantic_prompt,
    kitty_virtual_placeholder: row.kitty_virtual_placeholder,
    dirty: row.dirty,
  }
}

///|
fn copy_scrollback_cell(cell : PageCellState) -> PageCellState {
  {
    content_tag: cell.content_tag,
    codepoint: cell.codepoint,
    palette_index: cell.palette_index,
    bg_rgb: cell.bg_rgb,
    style: copy_scrollback_style(cell.style),
    wide: cell.wide,
    protected_flag: cell.protected_flag,
    hyperlink: match cell.hyperlink {
      Some(value) => Some(copy_scrollback_hyperlink(value))
      None => None
    },
    semantic_content: cell.semantic_content,
  }
}

///|
fn copy_scrollback_style(style : CellStyle) -> CellStyle {
  {
    fg_color: style.fg_color,
    bg_color: style.bg_color,
    underline_color: style.underline_color,
    bold: style.bold,
    italic: style.italic,
    faint: style.faint,
    blink: style.blink,
    inverse: style.inverse,
    invisible: style.invisible,
    strikethrough: style.strikethrough,
    overline: style.overline,
    underline: style.underline,
  }
}

///|
fn copy_scrollback_hyperlink(link : CellHyperlink) -> CellHyperlink {
  {
    uri: link.uri(),
    explicit_id: link.explicit_id(),
    implicit_id: link.implicit_id(),
  }
}

///|
fn scrollback_clamp_int(value : Int, min_ : Int, max_ : Int) -> Int {
  if value < min_ {
    min_
  } else if value > max_ {
    max_
  } else {
    value
  }
}
