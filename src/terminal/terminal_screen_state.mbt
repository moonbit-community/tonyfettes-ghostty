///|
pub(all) enum TerminalScreen {
  Primary
  Alternate
} derive(Eq, Debug)

///|
priv struct PageListRow {
  mut row_id : UInt64
  row : PageRowState
  cells : Array[PageCellState]
}

///|
priv enum PageListRowSource {
  History(Int)
  Screen(Int)
}

///|
priv struct PageListPoint {
  x : CellCountInt
  y : CellCountInt
}

///|
priv struct PageListResizeResult {
  grid : ScreenGridState
  cursor : PageListPoint?
  saved_cursor : PageListPoint?
}

///|
priv struct PageListTrackedPoint {
  row_id : UInt64
  mut x : Int
  mut target_row_id : UInt64?
  mut target_x : Int?
}

///|
priv struct PageListReflowCell {
  cell : PageCellState
  row_id : UInt64
  x : Int
}

///|
priv struct PageListTrackSet {
  cursor : PageListTrackedPoint?
  saved_cursor : PageListTrackedPoint?
}

///|
priv struct PageList {
  max_rows : Int
  mut history : Array[PageListRow]
  mut visible_row_ids : Array[UInt64]
  mut next_row_id : UInt64
  mut viewport_offset : Int
}

///|
priv struct TerminalScreenStorage {
  mut grid : ScreenGridState
  mut cursor : TerminalCursorState
  mut scrollback : PageList
  mut kitty_graphics : KittyGraphicsState
}

///|
fn PageList::new(rows : CellCountInt, max_rows : Int) -> PageList {
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
fn PageList::scrollback_rows(self : PageList) -> UInt {
  self.history.length().reinterpret_as_uint()
}

///|
fn PageList::total_rows(self : PageList, visible_rows : CellCountInt) -> UInt {
  visible_rows.to_uint() + self.scrollback_rows()
}

///|
fn PageList::scrollbar(
  self : PageList,
  visible_rows : CellCountInt,
) -> TerminalScrollbar {
  if self.max_rows <= 0 {
    let rows = visible_rows.to_uint()
    return TerminalScrollbar::new(rows, 0U, rows)
  }

  TerminalScrollbar::new(
    self.total_rows(visible_rows),
    self.viewport_row_offset().reinterpret_as_uint(),
    visible_rows.to_uint(),
  )
}

///|
fn PageList::row(
  self : PageList,
  grid : ScreenGridState,
  row : CellCountInt,
) -> PageRowState? {
  match self.visible_row_source(grid.rows.to_int(), row.to_int()) {
    Some(PageListRowSource::History(index)) =>
      Some(copy_scrollback_row(self.history[index].row))
    Some(PageListRowSource::Screen(index)) =>
      Some(copy_scrollback_row(grid.row_states[index]))
    None => None
  }
}

///|
fn PageList::cell(
  self : PageList,
  grid : ScreenGridState,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState? {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }

  match self.visible_row_source(grid.rows.to_int(), row.to_int()) {
    Some(PageListRowSource::History(index)) =>
      Some(copy_scrollback_cell(self.history[index].cells[col_idx]))
    Some(PageListRowSource::Screen(index)) =>
      Some(copy_scrollback_cell(grid.cells[grid.cell_index(index, col_idx)]))
    None => None
  }
}

///|
fn PageList::scroll_top(self : PageList) -> Unit {
  self.viewport_offset = self.history.length()
}

///|
fn PageList::scroll_bottom(self : PageList) -> Unit {
  self.viewport_offset = 0
}

///|
fn PageList::scroll_delta(self : PageList, delta : Int) -> Unit {
  self.viewport_offset = scrollback_clamp_int(
    self.viewport_offset - delta,
    0,
    self.history.length(),
  )
}

///|
fn PageList::capture_top_scroll_region_up(
  self : PageList,
  grid : ScreenGridState,
  bottom_req : Int,
  count_req : Int,
) -> Unit {
  let row_count = grid.rows.to_int()
  let bottom = scrollback_clamp_int(bottom_req, 0, row_count - 1)
  let count = scrollback_clamp_int(count_req, 0, bottom + 1)
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

  self.shift_visible_row_ids_top_region_up(bottom, count)
}

///|
fn PageList::capture_full_screen_scroll_down(
  self : PageList,
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
fn PageList::full_reset(self : PageList, rows : CellCountInt) -> Unit {
  self.history = []
  self.viewport_offset = 0
  self.reset_visible_row_ids(rows.to_int())
}

///|
fn PageList::clear_history(self : PageList) -> Unit {
  self.history = []
  self.viewport_offset = 0
}

///|
fn PageList::resize(
  self : PageList,
  grid : ScreenGridState,
  cols : CellCountInt,
  rows : CellCountInt,
  cursor : TerminalCursorState,
  saved_cursor : ScreenSavedCursor?,
) -> PageListResizeResult {
  let target_cols = screen_dimension(cols)
  let target_rows = screen_dimension(rows)
  let tracks = {
    cursor: self.tracked_cursor(grid, cursor),
    saved_cursor: self.tracked_saved_cursor(grid, saved_cursor),
  }
  let flattened = self.flatten_rows(grid)
  let resized = if target_cols == grid.cols {
    self.track_same_column_resize(tracks, target_cols)
    copy_pinned_rows(flattened, target_cols)
  } else {
    self.reflow_rows(flattened, grid.cols, target_cols, tracks)
  }
  self.rebuild_from_rows(
    resized,
    target_rows,
    target_cols,
    tracks,
    target_cols != grid.cols,
  )
}

///|
fn TerminalScreenStorage::resize(
  self : TerminalScreenStorage,
  rows : CellCountInt,
  cols : CellCountInt,
  saved_cursor : ScreenSavedCursor?,
) -> PageListResizeResult {
  let pending_wrap = self.cursor.pending_wrap()
  let result = self.scrollback.resize(
    self.grid,
    cols,
    rows,
    self.cursor,
    saved_cursor,
  )
  self.grid = result.grid
  self.cursor.resize(rows, cols)
  match result.cursor {
    Some(point) => {
      self.cursor.x = point.x
      self.cursor.y = point.y
      self.cursor.set_pending_wrap(
        pending_wrap && point.x == self.grid.cols - 1,
      )
    }
    None => {
      self.cursor.x = 0
      self.cursor.y = 0
      self.cursor.set_pending_wrap(false)
    }
  }
  result
}

///|
fn ScreenSavedCursorState::resize(
  self : ScreenSavedCursorState,
  point : PageListPoint?,
  cols : CellCountInt,
) -> Unit {
  match self.saved {
    Some(saved) =>
      self.saved = Some({
        x: match point {
          Some(value) => value.x
          None => 0
        },
        y: match point {
          Some(value) => value.y
          None => 0
        },
        style: saved.style(),
        cursor_protected: saved.cursor_protected(),
        pending_wrap: match point {
          Some(value) => saved.pending_wrap() && value.x == cols - 1
          None => false
        },
        origin: saved.origin(),
        charset: saved.charset(),
      })
    None => ()
  }
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
    scrollback: PageList::new(rows, max_scrollback),
    kitty_graphics: KittyGraphicsState::new(),
  }
}

///|
fn PageList::flatten_rows(
  self : PageList,
  grid : ScreenGridState,
) -> Array[PageListRow] {
  let rows : Array[PageListRow] = []
  for index in 0..<self.history.length() {
    rows.push(copy_pinned_row(self.history[index], grid.cols))
  }
  for row_idx in 0..<grid.rows.to_int() {
    rows.push(
      snapshot_scrollback_row(grid, row_idx, self.visible_row_ids[row_idx]),
    )
  }
  rows
}

///|
fn PageList::tracked_cursor(
  self : PageList,
  grid : ScreenGridState,
  cursor : TerminalCursorState,
) -> PageListTrackedPoint? {
  let y = cursor.y().to_int()
  if y < 0 || y >= grid.rows.to_int() || y >= self.visible_row_ids.length() {
    return None
  }
  Some({
    row_id: self.visible_row_ids[y],
    x: scrollback_clamp_int(cursor.x().to_int(), 0, grid.cols.to_int() - 1),
    target_row_id: None,
    target_x: None,
  })
}

///|
fn PageList::tracked_saved_cursor(
  self : PageList,
  grid : ScreenGridState,
  saved_cursor : ScreenSavedCursor?,
) -> PageListTrackedPoint? {
  match saved_cursor {
    Some(saved) => {
      let y = saved.y().to_int()
      if y < 0 || y >= grid.rows.to_int() || y >= self.visible_row_ids.length() {
        return None
      }
      Some({
        row_id: self.visible_row_ids[y],
        x: scrollback_clamp_int(saved.x().to_int(), 0, grid.cols.to_int() - 1),
        target_row_id: None,
        target_x: None,
      })
    }
    None => None
  }
}

///|
fn PageList::track_same_column_resize(
  _self : PageList,
  tracks : PageListTrackSet,
  cols : CellCountInt,
) -> Unit {
  track_same_column_resize_point(tracks.cursor, cols)
  track_same_column_resize_point(tracks.saved_cursor, cols)
}

///|
fn track_same_column_resize_point(
  tracked : PageListTrackedPoint?,
  cols : CellCountInt,
) -> Unit {
  match tracked {
    Some(point) => {
      point.target_row_id = Some(point.row_id)
      point.target_x = Some(scrollback_clamp_int(point.x, 0, cols.to_int() - 1))
    }
    None => ()
  }
}

///|
fn PageList::reflow_rows(
  self : PageList,
  rows : Array[PageListRow],
  old_cols : CellCountInt,
  new_cols : CellCountInt,
  tracks : PageListTrackSet,
) -> Array[PageListRow] {
  let output : Array[PageListRow] = []
  let line_cells : Array[PageListReflowCell] = []
  let mut line_row = PageRowState::new()
  let mut line_row_id = 0UL
  let mut line_started = false
  for index in 0..<rows.length() {
    let source = rows[index]
    if !line_started {
      line_row_id = source.row_id
      line_row = copy_scrollback_row(source.row)
      line_started = true
    }
    let content_len = reflow_content_len(source, old_cols, new_cols, tracks)
    for col in 0..<content_len {
      line_cells.push({
        cell: copy_scrollback_cell(source.cells[col]),
        row_id: source.row_id,
        x: col,
      })
    }
    if !source.row.wrap() {
      self.emit_reflow_line(
        output, line_row_id, line_row, line_cells, new_cols, tracks,
      )
      line_cells.clear()
      line_started = false
    }
  }
  if line_started {
    self.emit_reflow_line(
      output, line_row_id, line_row, line_cells, new_cols, tracks,
    )
  }
  trim_trailing_blank_pinned_rows(output, new_cols, tracks)
}

///|
fn PageList::emit_reflow_line(
  self : PageList,
  output : Array[PageListRow],
  row_id : UInt64,
  source_row : PageRowState,
  cells : Array[PageListReflowCell],
  cols : CellCountInt,
  tracks : PageListTrackSet,
) -> Unit {
  let width = cols.to_int()
  if cells.length() == 0 {
    output.push(
      make_pinned_row(row_id, source_row, [], cols, false, false, false),
    )
    return
  }

  let mut current_row_id = row_id
  let mut current_cells : Array[PageCellState] = []
  let mut wrap_continuation = false
  let mut index = 0
  while index < cells.length() {
    if current_cells.length() == width {
      output.push(
        make_pinned_row(
          current_row_id, source_row, current_cells, cols, true, wrap_continuation,
          true,
        ),
      )
      current_row_id = self.allocate_row_id()
      current_cells = []
      wrap_continuation = true
    }

    let source = cells[index]
    self.track_reflow_cell(
      tracks,
      source,
      current_row_id,
      current_cells.length(),
    )
    match source.cell.wide() {
      PageCellWide::Wide =>
        if width == 1 {
          current_cells.push(PageCellState::new())
          if index + 1 < cells.length() &&
            cells[index + 1].row_id == source.row_id &&
            cells[index + 1].x == source.x + 1 &&
            cells[index + 1].cell.wide() == PageCellWide::SpacerTail {
            self.track_reflow_cell(
              tracks,
              cells[index + 1],
              current_row_id,
              current_cells.length() - 1,
            )
            index += 2
          } else {
            index += 1
          }
        } else if current_cells.length() == width - 1 {
          current_cells.push(reflow_spacer_head_cell())
        } else {
          current_cells.push(copy_scrollback_cell(source.cell))
          index += 1
        }
      PageCellWide::SpacerTail =>
        if width == 1 {
          index += 1
        } else {
          current_cells.push(copy_scrollback_cell(source.cell))
          index += 1
        }
      PageCellWide::SpacerHead => index += 1
      PageCellWide::Narrow => {
        current_cells.push(copy_scrollback_cell(source.cell))
        index += 1
      }
    }
  }

  output.push(
    make_pinned_row(
      current_row_id, source_row, current_cells, cols, false, wrap_continuation,
      true,
    ),
  )
}

///|
fn PageList::rebuild_from_rows(
  self : PageList,
  rows : Array[PageListRow],
  active_rows : CellCountInt,
  cols : CellCountInt,
  tracks : PageListTrackSet,
  renumber : Bool,
) -> PageListResizeResult {
  let target_rows = active_rows.to_int()
  let padded = trim_leading_blank_pinned_rows(rows, target_rows, cols, tracks)
  while padded.length() < target_rows {
    padded.push(
      make_pinned_row(
        self.allocate_row_id(),
        PageRowState::new(),
        [],
        cols,
        false,
        false,
        false,
      ),
    )
  }
  if renumber {
    self.renumber_rows_in_display_order(padded, tracks)
  }

  let active_start = max_int(0, padded.length() - target_rows)
  let history_rows : Array[PageListRow] = []
  for index in 0..<active_start {
    history_rows.push(copy_pinned_row(padded[index], cols))
  }
  self.history = history_rows
  self.trim_history()

  let visible_ids : Array[UInt64] = []
  let grid_rows : Array[PageListRow] = []
  for index in active_start..<padded.length() {
    let row = copy_pinned_row(padded[index], cols)
    grid_rows.push(row)
    visible_ids.push(row.row_id)
  }
  self.visible_row_ids = visible_ids
  self.viewport_offset = scrollback_clamp_int(
    self.viewport_offset,
    0,
    self.history.length(),
  )
  {
    grid: screen_grid_from_rows(active_rows, cols, grid_rows),
    cursor: tracked_point_in_grid(grid_rows, cols, tracks.cursor),
    saved_cursor: tracked_point_in_grid(grid_rows, cols, tracks.saved_cursor),
  }
}

///|
fn PageList::grid_ref(
  self : PageList,
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
    Some(PageListRowSource::History(index)) =>
      Some(GridRef::new(screen, self.history[index].row_id, x))
    Some(PageListRowSource::Screen(index)) =>
      Some(GridRef::new(screen, self.visible_row_ids[index], x))
    None => None
  }
}

///|
fn PageList::row_by_id(
  self : PageList,
  grid : ScreenGridState,
  row_id : UInt64,
) -> PageRowState? {
  match self.row_source_by_id(row_id) {
    Some(PageListRowSource::History(index)) =>
      Some(copy_scrollback_row(self.history[index].row))
    Some(PageListRowSource::Screen(index)) =>
      Some(copy_scrollback_row(grid.row_states[index]))
    None => None
  }
}

///|
fn PageList::cell_by_id(
  self : PageList,
  grid : ScreenGridState,
  row_id : UInt64,
  col : CellCountInt,
) -> PageCellState? {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }

  match self.row_source_by_id(row_id) {
    Some(PageListRowSource::History(index)) =>
      Some(copy_scrollback_cell(self.history[index].cells[col_idx]))
    Some(PageListRowSource::Screen(index)) =>
      Some(copy_scrollback_cell(grid.cells[grid.cell_index(index, col_idx)]))
    None => None
  }
}

///|
fn PageList::point_from_row_id(
  self : PageList,
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
        Some(PageListRowSource::History(index)) =>
          Some(Coordinate::new(x, index.reinterpret_as_uint()))
        Some(PageListRowSource::Screen(index)) =>
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
fn PageList::visible_row_source(
  self : PageList,
  visible_rows : Int,
  row_idx : Int,
) -> PageListRowSource? {
  if row_idx < 0 || row_idx >= visible_rows {
    return None
  }

  let history_rows = self.history.length()
  let top_abs = self.viewport_row_offset()
  let absolute_row = top_abs + row_idx
  if absolute_row < history_rows {
    Some(PageListRowSource::History(absolute_row))
  } else {
    Some(PageListRowSource::Screen(absolute_row - history_rows))
  }
}

///|
fn PageList::row_source_for_point(
  self : PageList,
  grid : ScreenGridState,
  point : Point,
) -> PageListRowSource? {
  let y = point.coord().y().reinterpret_as_int()
  match point {
    Point::Active(_) => self.active_row_source(grid, y)
    Point::Viewport(_) => self.visible_row_source(grid.rows.to_int(), y)
    Point::Screen(_) => self.screen_row_source(grid, y)
    Point::History(_) => self.history_row_source(y)
  }
}

///|
fn PageList::active_row_source(
  _self : PageList,
  grid : ScreenGridState,
  y : Int,
) -> PageListRowSource? {
  if y < 0 || y >= grid.rows.to_int() {
    None
  } else {
    Some(PageListRowSource::Screen(y))
  }
}

///|
fn PageList::screen_row_source(
  self : PageList,
  grid : ScreenGridState,
  y : Int,
) -> PageListRowSource? {
  if y < 0 {
    return None
  }

  let history_rows = self.history.length()
  if y < history_rows {
    Some(PageListRowSource::History(y))
  } else if y < history_rows + grid.rows.to_int() {
    Some(PageListRowSource::Screen(y - history_rows))
  } else {
    None
  }
}

///|
fn PageList::history_row_source(self : PageList, y : Int) -> PageListRowSource? {
  if y < 0 || y >= self.history.length() {
    None
  } else {
    Some(PageListRowSource::History(y))
  }
}

///|
fn PageList::row_source_by_id(
  self : PageList,
  row_id : UInt64,
) -> PageListRowSource? {
  match self.history_index_of_row_id(row_id) {
    Some(index) => Some(PageListRowSource::History(index))
    None =>
      self
      .screen_index_of_row_id(row_id)
      .map(fn(index) { PageListRowSource::Screen(index) })
  }
}

///|
fn PageList::history_index_of_row_id(self : PageList, row_id : UInt64) -> Int? {
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
fn PageList::screen_index_of_row_id(self : PageList, row_id : UInt64) -> Int? {
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
fn PageList::viewport_index_of_row_id(
  self : PageList,
  grid : ScreenGridState,
  row_id : UInt64,
) -> Int? {
  let absolute_row = match self.row_source_by_id(row_id) {
    Some(PageListRowSource::History(index)) => index
    Some(PageListRowSource::Screen(index)) => self.history.length() + index
    None => return None
  }

  let top = self.viewport_row_offset()
  let bottom = top + grid.rows.to_int()
  if absolute_row < top || absolute_row >= bottom {
    None
  } else {
    Some(absolute_row - top)
  }
}

///|
fn PageList::viewport_row_offset(self : PageList) -> Int {
  scrollback_clamp_int(
    self.history.length() - self.viewport_offset,
    0,
    self.history.length(),
  )
}

///|
fn PageList::reset_visible_row_ids(self : PageList, row_count : Int) -> Unit {
  let ids : Array[UInt64] = []
  for _ in 0..<row_count {
    ids.push(self.next_row_id)
    self.next_row_id += 1UL
  }
  self.visible_row_ids = ids
}

///|
fn PageList::trim_history(self : PageList) -> Unit {
  if self.max_rows <= 0 {
    self.history = []
    return
  }

  let excess = self.history.length() - self.max_rows
  if excess <= 0 {
    return
  }

  let trimmed : Array[PageListRow] = []
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
fn PageList::shift_visible_row_ids_top_region_up(
  self : PageList,
  bottom : Int,
  count : Int,
) -> Unit {
  let row_count = self.visible_row_ids.length()
  let shifted : Array[UInt64] = []
  for index in 0..<row_count {
    if index <= bottom {
      let source = index + count
      if source <= bottom {
        shifted.push(self.visible_row_ids[source])
      } else {
        shifted.push(self.next_row_id)
        self.next_row_id += 1UL
      }
    } else {
      shifted.push(self.visible_row_ids[index])
    }
  }
  self.visible_row_ids = shifted
}

///|
fn PageList::shift_visible_row_ids_down(self : PageList, count : Int) -> Unit {
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
) -> PageListRow {
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
fn copy_pinned_rows(
  rows : Array[PageListRow],
  cols : CellCountInt,
) -> Array[PageListRow] {
  let copied : Array[PageListRow] = []
  for index in 0..<rows.length() {
    copied.push(copy_pinned_row(rows[index], cols))
  }
  copied
}

///|
fn trim_leading_blank_pinned_rows(
  rows : Array[PageListRow],
  min_rows : Int,
  cols : CellCountInt,
  tracks : PageListTrackSet,
) -> Array[PageListRow] {
  let mut start = 0
  while rows.length() - start > min_rows &&
        start < rows.length() &&
        pinned_row_is_blank(rows[start]) &&
        !pinned_row_is_tracked(rows[start], tracks) {
    start += 1
  }
  let trimmed : Array[PageListRow] = []
  for index in start..<rows.length() {
    trimmed.push(copy_pinned_row(rows[index], cols))
  }
  trimmed
}

///|
fn trim_trailing_blank_pinned_rows(
  rows : Array[PageListRow],
  cols : CellCountInt,
  tracks : PageListTrackSet,
) -> Array[PageListRow] {
  let mut end_ = rows.length()
  while end_ > 0 &&
        pinned_row_is_blank(rows[end_ - 1]) &&
        !pinned_row_is_tracked(rows[end_ - 1], tracks) {
    end_ -= 1
  }
  let trimmed : Array[PageListRow] = []
  for index in 0..<end_ {
    trimmed.push(copy_pinned_row(rows[index], cols))
  }
  trimmed
}

///|
fn pinned_row_is_tracked(row : PageListRow, tracks : PageListTrackSet) -> Bool {
  tracked_point_targets_row(tracks.cursor, row.row_id) ||
  tracked_point_targets_row(tracks.saved_cursor, row.row_id)
}

///|
fn tracked_point_targets_row(
  tracked : PageListTrackedPoint?,
  row_id : UInt64,
) -> Bool {
  match tracked {
    Some(point) =>
      match point.target_row_id {
        Some(target) => target == row_id
        None => false
      }
    None => false
  }
}

///|
fn pinned_row_is_blank(row : PageListRow) -> Bool {
  if row.row.wrap() ||
    row.row.wrap_continuation() ||
    row.row.semantic_prompt() != RowSemanticPrompt::None ||
    row.row.kitty_virtual_placeholder() {
    return false
  }
  for index in 0..<row.cells.length() {
    if reflow_cell_has_content(row.cells[index]) {
      return false
    }
  }
  true
}

///|
fn PageList::renumber_rows_in_display_order(
  self : PageList,
  rows : Array[PageListRow],
  tracks : PageListTrackSet,
) -> Unit {
  for index in 0..<rows.length() {
    let old_id = rows[index].row_id
    let new_id = self.allocate_row_id()
    rows[index].row_id = new_id
    update_tracked_row_id(tracks.cursor, old_id, new_id)
    update_tracked_row_id(tracks.saved_cursor, old_id, new_id)
  }
}

///|
fn update_tracked_row_id(
  tracked : PageListTrackedPoint?,
  old_id : UInt64,
  new_id : UInt64,
) -> Unit {
  match tracked {
    Some(point) =>
      match point.target_row_id {
        Some(target) =>
          if target == old_id {
            point.target_row_id = Some(new_id)
          }
        None => ()
      }
    None => ()
  }
}

///|
fn copy_pinned_row(source : PageListRow, cols : CellCountInt) -> PageListRow {
  make_pinned_row(
    source.row_id,
    source.row,
    source.cells,
    cols,
    source.row.wrap(),
    source.row.wrap_continuation(),
    false,
  )
}

///|
fn make_pinned_row(
  row_id : UInt64,
  source_row : PageRowState,
  source_cells : Array[PageCellState],
  cols : CellCountInt,
  wrap : Bool,
  wrap_continuation : Bool,
  update_prompt_continuation : Bool,
) -> PageListRow {
  let cells : Array[PageCellState] = []
  let width = cols.to_int()
  for col in 0..<width {
    if col < source_cells.length() {
      cells.push(copy_scrollback_cell(source_cells[col]))
    } else {
      cells.push(PageCellState::new())
    }
  }
  let row = copy_scrollback_row(source_row)
  row.set_wrap(wrap)
  row.set_wrap_continuation(wrap_continuation)
  if update_prompt_continuation &&
    wrap_continuation &&
    row.semantic_prompt() == RowSemanticPrompt::Prompt {
    row.set_semantic_prompt(RowSemanticPrompt::PromptContinuation)
  }
  apply_cell_flags_to_row(row, cells)
  { row_id, row, cells }
}

///|
fn PageList::track_reflow_cell(
  _self : PageList,
  tracks : PageListTrackSet,
  source : PageListReflowCell,
  target_row_id : UInt64,
  target_x : Int,
) -> Unit {
  track_reflow_cell_point(tracks.cursor, source, target_row_id, target_x)
  track_reflow_cell_point(tracks.saved_cursor, source, target_row_id, target_x)
}

///|
fn track_reflow_cell_point(
  tracked : PageListTrackedPoint?,
  source : PageListReflowCell,
  target_row_id : UInt64,
  target_x : Int,
) -> Unit {
  match tracked {
    Some(point) =>
      if point.target_row_id == None &&
        point.row_id == source.row_id &&
        point.x == source.x {
        point.target_row_id = Some(target_row_id)
        point.target_x = Some(target_x)
      }
    None => ()
  }
}

///|
fn reflow_spacer_head_cell() -> PageCellState {
  let cell = PageCellState::new()
  cell.set_wide(PageCellWide::SpacerHead)
  cell
}

///|
fn apply_cell_flags_to_row(
  row : PageRowState,
  cells : Array[PageCellState],
) -> Unit {
  let mut grapheme = false
  let mut styled = false
  let mut hyperlink = false
  for index in 0..<cells.length() {
    let cell = cells[index]
    if cell.has_grapheme() {
      grapheme = true
    }
    if cell.has_styling() {
      styled = true
    }
    if cell.hyperlink() != None {
      hyperlink = true
    }
  }
  row.set_grapheme(grapheme)
  row.set_styled(styled)
  row.set_hyperlink(hyperlink)
}

///|
fn reflow_content_len(
  source : PageListRow,
  old_cols : CellCountInt,
  new_cols : CellCountInt,
  tracks : PageListTrackSet,
) -> Int {
  let limit = min_int(source.cells.length(), old_cols.to_int())
  let content_len = if source.row.wrap() {
    limit
  } else {
    let mut index = limit
    let mut len = 0
    while index > 0 {
      index -= 1
      if reflow_cell_has_content(source.cells[index]) {
        len = index + 1
        break
      }
    }
    len
  }
  reflow_content_len_for_track(
    reflow_content_len_for_track(
      content_len,
      source,
      limit,
      new_cols,
      tracks.cursor,
    ),
    source,
    limit,
    new_cols,
    tracks.saved_cursor,
  )
}

///|
fn reflow_content_len_for_track(
  content_len : Int,
  source : PageListRow,
  limit : Int,
  new_cols : CellCountInt,
  tracked : PageListTrackedPoint?,
) -> Int {
  match tracked {
    Some(point) =>
      if point.row_id == source.row_id && point.x < limit {
        if !source.row.wrap() && point.x >= content_len {
          point.x = min_int(point.x, new_cols.to_int() - 1)
        }
        max_int(content_len, point.x + 1)
      } else {
        content_len
      }
    None => content_len
  }
}

///|
fn reflow_cell_has_content(cell : PageCellState) -> Bool {
  !cell.is_empty() ||
  cell.has_styling() ||
  cell.is_protected() ||
  cell.hyperlink() != None ||
  cell.semantic_content() != SemanticContent::Output
}

///|
fn screen_grid_from_rows(
  rows : CellCountInt,
  cols : CellCountInt,
  pinned_rows : Array[PageListRow],
) -> ScreenGridState {
  let grid = ScreenGridState::new(rows, cols)
  let row_count = min_int(rows.to_int(), pinned_rows.length())
  for row_idx in 0..<row_count {
    grid.row_states[row_idx] = copy_scrollback_row(pinned_rows[row_idx].row)
    for col_idx in 0..<cols.to_int() {
      grid.cells[grid.cell_index(row_idx, col_idx)] = copy_scrollback_cell(
        pinned_rows[row_idx].cells[col_idx],
      )
    }
  }
  grid
}

///|
fn tracked_point_in_grid(
  rows : Array[PageListRow],
  cols : CellCountInt,
  tracked : PageListTrackedPoint?,
) -> PageListPoint? {
  match tracked {
    Some(point) =>
      match point.target_row_id {
        Some(row_id) =>
          match point.target_x {
            Some(x) => {
              let target_x = scrollback_clamp_int(x, 0, cols.to_int() - 1)
              for row_idx in 0..<rows.length() {
                if rows[row_idx].row_id == row_id {
                  return Some({
                    x: target_x.to_uint16(),
                    y: row_idx.to_uint16(),
                  })
                }
              }
              None
            }
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn PageList::allocate_row_id(self : PageList) -> UInt64 {
  let row_id = self.next_row_id
  self.next_row_id += 1UL
  row_id
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
