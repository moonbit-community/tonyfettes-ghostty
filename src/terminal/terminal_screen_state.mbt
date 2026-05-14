///|
pub(all) enum TerminalScreen {
  Primary
  Alternate
} derive(Eq, Debug)

///|
priv struct PageListPage {
  rows : CellCountInt
  cols : CellCountInt
  row_states : Array[PageRowState]
  cells : Array[PageCellState]
}

///|
priv struct PageListNode {
  mut prev : PageListNode?
  mut next : PageListNode?
  page : PageListPage
}

///|
priv struct PageListRow {
  row_id : UInt64
  row : PageRowState
  cells : Array[PageCellState]
  node : PageListNode
  y : CellCountInt
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
priv struct PageListPin {
  id : UInt64
  mut node : PageListNode
  mut y : CellCountInt
  mut x : Int
  mut garbage : Bool
}

///|
priv enum PageListViewport {
  Active
  Top
  Pin
}

///|
priv struct PageList {
  max_rows : Int
  mut rows : CellCountInt
  mut cols : CellCountInt
  mut first : PageListNode?
  mut last : PageListNode?
  mut active_node : PageListNode
  mut history : Array[PageListRow]
  mut visible_row_ids : Array[UInt64]
  mut next_row_id : UInt64
  mut viewport : PageListViewport
  mut tracked_pins : Array[PageListPin]
  mut next_pin_id : UInt64
  mut viewport_pin : UInt64
  mut viewport_pin_row_offset : Int?
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
priv enum PageListReflowWriteResult {
  Success
  Repeat
  SkipNext
}

///|
priv struct PageListReflowCursor {
  cols : CellCountInt
  rows : Array[PageListRow]
  mut row_id : UInt64
  mut node : PageListNode
  mut x : Int
  mut pending_wrap : Bool
  mut new_rows : Int
  mut total_rows : Int
}

///|
priv struct PageListPreservedCursor {
  tracked_pin : UInt64
  remaining_rows : Int
  wrapped_rows : Int
}

///|
fn PageListPage::new(rows : CellCountInt, cols : CellCountInt) -> PageListPage {
  let actual_rows = screen_dimension(rows)
  let actual_cols = screen_dimension(cols)
  let row_states : Array[PageRowState] = []
  let cells : Array[PageCellState] = []
  for _ in 0..<actual_rows.to_int() {
    row_states.push(PageRowState::new())
  }
  for _ in 0..<(actual_rows.to_int() * actual_cols.to_int()) {
    cells.push(PageCellState::new())
  }
  { rows: actual_rows, cols: actual_cols, row_states, cells }
}

///|
fn PageListNode::new(page : PageListPage) -> PageListNode {
  { prev: None, next: None, page }
}

///|
fn PageList::new(
  rows : CellCountInt,
  cols : CellCountInt,
  max_rows : Int,
) -> PageList {
  let active_node = PageListNode::new(PageListPage::new(rows, cols))
  let state = {
    max_rows,
    rows: active_node.page.rows,
    cols: active_node.page.cols,
    first: Some(active_node),
    last: Some(active_node),
    active_node,
    history: [],
    visible_row_ids: [],
    next_row_id: 0UL,
    viewport: PageListViewport::Active,
    tracked_pins: [],
    next_pin_id: 0UL,
    viewport_pin: 0UL,
    viewport_pin_row_offset: None,
  }
  state.reset_visible_row_ids(state.rows.to_int())
  state.viewport_pin = state.track_pin(active_node, 0, 0)
  state.relink_nodes()
  state
}

///|
fn PageList::active_grid(self : PageList) -> ScreenGridState {
  {
    rows: self.active_node.page.rows,
    cols: self.active_node.page.cols,
    row_states: self.active_node.page.row_states,
    cells: self.active_node.page.cells,
  }
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
fn PageList::total_rows_int(self : PageList) -> Int {
  let mut total = 0
  let mut node = self.first
  let mut done = false
  while !done {
    match node {
      Some(current) => {
        total += current.page.rows.to_int()
        node = current.next
      }
      None => done = true
    }
  }
  total
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
  if self.max_rows <= 0 {
    self.viewport = PageListViewport::Active
  } else {
    self.viewport = PageListViewport::Top
  }
  self.viewport_pin_row_offset = None
}

///|
fn PageList::scroll_bottom(self : PageList) -> Unit {
  self.viewport = PageListViewport::Active
  self.viewport_pin_row_offset = None
}

///|
fn PageList::scroll_delta(self : PageList, delta : Int) -> Unit {
  if self.max_rows <= 0 {
    self.viewport = PageListViewport::Active
    self.viewport_pin_row_offset = None
    return
  }
  self.set_viewport_row_offset(self.viewport_row_offset() + delta)
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
      let row = snapshot_scrollback_row(
        grid,
        row_idx,
        self.visible_row_ids[row_idx],
      )
      self.move_pins_for_row(
        self.active_node,
        row_idx.to_uint16(),
        row.node,
        row.y,
      )
      self.history.push(row)
      row_idx += 1
    }

    self.trim_history()
  } else {
    self.viewport = PageListViewport::Active
    self.viewport_pin_row_offset = None
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
}

///|
fn PageList::full_reset(self : PageList, rows : CellCountInt) -> Unit {
  self.history = []
  self.viewport = PageListViewport::Active
  self.viewport_pin_row_offset = None
  self.reset_visible_row_ids(rows.to_int())
  self.relink_nodes()
  for index in 0..<self.tracked_pins.length() {
    self.mark_pin_garbage(index)
  }
}

///|
fn PageList::clear_history(self : PageList) -> Unit {
  self.mark_pins_for_rows_garbage(self.history)
  self.history = []
  self.viewport = PageListViewport::Active
  self.viewport_pin_row_offset = None
  self.relink_nodes()
}

///|
fn PageList::track_pin(
  self : PageList,
  node : PageListNode,
  y : CellCountInt,
  x : Int,
) -> UInt64 {
  let id = self.next_pin_id
  self.next_pin_id += 1UL
  self.tracked_pins.push({ id, node, y, x, garbage: false })
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
      Some(self.track_pin(self.history[index].node, self.history[index].y, x))
    Some(PageListRowSource::Screen(index)) =>
      Some(self.track_pin(self.active_node, index.to_uint16(), x))
    None => None
  }
}

///|
fn PageList::untrack_pin(self : PageList, id : UInt64) -> Unit {
  let next : Array[PageListPin] = []
  for pin in self.tracked_pins {
    if pin.id != id {
      next.push(pin)
    }
  }
  self.tracked_pins = next
}

///|
fn PageList::tracked_pin_index(self : PageList, id : UInt64) -> Int? {
  for index in 0..<self.tracked_pins.length() {
    if self.tracked_pins[index].id == id {
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
      let pin = self.tracked_pins[index]
      if pin.garbage {
        return None
      }
      self.point_from_pin_node(grid, pin, tag)
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
      let pin = self.tracked_pins[index]
      if pin.garbage {
        None
      } else {
        self
        .row_id_for_pin(pin)
        .map(fn(row_id) { GridRef::new(screen, row_id, pin.x.to_uint16()) })
      }
    }
    None => None
  }
}

///|
fn PageList::pin_x(self : PageList, id : UInt64) -> CellCountInt? {
  match self.tracked_pin_index(id) {
    Some(index) =>
      if self.tracked_pins[index].garbage {
        None
      } else {
        Some(self.tracked_pins[index].x.to_uint16())
      }
    None => None
  }
}

///|
fn PageList::point_from_pin_node(
  self : PageList,
  grid : ScreenGridState,
  pin : PageListPin,
  tag : Tag,
) -> Coordinate? {
  let x = pin.x.to_uint16()
  match self.row_source_for_pin(pin) {
    Some(PageListRowSource::History(index)) =>
      match tag {
        Tag::Active => None
        Tag::Viewport =>
          self
          .viewport_index_for_source(grid, PageListRowSource::History(index))
          .map(fn(row) { Coordinate::new(x, row.reinterpret_as_uint()) })
        Tag::Screen => Some(Coordinate::new(x, index.reinterpret_as_uint()))
        Tag::History => Some(Coordinate::new(x, index.reinterpret_as_uint()))
      }
    Some(PageListRowSource::Screen(index)) =>
      match tag {
        Tag::Active => Some(Coordinate::new(x, index.reinterpret_as_uint()))
        Tag::Viewport =>
          self
          .viewport_index_for_source(grid, PageListRowSource::Screen(index))
          .map(fn(row) { Coordinate::new(x, row.reinterpret_as_uint()) })
        Tag::Screen =>
          Some(
            Coordinate::new(
              x,
              (self.history.length() + index).reinterpret_as_uint(),
            ),
          )
        Tag::History => None
      }
    None => None
  }
}

///|
fn PageList::row_id_for_pin(self : PageList, pin : PageListPin) -> UInt64? {
  match self.row_source_for_pin(pin) {
    Some(PageListRowSource::History(index)) => Some(self.history[index].row_id)
    Some(PageListRowSource::Screen(index)) => Some(self.visible_row_ids[index])
    None => None
  }
}

///|
fn PageList::row_source_for_pin(
  self : PageList,
  pin : PageListPin,
) -> PageListRowSource? {
  if physical_equal(pin.node, self.active_node) {
    let index = pin.y.to_int()
    if index >= 0 && index < self.visible_row_ids.length() {
      return Some(PageListRowSource::Screen(index))
    }
    return None
  }

  for index in 0..<self.history.length() {
    if physical_equal(pin.node, self.history[index].node) &&
      pin.y == self.history[index].y {
      return Some(PageListRowSource::History(index))
    }
  }
  None
}

///|
fn PageList::viewport_index_for_source(
  self : PageList,
  grid : ScreenGridState,
  source : PageListRowSource,
) -> Int? {
  let row = match source {
    PageListRowSource::History(index) => index
    PageListRowSource::Screen(index) => self.history.length() + index
  }
  let top = self.viewport_row_offset()
  let bottom = top + grid.rows.to_int()
  if row < top || row >= bottom {
    None
  } else {
    Some(row - top)
  }
}

///|
fn PageList::preserved_cursor(
  self : PageList,
  grid : ScreenGridState,
  cursor_pin : UInt64?,
) -> PageListPreservedCursor? {
  match cursor_pin {
    Some(id) =>
      match self.tracked_pin_index(id) {
        Some(pin_index) => {
          let pin = self.tracked_pins[pin_index]
          match self.point_from_pin_node(grid, pin, Tag::Active) {
            Some(point) => {
              let y = point.y().reinterpret_as_int()
              Some({
                tracked_pin: id,
                remaining_rows: self.rows.to_int() - y - 1,
                wrapped_rows: self.count_wrap_continuations_left_up(grid, pin),
              })
            }
            None => None
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn PageList::count_wrap_continuations_left_up(
  self : PageList,
  grid : ScreenGridState,
  pin : PageListPin,
) -> Int {
  match self.row_source_for_pin(pin) {
    Some(PageListRowSource::Screen(index)) => {
      let mut wrapped = 0
      for row_idx in 0..<=index {
        if row_idx < grid.row_states.length() &&
          grid.row_states[row_idx].wrap_continuation() {
          wrapped += 1
        }
      }
      wrapped
    }
    _ => 0
  }
}

///|
fn PageList::move_pins_for_cell(
  self : PageList,
  source_node : PageListNode,
  source_y : CellCountInt,
  source_x : Int,
  target_node : PageListNode,
  target_y : CellCountInt,
  target_x : Int,
) -> Unit {
  for index in 0..<self.tracked_pins.length() {
    if physical_equal(self.tracked_pins[index].node, source_node) &&
      self.tracked_pins[index].y == source_y &&
      self.tracked_pins[index].x == source_x &&
      !self.tracked_pins[index].garbage {
      self.tracked_pins[index].node = target_node
      self.tracked_pins[index].y = target_y
      self.tracked_pins[index].x = target_x
    }
  }
}

///|
fn PageList::move_pins_for_row(
  self : PageList,
  source_node : PageListNode,
  source_y : CellCountInt,
  target_node : PageListNode,
  target_y : CellCountInt,
) -> Unit {
  for index in 0..<self.tracked_pins.length() {
    if physical_equal(self.tracked_pins[index].node, source_node) &&
      self.tracked_pins[index].y == source_y &&
      !self.tracked_pins[index].garbage {
      self.tracked_pins[index].node = target_node
      self.tracked_pins[index].y = target_y
    }
  }
}

///|
fn PageList::clamp_pins_to_cols(self : PageList, cols : CellCountInt) -> Unit {
  let max_x = cols.to_int() - 1
  for index in 0..<self.tracked_pins.length() {
    if self.tracked_pins[index].x > max_x {
      self.tracked_pins[index].x = max_x
    }
  }
}

///|
fn PageList::mark_pins_for_rows_garbage(
  self : PageList,
  rows : Array[PageListRow],
) -> Unit {
  for row in rows {
    self.mark_pins_for_row_garbage(row)
  }
}

///|
fn PageList::mark_pins_for_row_garbage(
  self : PageList,
  row : PageListRow,
) -> Unit {
  for index in 0..<self.tracked_pins.length() {
    if physical_equal(self.tracked_pins[index].node, row.node) &&
      self.tracked_pins[index].y == row.y {
      self.mark_pin_garbage(index)
    }
  }
}

///|
fn PageList::mark_pin_garbage(self : PageList, index : Int) -> Unit {
  if self.tracked_pins[index].id == self.viewport_pin {
    self.tracked_pins[index].node = self.active_node
    self.tracked_pins[index].y = 0
    self.tracked_pins[index].x = 0
    self.tracked_pins[index].garbage = false
    return
  }
  self.tracked_pins[index].node = self.active_node
  self.tracked_pins[index].y = 0
  self.tracked_pins[index].x = 0
  self.tracked_pins[index].garbage = true
}

///|
fn PageList::set_viewport_row_offset(self : PageList, row : Int) -> Unit {
  if self.max_rows <= 0 {
    self.viewport = PageListViewport::Active
    self.viewport_pin_row_offset = None
    return
  }
  let top = scrollback_clamp_int(row, 0, self.history.length())
  if top == 0 {
    self.viewport = PageListViewport::Top
    self.viewport_pin_row_offset = None
  } else if top >= self.history.length() {
    self.viewport = PageListViewport::Active
    self.viewport_pin_row_offset = None
  } else {
    let row = self.history[top]
    self.set_viewport_pin(row)
    self.viewport = PageListViewport::Pin
    self.viewport_pin_row_offset = Some(top)
  }
}

///|
fn PageList::pin_is_active(self : PageList, pin : PageListPin) -> Bool {
  match self.row_source_for_pin(pin) {
    Some(PageListRowSource::Screen(_)) => true
    _ => false
  }
}

///|
fn PageList::fixup_viewport(self : PageList, removed : Int) -> Unit {
  match self.viewport {
    PageListViewport::Active => ()
    PageListViewport::Pin =>
      match self.tracked_pin_index(self.viewport_pin) {
        Some(index) =>
          if self.pin_is_active(self.tracked_pins[index]) {
            self.viewport = PageListViewport::Active
            self.viewport_pin_row_offset = None
          } else {
            match self.viewport_pin_row_offset {
              Some(offset) =>
                if offset < removed {
                  self.viewport = PageListViewport::Top
                  self.viewport_pin_row_offset = None
                } else {
                  self.viewport_pin_row_offset = Some(offset - removed)
                }
              None => ()
            }
          }
        None => {
          self.viewport = PageListViewport::Active
          self.viewport_pin_row_offset = None
        }
      }
    PageListViewport::Top =>
      match self.first {
        Some(first) =>
          if physical_equal(first, self.active_node) {
            self.viewport = PageListViewport::Active
            self.viewport_pin_row_offset = None
          }
        None => {
          self.viewport = PageListViewport::Active
          self.viewport_pin_row_offset = None
        }
      }
  }
}

///|
fn PageList::relink_nodes(self : PageList) -> Unit {
  let mut previous : PageListNode? = None
  let mut first : PageListNode? = None
  for row in self.history {
    row.node.prev = previous
    row.node.next = None
    match previous {
      Some(node) => node.next = Some(row.node)
      None => first = Some(row.node)
    }
    previous = Some(row.node)
  }
  self.active_node.prev = previous
  self.active_node.next = None
  match previous {
    Some(node) => node.next = Some(self.active_node)
    None => first = Some(self.active_node)
  }
  self.first = first
  self.last = Some(self.active_node)
}

///|
fn PageList::pin_row_offset(self : PageList, pin : PageListPin) -> Int? {
  let total_rows = self.total_rows_int()
  let mut node = self.last
  let mut rows_from_bottom = 0
  let mut result : Int? = None
  let mut done = false
  while !done {
    match node {
      Some(current) => {
        let row_count = current.page.rows.to_int()
        rows_from_bottom += row_count
        if physical_equal(current, pin.node) {
          result = Some(total_rows - rows_from_bottom + pin.y.to_int())
          done = true
        } else {
          node = current.prev
        }
      }
      None => done = true
    }
  }
  result
}

///|
fn PageList::set_viewport_pin(self : PageList, row : PageListRow) -> Unit {
  match self.tracked_pin_index(self.viewport_pin) {
    Some(index) => {
      self.tracked_pins[index].node = row.node
      self.tracked_pins[index].y = row.y
      self.tracked_pins[index].x = 0
      self.tracked_pins[index].garbage = false
    }
    None => self.viewport_pin = self.track_pin(row.node, row.y, 0)
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
  self.viewport_pin_row_offset = None
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
  let result = if target_cols == grid.cols {
    self.resize_without_reflow(
      grid, target_cols, target_rows, cursor, cursor_pin, saved_pin,
    )
  } else if target_cols > grid.cols {
    let cols_result = self.resize_cols(grid, target_cols, cursor_pin, saved_pin)
    if target_rows == cols_result.grid.rows {
      cols_result
    } else {
      self.resize_without_reflow(
        cols_result.grid,
        target_cols,
        target_rows,
        cursor,
        cursor_pin,
        saved_pin,
      )
    }
  } else {
    let rows_result = if target_rows == grid.rows {
      { grid, cursor: None, saved_cursor: None }
    } else {
      self.resize_without_reflow(
        grid,
        grid.cols,
        target_rows,
        cursor,
        cursor_pin,
        saved_pin,
      )
    }
    self.resize_cols(rows_result.grid, target_cols, cursor_pin, saved_pin)
  }
  self.fixup_viewport(0)
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
fn PageList::resize_without_reflow(
  self : PageList,
  grid : ScreenGridState,
  cols : CellCountInt,
  rows : CellCountInt,
  cursor : TerminalCursorState,
  cursor_pin : UInt64?,
  saved_pin : UInt64?,
) -> PageListResizeResult {
  if cols < grid.cols {
    self.clamp_pins_to_cols(cols)
  }
  if cols != grid.cols {
    let resized_history : Array[PageListRow] = []
    for row in self.history {
      let resized = make_pinned_row(
        row.row_id,
        row.row,
        row.cells,
        cols,
        row.row.wrap(),
        row.row.wrap_continuation(),
        false,
      )
      self.move_pins_for_row(row.node, row.y, resized.node, resized.y)
      resized_history.push(resized)
    }
    self.history = resized_history
  }

  let active_rows : Array[PageListRow] = []
  for row_idx in 0..<grid.rows.to_int() {
    let row = snapshot_scrollback_row(
      grid,
      row_idx,
      self.visible_row_ids[row_idx],
    )
    active_rows.push({
      row_id: row.row_id,
      row: row.row,
      cells: row.cells,
      node: self.active_node,
      y: row_idx.to_uint16(),
    })
  }

  let target_rows = rows.to_int()
  let current_rows = active_rows.length()
  let grid_rows : Array[PageListRow] = []
  let visible_ids : Array[UInt64] = []

  if target_rows < current_rows {
    let max_trim = current_rows - target_rows
    let trimmed = self.trim_trailing_blank_rows(active_rows, max_trim)
    let remaining = current_rows - trimmed
    let history_count = max_int(0, remaining - target_rows)

    for index in 0..<history_count {
      let source = active_rows[index]
      if self.max_rows > 0 {
        let history_row = make_pinned_row(
          source.row_id,
          source.row,
          source.cells,
          cols,
          source.row.wrap(),
          source.row.wrap_continuation(),
          false,
        )
        self.move_pins_for_row(
          source.node,
          source.y,
          history_row.node,
          history_row.y,
        )
        self.history.push(history_row)
      } else {
        self.mark_pins_for_row_garbage(source)
      }
    }

    for index in history_count..<remaining {
      let row = copy_pinned_row(active_rows[index], cols)
      grid_rows.push(row)
      visible_ids.push(row.row_id)
    }
  } else if target_rows > current_rows {
    let grow_count = target_rows - current_rows
    let cursor_at_bottom = cursor.y().to_int() >= current_rows - 1
    let pull_count = if cursor_at_bottom {
      min_int(grow_count, self.history.length())
    } else {
      0
    }
    let history_keep = self.history.length() - pull_count
    let pulled_rows : Array[PageListRow] = []
    for index in history_keep..<self.history.length() {
      pulled_rows.push(copy_pinned_row(self.history[index], cols))
    }
    if pull_count > 0 {
      let history_rows : Array[PageListRow] = []
      for index in 0..<history_keep {
        history_rows.push(self.history[index])
      }
      self.history = history_rows
    }

    for row in pulled_rows {
      grid_rows.push(row)
      visible_ids.push(row.row_id)
    }
    for row in active_rows {
      grid_rows.push(copy_pinned_row(row, cols))
      visible_ids.push(row.row_id)
    }
    for _ in 0..<(grow_count - pull_count) {
      let row = make_pinned_row(
        self.allocate_row_id(),
        PageRowState::new(),
        [],
        cols,
        false,
        false,
        false,
      )
      visible_ids.push(row.row_id)
      grid_rows.push(row)
    }
  } else {
    for row in active_rows {
      grid_rows.push(copy_pinned_row(row, cols))
      visible_ids.push(row.row_id)
    }
  }

  self.visible_row_ids = visible_ids
  self.trim_history()

  let resized_grid = screen_grid_from_rows(rows, cols, grid_rows)
  let active_node = PageListNode::new({
    rows: resized_grid.rows,
    cols: resized_grid.cols,
    row_states: resized_grid.row_states,
    cells: resized_grid.cells,
  })
  self.active_node = active_node
  self.rows = resized_grid.rows
  self.cols = resized_grid.cols
  for row_idx in 0..<grid_rows.length() {
    self.move_pins_for_row(
      grid_rows[row_idx].node,
      grid_rows[row_idx].y,
      active_node,
      row_idx.to_uint16(),
    )
  }
  self.relink_nodes()

  {
    grid: resized_grid,
    cursor: self.page_point_from_pin_rows(grid_rows, cols, cursor_pin),
    saved_cursor: self.page_point_from_pin_rows(grid_rows, cols, saved_pin),
  }
}

///|
fn PageList::resize_cols(
  self : PageList,
  grid : ScreenGridState,
  cols : CellCountInt,
  cursor_pin : UInt64?,
  saved_pin : UInt64?,
) -> PageListResizeResult {
  let preserved_cursor = self.preserved_cursor(grid, cursor_pin)
  self.cols = cols

  let source_rows : Array[PageListRow] = []
  for row in self.history {
    source_rows.push(row)
  }
  for row_idx in 0..<grid.rows.to_int() {
    let row = snapshot_scrollback_row(
      grid,
      row_idx,
      self.visible_row_ids[row_idx],
    )
    source_rows.push({
      row_id: row.row_id,
      row: row.row,
      cells: row.cells,
      node: self.active_node,
      y: row_idx.to_uint16(),
    })
  }

  let cursor = PageListReflowCursor::new(self, cols)
  for row in source_rows {
    cursor.reflow_row(self, row)
  }
  let reflowed = cursor.finish(self)
  while cursor.total_rows < self.rows.to_int() {
    reflowed.push(
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
    cursor.total_rows += 1
  }

  let active_rows = self.rows.to_int()
  let bottom_start = max_int(0, reflowed.length() - active_rows)
  let active_start = match preserved_cursor {
    Some(preserved) =>
      match self.tracked_pin_index(preserved.tracked_pin) {
        Some(pin_index) => {
          let pin = self.tracked_pins[pin_index]
          let mut pin_row = -1
          for row_idx in 0..<reflowed.length() {
            if physical_equal(reflowed[row_idx].node, pin.node) &&
              reflowed[row_idx].y == pin.y {
              pin_row = row_idx
            }
          }
          if pin_row < 0 {
            bottom_start
          } else {
            let mut wrapped_after = 0
            let mut row_idx = bottom_start
            while row_idx <= pin_row {
              if reflowed[row_idx].row.wrap_continuation() {
                wrapped_after += 1
              }
              row_idx += 1
            }
            let added_wraps = max_int(0, wrapped_after - preserved.wrapped_rows)
            let remaining = max_int(0, preserved.remaining_rows - added_wraps)
            let desired = pin_row + remaining + 1 - active_rows
            scrollback_clamp_int(desired, 0, bottom_start)
          }
        }
        None => bottom_start
      }
    None => bottom_start
  }
  let active_end = min_int(reflowed.length(), active_start + active_rows)

  let history_rows : Array[PageListRow] = []
  for index in 0..<active_start {
    history_rows.push(reflowed[index])
  }
  for index in active_end..<reflowed.length() {
    self.mark_pins_for_row_garbage(reflowed[index])
  }
  self.history = history_rows
  self.trim_history()

  let grid_rows : Array[PageListRow] = []
  let visible_ids : Array[UInt64] = []
  for index in active_start..<active_end {
    grid_rows.push(reflowed[index])
    visible_ids.push(reflowed[index].row_id)
  }
  self.visible_row_ids = visible_ids

  let resized_grid = screen_grid_from_rows(self.rows, cols, grid_rows)
  let active_node = PageListNode::new({
    rows: resized_grid.rows,
    cols: resized_grid.cols,
    row_states: resized_grid.row_states,
    cells: resized_grid.cells,
  })
  self.active_node = active_node
  self.rows = resized_grid.rows
  self.cols = resized_grid.cols
  for row_idx in 0..<grid_rows.length() {
    self.move_pins_for_row(
      grid_rows[row_idx].node,
      grid_rows[row_idx].y,
      active_node,
      row_idx.to_uint16(),
    )
  }
  self.relink_nodes()

  {
    grid: resized_grid,
    cursor: self.page_point_from_pin_rows(grid_rows, cols, cursor_pin),
    saved_cursor: self.page_point_from_pin_rows(grid_rows, cols, saved_pin),
  }
}

///|
fn PageListReflowCursor::new(
  list : PageList,
  cols : CellCountInt,
) -> PageListReflowCursor {
  {
    cols,
    rows: [],
    row_id: list.allocate_row_id(),
    node: PageListNode::new(PageListPage::new(1, cols)),
    x: 0,
    pending_wrap: false,
    new_rows: 0,
    total_rows: 1,
  }
}

///|
fn PageListReflowCursor::row(self : PageListReflowCursor) -> PageListRow {
  {
    row_id: self.row_id,
    row: self.node.page.row_states[0],
    cells: self.node.page.cells,
    node: self.node,
    y: 0,
  }
}

///|
fn PageListReflowCursor::finish(
  self : PageListReflowCursor,
  list : PageList,
) -> Array[PageListRow] {
  let row = self.row()
  if !pinned_row_is_blank(row) || list.pinned_row_is_tracked(row) {
    apply_cell_flags_to_row(row.row, row.cells)
    self.rows.push(row)
  }
  self.total_rows = self.rows.length()
  self.rows
}

///|
fn PageListReflowCursor::reflow_row(
  self : PageListReflowCursor,
  list : PageList,
  source : PageListRow,
) -> Unit {
  let mut cols_len = source.cells.length()
  if !source.row.wrap() {
    while cols_len > 0 && source.cells[cols_len - 1].is_empty() {
      cols_len -= 1
    }
    if cols_len == 0 && source.row.semantic_prompt() != RowSemanticPrompt::None {
      cols_len = 1
    }
  }

  for index in 0..<list.tracked_pins.length() {
    let pin = list.tracked_pins[index]
    if !pin.garbage &&
      physical_equal(pin.node, source.node) &&
      pin.y == source.y {
      if pin.x >= cols_len {
        list.tracked_pins[index].x = min_int(
          pin.x,
          self.cols.to_int() - 1 - self.x,
        )
      }
      cols_len = max_int(cols_len, list.tracked_pins[index].x + 1)
    }
  }

  if cols_len == 0 {
    if !source.row.wrap_continuation() {
      self.new_rows += 1
    }
    return
  }

  while self.new_rows > 0 {
    self.cursor_scroll_or_new_page(list)
    self.new_rows -= 1
  }

  self.copy_row_metadata(source.row)
  let mut x = 0
  while x < cols_len {
    if self.pending_wrap {
      self.node.page.row_states[0].set_wrap(true)
      self.cursor_scroll_or_new_page(list)
      self.copy_row_metadata(source.row)
      self.node.page.row_states[0].set_wrap_continuation(true)
    }

    list.move_pins_for_cell(source.node, source.y, x, self.node, 0, self.x)

    match self.write_cell(source.cells[x]) {
      PageListReflowWriteResult::Success => x += 1
      PageListReflowWriteResult::SkipNext => {
        if x + 1 < cols_len {
          list.move_pins_for_cell(
            source.node,
            source.y,
            x + 1,
            self.node,
            0,
            self.x,
          )
        }
        x += 2
      }
      PageListReflowWriteResult::Repeat => ()
    }
  }

  if !source.row.wrap() {
    self.new_rows += 1
  }
}

///|
fn PageListReflowCursor::write_cell(
  self : PageListReflowCursor,
  cell : PageCellState,
) -> PageListReflowWriteResult {
  match cell.wide() {
    PageCellWide::Narrow => {
      self.node.page.cells[self.x] = copy_scrollback_cell(cell)
      self.cursor_forward()
      PageListReflowWriteResult::Success
    }
    PageCellWide::Wide =>
      if self.cols.to_int() > 1 {
        if self.x == self.cols.to_int() - 1 {
          self.node.page.cells[self.x] = reflow_spacer_head_cell()
          self.cursor_forward()
          PageListReflowWriteResult::Repeat
        } else {
          self.node.page.cells[self.x] = copy_scrollback_cell(cell)
          self.cursor_forward()
          PageListReflowWriteResult::Success
        }
      } else {
        self.node.page.cells[self.x] = PageCellState::new()
        self.cursor_forward()
        PageListReflowWriteResult::SkipNext
      }
    PageCellWide::SpacerTail =>
      if self.cols.to_int() > 1 {
        self.node.page.cells[self.x] = copy_scrollback_cell(cell)
        self.cursor_forward()
        PageListReflowWriteResult::Success
      } else {
        PageListReflowWriteResult::Success
      }
    PageCellWide::SpacerHead => PageListReflowWriteResult::Success
  }
}

///|
fn PageListReflowCursor::cursor_forward(self : PageListReflowCursor) -> Unit {
  if self.x == self.cols.to_int() - 1 {
    self.pending_wrap = true
  } else {
    self.x += 1
  }
}

///|
fn PageListReflowCursor::cursor_scroll_or_new_page(
  self : PageListReflowCursor,
  list : PageList,
) -> Unit {
  let row = self.row()
  apply_cell_flags_to_row(row.row, row.cells)
  self.rows.push(row)
  self.row_id = list.allocate_row_id()
  self.node = PageListNode::new(PageListPage::new(1, self.cols))
  self.x = 0
  self.pending_wrap = false
  self.total_rows = self.rows.length() + 1
}

///|
fn PageListReflowCursor::copy_row_metadata(
  self : PageListReflowCursor,
  row : PageRowState,
) -> Unit {
  self.node.page.row_states[0].set_semantic_prompt(row.semantic_prompt())
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
  let scrollback = PageList::new(rows, cols, max_scrollback)
  {
    grid: scrollback.active_grid(),
    cursor: TerminalCursorState::new(rows, cols),
    saved_cursor: ScreenSavedCursorState::new(),
    scrollback,
    kitty_graphics: KittyGraphicsState::new(),
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
          let pin = self.tracked_pins[pin_index]
          if pin.garbage {
            return None
          }
          let x = scrollback_clamp_int(pin.x, 0, cols.to_int() - 1)
          if physical_equal(pin.node, self.active_node) {
            let y = pin.y.to_int()
            if y >= 0 && y < rows.length() {
              return Some({ x: x.to_uint16(), y: pin.y })
            }
          }
          for row_idx in 0..<rows.length() {
            if physical_equal(rows[row_idx].node, pin.node) &&
              rows[row_idx].y == pin.y {
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
  let display_row = top_abs + row_idx
  if display_row < history_rows {
    Some(PageListRowSource::History(display_row))
  } else {
    Some(PageListRowSource::Screen(display_row - history_rows))
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
  let display_row = match self.row_source_by_id(row_id) {
    Some(PageListRowSource::History(index)) => index
    Some(PageListRowSource::Screen(index)) => self.history.length() + index
    None => return None
  }

  let top = self.viewport_row_offset()
  let bottom = top + grid.rows.to_int()
  if display_row < top || display_row >= bottom {
    None
  } else {
    Some(display_row - top)
  }
}

///|
fn PageList::viewport_row_offset(self : PageList) -> Int {
  match self.viewport {
    PageListViewport::Top => 0
    PageListViewport::Active => self.history.length()
    PageListViewport::Pin =>
      match self.viewport_pin_row_offset {
        Some(offset) => scrollback_clamp_int(offset, 0, self.history.length())
        None =>
          match self.tracked_pin_index(self.viewport_pin) {
            Some(index) =>
              if !self.tracked_pins[index].garbage {
                match self.pin_row_offset(self.tracked_pins[index]) {
                  Some(row) => {
                    let offset = scrollback_clamp_int(
                      row,
                      0,
                      self.history.length(),
                    )
                    self.viewport_pin_row_offset = Some(offset)
                    offset
                  }
                  None => {
                    self.viewport = PageListViewport::Active
                    self.history.length()
                  }
                }
              } else {
                self.viewport = PageListViewport::Active
                self.history.length()
              }
            None => {
              self.viewport = PageListViewport::Active
              self.history.length()
            }
          }
      }
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
    self.viewport = PageListViewport::Active
    self.viewport_pin_row_offset = None
    self.relink_nodes()
    return
  }

  self.relink_nodes()
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
  match self.viewport {
    PageListViewport::Pin => {
      let _ = self.viewport_row_offset()
    }
    _ => ()
  }
  self.history = trimmed
  self.relink_nodes()
  self.fixup_viewport(excess)
  self.mark_pins_for_rows_garbage(removed)
}

///|
fn PageList::shift_visible_row_ids_top_region_up(
  self : PageList,
  bottom : Int,
  count : Int,
) -> Unit {
  let row_count = self.visible_row_ids.length()
  let removed_count = min_int(count, bottom + 1)
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
  for index in 0..<self.tracked_pins.length() {
    if physical_equal(self.tracked_pins[index].node, self.active_node) &&
      !self.tracked_pins[index].garbage {
      let y = self.tracked_pins[index].y.to_int()
      if y <= bottom {
        if y >= count {
          self.tracked_pins[index].y = (y - count).to_uint16()
        } else if self.max_rows <= 0 && y < removed_count {
          self.mark_pin_garbage(index)
        }
      }
    }
  }
}

///|
fn PageList::shift_visible_row_ids_down(self : PageList, count : Int) -> Unit {
  let row_count = self.visible_row_ids.length()
  let keep = row_count - count
  let shifted : Array[UInt64] = []
  for _ in 0..<count {
    shifted.push(self.next_row_id)
    self.next_row_id += 1UL
  }
  for index in 0..<keep {
    shifted.push(self.visible_row_ids[index])
  }
  self.visible_row_ids = shifted
  for index in 0..<self.tracked_pins.length() {
    if physical_equal(self.tracked_pins[index].node, self.active_node) &&
      !self.tracked_pins[index].garbage {
      let y = self.tracked_pins[index].y.to_int()
      if y >= keep {
        self.mark_pin_garbage(index)
      } else {
        self.tracked_pins[index].y = (y + count).to_uint16()
      }
    }
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
  make_pinned_row(
    row_id,
    grid.row_states[row_idx],
    cells,
    grid.cols,
    grid.row_states[row_idx].wrap(),
    grid.row_states[row_idx].wrap_continuation(),
    false,
  )
}

///|
fn PageList::trim_trailing_blank_rows(
  self : PageList,
  rows : Array[PageListRow],
  max : Int,
) -> Int {
  let mut trimmed = 0
  let mut index = rows.length()
  while index > 0 && trimmed < max {
    let row = rows[index - 1]
    if pinned_row_has_text_any(row) || self.pinned_row_is_tracked(row) {
      return trimmed
    }
    trimmed += 1
    index -= 1
  }
  trimmed
}

///|
fn PageList::pinned_row_is_tracked(self : PageList, row : PageListRow) -> Bool {
  for pin in self.tracked_pins {
    if !pin.garbage && physical_equal(pin.node, row.node) && pin.y == row.y {
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
fn pinned_row_has_text_any(row : PageListRow) -> Bool {
  for cell in row.cells {
    if cell.has_text() {
      return true
    }
  }
  false
}

///|
fn copy_pinned_row(source : PageListRow, cols : CellCountInt) -> PageListRow {
  let copied = make_pinned_row(
    source.row_id,
    source.row,
    source.cells,
    cols,
    source.row.wrap(),
    source.row.wrap_continuation(),
    false,
  )
  {
    row_id: copied.row_id,
    row: copied.row,
    cells: copied.cells,
    node: source.node,
    y: source.y,
  }
}

///|
fn make_pinned_row(
  row_id : UInt64,
  row_template : PageRowState,
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
  let row = copy_scrollback_row(row_template)
  row.set_wrap(wrap)
  row.set_wrap_continuation(wrap_continuation)
  if update_prompt_continuation &&
    wrap_continuation &&
    row.semantic_prompt() == RowSemanticPrompt::Prompt {
    row.set_semantic_prompt(RowSemanticPrompt::PromptContinuation)
  }
  apply_cell_flags_to_row(row, cells)
  let row_states : Array[PageRowState] = []
  row_states.push(row)
  let node = PageListNode::new({ rows: 1, cols, row_states, cells })
  { row_id, row, cells, node, y: 0 }
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
