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
priv struct PageListTrackedPin {
  id : UInt64
  mut row_id : UInt64
  mut x : Int
  mut garbage : Bool
}

///|
priv struct PageListReflowCell {
  cell : PageCellState
  row_id : UInt64
  x : Int
}

///|
priv struct PageList {
  max_rows : Int
  mut history : Array[PageListRow]
  mut visible_row_ids : Array[UInt64]
  mut next_row_id : UInt64
  mut viewport_offset : Int
  mut pins : Array[PageListTrackedPin]
  mut next_pin_id : UInt64
  mut viewport_pin : UInt64?
}

///|
priv struct TerminalScreenStorage {
  mut grid : ScreenGridState
  mut cursor : TerminalCursorState
  saved_cursor : ScreenSavedCursorState
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
    pins: [],
    next_pin_id: 0UL,
    viewport_pin: None,
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
  self.set_viewport_row_offset(0)
}

///|
fn PageList::scroll_bottom(self : PageList) -> Unit {
  self.viewport_offset = 0
  self.clear_viewport_pin()
}

///|
fn PageList::scroll_delta(self : PageList, delta : Int) -> Unit {
  let current_offset = self.history.length() - self.viewport_row_offset()
  let next_offset = scrollback_clamp_int(
    current_offset - delta,
    0,
    self.history.length(),
  )
  self.set_viewport_row_offset(self.history.length() - next_offset)
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
  self.clear_viewport_pin()
  self.reset_visible_row_ids(rows.to_int())
  let fallback = self.active_top_row_id()
  for index in 0..<self.pins.length() {
    match fallback {
      Some(top) => {
        self.pins[index].row_id = top
        self.pins[index].x = 0
        self.pins[index].garbage = true
      }
      None => ()
    }
  }
}

///|
fn PageList::clear_history(self : PageList) -> Unit {
  self.mark_pins_for_rows_garbage(self.history)
  self.history = []
  self.viewport_offset = 0
  self.clear_viewport_pin()
}

///|
fn PageList::track_pin_at_row_id(
  self : PageList,
  row_id : UInt64,
  x : Int,
) -> UInt64 {
  let id = self.next_pin_id
  self.next_pin_id += 1UL
  self.pins.push({ id, row_id, x, garbage: false })
  id
}

///|
fn PageList::track_pin_at_point(
  self : PageList,
  grid : ScreenGridState,
  point : Point,
) -> UInt64? {
  let x = point.coord().x().to_int()
  if x < 0 || x >= grid.cols.to_int() {
    return None
  }
  match self.row_source_for_point(grid, point) {
    Some(PageListRowSource::History(index)) =>
      Some(self.track_pin_at_row_id(self.history[index].row_id, x))
    Some(PageListRowSource::Screen(index)) =>
      Some(self.track_pin_at_row_id(self.visible_row_ids[index], x))
    None => None
  }
}

///|
fn PageList::untrack_pin(self : PageList, id : UInt64) -> Unit {
  let next : Array[PageListTrackedPin] = []
  for pin in self.pins {
    if pin.id != id {
      next.push(pin)
    }
  }
  self.pins = next
}

///|
fn PageList::tracked_pin_index(self : PageList, id : UInt64) -> Int? {
  for index in 0..<self.pins.length() {
    if self.pins[index].id == id {
      return Some(index)
    }
  }
  None
}

///|
fn PageList::point_from_pin(
  self : PageList,
  grid : ScreenGridState,
  id : UInt64,
  tag : Tag,
) -> Coordinate? {
  match self.tracked_pin_index(id) {
    Some(index) => {
      let pin = self.pins[index]
      if pin.garbage {
        return None
      }
      self.point_from_row_id(grid, pin.row_id, pin.x.to_uint16(), tag)
    }
    None => None
  }
}

///|
fn PageList::grid_ref_from_pin(
  self : PageList,
  screen : TerminalScreen,
  id : UInt64,
) -> GridRef? {
  match self.tracked_pin_index(id) {
    Some(index) => {
      let pin = self.pins[index]
      if pin.garbage {
        None
      } else {
        Some(GridRef::new(screen, pin.row_id, pin.x.to_uint16()))
      }
    }
    None => None
  }
}

///|
fn PageList::pin_x(self : PageList, id : UInt64) -> CellCountInt? {
  match self.tracked_pin_index(id) {
    Some(index) =>
      if self.pins[index].garbage {
        None
      } else {
        Some(self.pins[index].x.to_uint16())
      }
    None => None
  }
}

///|
fn PageList::update_pins_for_row_id(
  self : PageList,
  old_id : UInt64,
  new_id : UInt64,
) -> Unit {
  for index in 0..<self.pins.length() {
    if self.pins[index].row_id == old_id {
      self.pins[index].row_id = new_id
      self.pins[index].garbage = false
    }
  }
}

///|
fn PageList::move_pins_for_cell(
  self : PageList,
  source_row_id : UInt64,
  source_x : Int,
  target_row_id : UInt64,
  target_x : Int,
) -> Unit {
  for index in 0..<self.pins.length() {
    if self.pins[index].row_id == source_row_id &&
      self.pins[index].x == source_x &&
      !self.pins[index].garbage {
      self.pins[index].row_id = target_row_id
      self.pins[index].x = target_x
    }
  }
}

///|
fn PageList::clamp_pins_to_cols(self : PageList, cols : CellCountInt) -> Unit {
  let max_x = cols.to_int() - 1
  for index in 0..<self.pins.length() {
    if self.pins[index].x > max_x {
      self.pins[index].x = max_x
    }
  }
}

///|
fn PageList::mark_pins_for_rows_garbage(
  self : PageList,
  rows : Array[PageListRow],
) -> Unit {
  for row in rows {
    self.mark_pins_for_row_id_garbage(row.row_id)
  }
}

///|
fn PageList::mark_pins_for_row_id_garbage(
  self : PageList,
  row_id : UInt64,
) -> Unit {
  let fallback = self.active_top_row_id()
  for index in 0..<self.pins.length() {
    if self.pins[index].row_id == row_id {
      match fallback {
        Some(top) => {
          self.pins[index].row_id = top
          self.pins[index].x = 0
          self.pins[index].garbage = true
        }
        None => ()
      }
    }
  }
}

///|
fn PageList::active_top_row_id(self : PageList) -> UInt64? {
  if self.visible_row_ids.length() > 0 {
    Some(self.visible_row_ids[0])
  } else if self.history.length() > 0 {
    Some(self.history[0].row_id)
  } else {
    None
  }
}

///|
fn PageList::row_id_at_absolute(self : PageList, row : Int) -> UInt64? {
  if row < 0 {
    return None
  }
  if row < self.history.length() {
    return Some(self.history[row].row_id)
  }
  let screen_index = row - self.history.length()
  if screen_index >= 0 && screen_index < self.visible_row_ids.length() {
    Some(self.visible_row_ids[screen_index])
  } else {
    None
  }
}

///|
fn PageList::clear_viewport_pin(self : PageList) -> Unit {
  match self.viewport_pin {
    Some(id) => self.untrack_pin(id)
    None => ()
  }
  self.viewport_pin = None
}

///|
fn PageList::set_viewport_row_offset(self : PageList, row : Int) -> Unit {
  let top = scrollback_clamp_int(row, 0, self.history.length())
  self.viewport_offset = self.history.length() - top
  self.clear_viewport_pin()
  if top < self.history.length() {
    match self.row_id_at_absolute(top) {
      Some(row_id) =>
        self.viewport_pin = Some(self.track_pin_at_row_id(row_id, 0))
      None => ()
    }
  }
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
  let cursor_pin = self.track_pin_at_point(
    grid,
    Point::Active(Coordinate::new(cursor.x(), cursor.y().to_uint())),
  )
  let saved_pin = match saved_cursor {
    Some(saved) =>
      self.track_pin_at_point(
        grid,
        Point::Active(Coordinate::new(saved.x(), saved.y().to_uint())),
      )
    None => None
  }
  let cursor_remaining_rows = grid.rows.to_int() - cursor.y().to_int() - 1
  let flattened = self.flatten_rows(grid)
  let resized = if target_cols == grid.cols {
    self.clamp_pins_to_cols(target_cols)
    copy_pinned_rows(flattened, target_cols)
  } else {
    self.reflow_rows(flattened, grid.cols, target_cols)
  }
  let result = self.rebuild_from_rows(
    resized,
    target_rows,
    target_cols,
    cursor_pin,
    saved_pin,
    if target_cols == grid.cols {
      None
    } else {
      Some(cursor_remaining_rows)
    },
    target_cols != grid.cols,
  )
  match cursor_pin {
    Some(id) => self.untrack_pin(id)
    None => ()
  }
  match saved_pin {
    Some(id) => self.untrack_pin(id)
    None => ()
  }
  result
}

///|
fn TerminalScreenStorage::resize(
  self : TerminalScreenStorage,
  rows : CellCountInt,
  cols : CellCountInt,
) -> PageListResizeResult {
  let pending_wrap = self.cursor.pending_wrap()
  let saved_cursor = if self.saved_cursor.has_saved() {
    Some(self.saved_cursor.restore())
  } else {
    None
  }
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
  self.saved_cursor.resize(result.saved_cursor, cols)
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
    saved_cursor: ScreenSavedCursorState::new(),
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
fn PageList::reflow_rows(
  self : PageList,
  rows : Array[PageListRow],
  old_cols : CellCountInt,
  new_cols : CellCountInt,
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
    let content_len = self.reflow_content_len(source, old_cols, new_cols)
    for col in 0..<content_len {
      line_cells.push({
        cell: copy_scrollback_cell(source.cells[col]),
        row_id: source.row_id,
        x: col,
      })
    }
    if !source.row.wrap() {
      self.emit_reflow_line(output, line_row_id, line_row, line_cells, new_cols)
      line_cells.clear()
      line_started = false
    }
  }
  if line_started {
    self.emit_reflow_line(output, line_row_id, line_row, line_cells, new_cols)
  }
  trim_trailing_blank_pinned_rows(self, output, new_cols)
}

///|
fn PageList::emit_reflow_line(
  self : PageList,
  output : Array[PageListRow],
  row_id : UInt64,
  source_row : PageRowState,
  cells : Array[PageListReflowCell],
  cols : CellCountInt,
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
    self.move_pins_for_cell(
      source.row_id,
      source.x,
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
            self.move_pins_for_cell(
              cells[index + 1].row_id,
              cells[index + 1].x,
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
      PageCellWide::SpacerHead => {
        self.move_pins_for_cell(
          source.row_id,
          source.x,
          current_row_id,
          current_cells.length(),
        )
        index += 1
      }
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
  cursor_pin : UInt64?,
  saved_pin : UInt64?,
  cursor_remaining_rows : Int?,
  renumber : Bool,
) -> PageListResizeResult {
  let target_rows = active_rows.to_int()
  let content_rows = trim_trailing_blank_pinned_rows(self, rows, cols)
  let padded = trim_leading_blank_pinned_rows(
    self, content_rows, target_rows, cols,
  )
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
    self.renumber_rows_in_display_order(padded)
  }

  let active_start = self.active_start_for_resize(
    padded, target_rows, cursor_pin, cursor_remaining_rows,
  )
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
    cursor: self.page_point_from_pin_rows(grid_rows, cols, cursor_pin),
    saved_cursor: self.page_point_from_pin_rows(grid_rows, cols, saved_pin),
  }
}

///|
fn PageList::active_start_for_resize(
  self : PageList,
  rows : Array[PageListRow],
  target_rows : Int,
  cursor_pin : UInt64?,
  cursor_remaining_rows : Int?,
) -> Int {
  let bottom_start = max_int(0, rows.length() - target_rows)
  match (cursor_pin, cursor_remaining_rows) {
    (Some(pin_id), Some(remaining)) =>
      match self.tracked_pin_index(pin_id) {
        Some(pin_index) => {
          let row_id = self.pins[pin_index].row_id
          for row_idx in 0..<rows.length() {
            if rows[row_idx].row_id == row_id {
              let desired = row_idx + remaining + 1 - target_rows
              return scrollback_clamp_int(desired, 0, bottom_start)
            }
          }
          bottom_start
        }
        None => bottom_start
      }
    _ => bottom_start
  }
}

///|
fn PageList::page_point_from_pin_rows(
  self : PageList,
  rows : Array[PageListRow],
  cols : CellCountInt,
  pin_id : UInt64?,
) -> PageListPoint? {
  match pin_id {
    Some(id) =>
      match self.tracked_pin_index(id) {
        Some(pin_index) => {
          let pin = self.pins[pin_index]
          if pin.garbage {
            return None
          }
          let x = scrollback_clamp_int(pin.x, 0, cols.to_int() - 1)
          for row_idx in 0..<rows.length() {
            if rows[row_idx].row_id == pin.row_id {
              return Some({ x: x.to_uint16(), y: row_idx.to_uint16() })
            }
          }
          None
        }
        None => None
      }
    None => None
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
  match self.viewport_pin {
    Some(id) =>
      match self.tracked_pin_index(id) {
        Some(index) =>
          if !self.pins[index].garbage {
            match self.absolute_index_of_row_id(self.pins[index].row_id) {
              Some(row) =>
                return scrollback_clamp_int(row, 0, self.history.length())
              None => ()
            }
          }
        None => ()
      }
    None => ()
  }
  scrollback_clamp_int(
    self.history.length() - self.viewport_offset,
    0,
    self.history.length(),
  )
}

///|
fn PageList::absolute_index_of_row_id(self : PageList, row_id : UInt64) -> Int? {
  match self.history_index_of_row_id(row_id) {
    Some(index) => Some(index)
    None =>
      self
      .screen_index_of_row_id(row_id)
      .map(fn(index) { self.history.length() + index })
  }
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
    self.mark_pins_for_rows_garbage(self.history)
    self.history = []
    self.clear_viewport_pin()
    return
  }

  let excess = self.history.length() - self.max_rows
  if excess <= 0 {
    return
  }

  let trimmed : Array[PageListRow] = []
  let removed : Array[PageListRow] = []
  for index in 0..<excess {
    removed.push(self.history[index])
  }
  for index in excess..<self.history.length() {
    trimmed.push(self.history[index])
  }
  self.history = trimmed
  self.mark_pins_for_rows_garbage(removed)
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
  let removed : Array[UInt64] = []
  let removed_count = min_int(count, bottom + 1)
  if self.max_rows <= 0 {
    for index in 0..<removed_count {
      if index < row_count {
        removed.push(self.visible_row_ids[index])
      }
    }
  }
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
  for row_id in removed {
    self.mark_pins_for_row_id_garbage(row_id)
  }
}

///|
fn PageList::shift_visible_row_ids_down(self : PageList, count : Int) -> Unit {
  let row_count = self.visible_row_ids.length()
  let removed : Array[UInt64] = []
  let keep = row_count - count
  for index in keep..<row_count {
    if index >= 0 {
      removed.push(self.visible_row_ids[index])
    }
  }
  let shifted : Array[UInt64] = []
  for _ in 0..<count {
    shifted.push(self.next_row_id)
    self.next_row_id += 1UL
  }
  for index in 0..<keep {
    shifted.push(self.visible_row_ids[index])
  }
  self.visible_row_ids = shifted
  for row_id in removed {
    self.mark_pins_for_row_id_garbage(row_id)
  }
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
  list : PageList,
  rows : Array[PageListRow],
  min_rows : Int,
  cols : CellCountInt,
) -> Array[PageListRow] {
  let mut start = 0
  while rows.length() - start > min_rows &&
        start < rows.length() &&
        pinned_row_is_blank(rows[start]) &&
        !list.pinned_row_is_tracked(rows[start]) {
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
  list : PageList,
  rows : Array[PageListRow],
  cols : CellCountInt,
) -> Array[PageListRow] {
  let mut end_ = rows.length()
  while end_ > 0 &&
        pinned_row_is_blank(rows[end_ - 1]) &&
        !list.pinned_row_is_tracked(rows[end_ - 1]) {
    end_ -= 1
  }
  let trimmed : Array[PageListRow] = []
  for index in 0..<end_ {
    trimmed.push(copy_pinned_row(rows[index], cols))
  }
  trimmed
}

///|
fn PageList::pinned_row_is_tracked(self : PageList, row : PageListRow) -> Bool {
  for pin in self.pins {
    if !pin.garbage && pin.row_id == row.row_id {
      return true
    }
  }
  false
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
) -> Unit {
  for index in 0..<rows.length() {
    let old_id = rows[index].row_id
    let new_id = self.allocate_row_id()
    rows[index].row_id = new_id
    self.update_pins_for_row_id(old_id, new_id)
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
fn PageList::reflow_content_len(
  self : PageList,
  source : PageListRow,
  old_cols : CellCountInt,
  new_cols : CellCountInt,
) -> Int {
  let limit = min_int(source.cells.length(), old_cols.to_int())
  let mut content_len = if source.row.wrap() {
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
  for index in 0..<self.pins.length() {
    if !self.pins[index].garbage &&
      self.pins[index].row_id == source.row_id &&
      self.pins[index].x < limit {
      if !source.row.wrap() && self.pins[index].x >= content_len {
        self.pins[index].x = min_int(self.pins[index].x, new_cols.to_int() - 1)
      }
      content_len = max_int(content_len, self.pins[index].x + 1)
    }
  }
  content_len
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
