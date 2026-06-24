///|
pub(all) enum TerminalScreen {
  Primary
  Alternate
} derive(Eq, Debug)

///|
priv struct PageListPage {
  rows : @size.CellCountInt
  cols : @size.CellCountInt
  // Parallel per-row arrays, mirroring `ScreenGridState`: `descs[i]`/`cells[i]`
  // are row `i`'s descriptor and cell buffer. The active page shares these
  // arrays with the grid by reference (see `active_grid`).
  descs : FixedArray[@page.PageRowState]
  cells : FixedArray[FixedArray[@page.PageCellState]]
  // Per-row hyperlink ids, parallel to `cells` (see `ScreenGridState.link_ids`).
  // Shared with the active grid by reference, exactly like `cells`.
  link_ids : FixedArray[FixedArray[@hyperlink.HyperlinkId]?]
}

///|
priv struct PageListNode {
  page : PageListPage
}

///|
priv struct PageListRow {
  mut row : @page.PageRowState
  cells : FixedArray[@page.PageCellState]
  // The row's hyperlink ids keyed by column, or `None` when the row has no links
  // (the common case). Mirrors `ScreenGridState.link_ids`'s per-row entry; travels
  // with `cells` when the row moves between the active grid and history.
  link_ids : FixedArray[@hyperlink.HyperlinkId]?
  node : PageListNode
  y : @size.CellCountInt
}

///|
priv enum PageListRowSource {
  History(Int)
  Screen(Int)
}

///|
priv struct PageListPoint {
  x : @size.CellCountInt
  y : @size.CellCountInt
}

///|
priv struct PageListResizeResult {
  grid : ScreenGridState
  cursor : PageListPoint?
  saved_cursor : PageListPoint?
}

///|
priv struct PageListPin {
  mut node : PageListNode
  mut y : @size.CellCountInt
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
  mut rows : @size.CellCountInt
  mut cols : @size.CellCountInt
  mut active_node : PageListNode
  mut history : @deque.Deque[PageListRow]
  mut viewport : PageListViewport
  mut tracked_pins : Array[PageListPin]
  mut viewport_pin : PageListPin?
  mut viewport_pin_row_offset : Int?
  // The single style intern table for this screen, shared by reference into every
  // grid view (`active_grid`, resize results) and used to resolve scrollback-row
  // styles. Owned here because the `PageList` owns both the active page and the
  // history; one table keeps a cell's `StyleId` valid as its row scrolls between
  // them. Primary and alternate screens have distinct `PageList`s and thus
  // distinct tables, which is fine — cells never migrate between them.
  // `mut` only so `full_reset` can swap in fresh empty tables once the screen is
  // wholly cleared (see there); steady-state printing never reassigns them.
  mut style_table : @style.StyleTable
  // The hyperlink intern table, owned and shared exactly like `style_table`.
  mut hyperlink_table : @hyperlink.HyperlinkTable
  // The grapheme intern table, owned and shared exactly like `style_table`.
  mut grapheme_table : @page.GraphemeTable
}

///|
priv struct TerminalScreenStorage {
  mut grid : ScreenGridState
  mut cursor : @cursor.TerminalCursorState
  saved_cursor : ScreenSavedCursorState
  mut scrollback : PageList
  mut kitty_graphics : KittyGraphicsState
  // Semantic-prompt state is per-screen: the alternate screen used by
  // fullscreen apps must not inherit the primary screen's OSC 133 zones,
  // and its rows must not be stamped with the primary's leftover prompt
  // state. Swapped alongside grid/cursor/scrollback in load/store.
  mut semantic : ScreenSemanticState
}

///|
priv enum PageListReflowWriteResult {
  Success
  Repeat
  SkipNext
}

///|
priv struct PageListReflowCursor {
  cols : @size.CellCountInt
  rows : Array[PageListRow]
  mut node : PageListNode
  mut x : Int
  mut pending_wrap : Bool
  mut new_rows : Int
  mut total_rows : Int
}

///|
priv struct PageListPreservedCursor {
  tracked_pin : PageListPin
  remaining_rows : Int
  wrapped_rows : Int
}

///|
fn PageListPage::new(
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
) -> PageListPage {
  let actual_rows = screen_dimension(rows)
  let actual_cols = screen_dimension(cols)
  let descs : FixedArray[@page.PageRowState] = FixedArray::makei(
    actual_rows.to_int(),
    _ => @page.PageRowState::new(),
  )
  let cells : FixedArray[FixedArray[@page.PageCellState]] = FixedArray::makei(
    actual_rows.to_int(),
    _ => make_row_cells(actual_cols.to_int()),
  )
  {
    rows: actual_rows,
    cols: actual_cols,
    descs,
    cells,
    link_ids: FixedArray::make(actual_rows.to_int(), None),
  }
}

///|
fn PageListNode::new(page : PageListPage) -> PageListNode {
  { page, }
}

///|
fn PageList::new(
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
  max_rows : Int,
) -> PageList {
  let active_node = PageListNode::new(PageListPage::new(rows, cols))
  let state = {
    max_rows,
    rows: active_node.page.rows,
    cols: active_node.page.cols,
    active_node,
    history: @deque.Deque::from_array(([] : Array[PageListRow])),
    viewport: Active,
    tracked_pins: [],
    viewport_pin: None,
    viewport_pin_row_offset: None,
    style_table: @style.StyleTable::new(),
    hyperlink_table: @hyperlink.HyperlinkTable::new(),
    grapheme_table: @page.GraphemeTable::new(),
  }
  state.viewport_pin = Some(state.track_pin(active_node, 0, 0))
  state
}

///|
fn PageList::active_grid(self : PageList) -> ScreenGridState {
  // Shares the active page's `descs`/`cells` arrays by reference, so grid
  // mutations (writes, scroll moves) are seen by the page and vice versa.
  {
    rows: self.active_node.page.rows,
    cols: self.cols,
    descs: self.active_node.page.descs,
    cells: self.active_node.page.cells,
    link_ids: self.active_node.page.link_ids,
    cell_pool: [],
    style_table: self.style_table,
    hyperlink_table: self.hyperlink_table,
    grapheme_table: self.grapheme_table,
  }
}

///|
fn PageList::scrollback_rows(self : PageList) -> UInt {
  self.history.length().reinterpret_as_uint()
}

///|
fn PageList::total_rows(
  self : PageList,
  visible_rows : @size.CellCountInt,
) -> UInt {
  visible_rows.to_uint() + self.scrollback_rows()
}

///|
fn PageList::scrollbar(
  self : PageList,
  visible_rows : @size.CellCountInt,
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
  row : @size.CellCountInt,
) -> @page.PageRowState? {
  match self.visible_row_source(grid.rows.to_int(), row.to_int()) {
    Some(History(index)) => Some(self.history[index].row)
    Some(Screen(index)) => Some(grid.descs[index])
    None => None
  }
}

///|
fn PageList::cell(
  self : PageList,
  grid : ScreenGridState,
  row : @size.CellCountInt,
  col : @size.CellCountInt,
) -> @page.PageCellState? {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }

  match self.visible_row_source(grid.rows.to_int(), row.to_int()) {
    Some(History(index)) => Some(self.history[index].cells[col_idx])
    Some(Screen(index)) => Some(grid.cells[index][col_idx])
    None => None
  }
}

///|
fn PageList::screen_row(
  self : PageList,
  grid : ScreenGridState,
  row : @size.CellCountInt,
) -> @page.PageRowState? {
  match self.screen_row_source(grid, row.to_int()) {
    Some(History(index)) => Some(self.history[index].row)
    Some(Screen(index)) => Some(grid.descs[index])
    None => None
  }
}

///|
fn PageList::screen_cell(
  self : PageList,
  grid : ScreenGridState,
  row : @size.CellCountInt,
  col : @size.CellCountInt,
) -> @page.PageCellState? {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }

  match self.screen_row_source(grid, row.to_int()) {
    Some(History(index)) => Some(self.history[index].cells[col_idx])
    Some(Screen(index)) => Some(grid.cells[index][col_idx])
    None => None
  }
}

///|
/// Resolve the hyperlink id at a visible `(row, col)` from whichever source — the
/// active grid or a history row — backs it. The id lives in that source's
/// `link_ids` side array, not in the cell.
///
/// Gated on the cell's `has_hyperlink()` presence bit: the side array deliberately
/// keeps dead entries under cells whose presence bit was cleared (a link-free
/// overwrite, clear, or region copy never scrubs the old id), so resolving without
/// the gate would report a stale OSC 8 link for an unlinked cell. The bit is the
/// source of truth; the array is read only when it is set.
fn PageList::link_id_at_source(
  self : PageList,
  grid : ScreenGridState,
  source : PageListRowSource,
  col_idx : Int,
) -> @hyperlink.HyperlinkId {
  match source {
    History(index) => {
      let row = self.history[index]
      if !row.cells[col_idx].has_hyperlink() {
        return @hyperlink.no_hyperlink_id
      }
      match row.link_ids {
        Some(links) => links[col_idx]
        None => @hyperlink.no_hyperlink_id
      }
    }
    Screen(index) =>
      if grid.cells[index][col_idx].has_hyperlink() {
        grid.link_id_at(index, col_idx)
      } else {
        @hyperlink.no_hyperlink_id
      }
  }
}

///|
fn PageList::cell_hyperlink(
  self : PageList,
  grid : ScreenGridState,
  row : @size.CellCountInt,
  col : @size.CellCountInt,
) -> @hyperlink.CellHyperlink? {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }
  match self.visible_row_source(grid.rows.to_int(), row.to_int()) {
    Some(source) =>
      self.hyperlink_table.get(self.link_id_at_source(grid, source, col_idx))
    None => None
  }
}

///|
/// The raw (gated) `@hyperlink.HyperlinkId` at a visible `(row, col)` — the cheap u16 key the
/// render-snapshot diff compares to notice a hyperlink-only change (the packed
/// cell carries only a presence bit, so two cells under different URIs are equal).
/// Uses the same visible source as `cell` so it lines up with the render cell
/// snapshot. Returns `@hyperlink.no_hyperlink_id` for an unlinked cell.
fn PageList::cell_hyperlink_id(
  self : PageList,
  grid : ScreenGridState,
  row : @size.CellCountInt,
  col : @size.CellCountInt,
) -> @hyperlink.HyperlinkId {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return @hyperlink.no_hyperlink_id
  }
  match self.visible_row_source(grid.rows.to_int(), row.to_int()) {
    Some(source) => self.link_id_at_source(grid, source, col_idx)
    None => @hyperlink.no_hyperlink_id
  }
}

///|
fn PageList::screen_cell_hyperlink(
  self : PageList,
  grid : ScreenGridState,
  row : @size.CellCountInt,
  col : @size.CellCountInt,
) -> @hyperlink.CellHyperlink? {
  let col_idx = col.to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }
  match self.screen_row_source(grid, row.to_int()) {
    Some(source) =>
      self.hyperlink_table.get(self.link_id_at_source(grid, source, col_idx))
    None => None
  }
}

///|
fn PageList::scroll_top(self : PageList) -> Unit {
  if self.max_rows <= 0 {
    self.viewport = Active
  } else {
    self.viewport = Top
  }
  self.viewport_pin_row_offset = None
}

///|
fn PageList::scroll_bottom(self : PageList) -> Unit {
  self.viewport = Active
  self.viewport_pin_row_offset = None
}

///|
fn PageList::scroll_delta(self : PageList, delta : Int) -> Unit {
  if self.max_rows <= 0 {
    self.viewport = Active
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
      let row = harvest_scrollback_row(grid, row_idx)
      self.move_pins_for_row(
        self.active_node,
        row_idx.to_uint16(),
        row.node,
        row.y,
      )
      self.history.push_back(row)
      row_idx += 1
    }

    // Recycle the cells of rows evicted here as the blank rows the grid shift
    // (which runs immediately after this capture) scrolls in at the bottom — at
    // a full buffer this makes the line feed allocation-free.
    for evicted in self.trim_history() {
      grid.recycle_row_cells(evicted.cells)
    }
  } else {
    self.viewport = Active
    self.viewport_pin_row_offset = None
  }

  self.shift_active_pins_top_region_up(bottom, count)
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

  self.shift_active_pins_down(count)
}

///|
fn PageList::full_reset(self : PageList, _rows : @size.CellCountInt) -> Unit {
  self.history.clear()
  self.viewport = Active
  self.viewport_pin_row_offset = None
  for index in 0..<self.tracked_pins.length() {
    self.mark_pin_garbage(index)
  }
  // The history is now empty and the caller (`clear_active_screen`) has already
  // blanked the active grid, so no cell — in this list or its grid views — still
  // references an interned id. Reclaim the grow-only intern tables by minting
  // fresh empty ones; otherwise repeated full clears (e.g. DECSET 1049 alt-screen
  // churn that prints many distinct styles/links/grapheme runs) keep consuming
  // 16-bit ids for content that no longer exists and eventually exhaust them,
  // degrading later cells to default/no-link/dropped-marks on an empty screen.
  // We mint *new* tables rather than clearing in place on purpose: the swap flips
  // their identity, which `RenderState` keys on (`physical_equal`) to force a
  // repaint after the reset — an in-place clear that reused the same low ids for
  // new content would otherwise read as unchanged. The grid still holds the old
  // table refs it copied at construction, so `clear_active_screen` rebuilds it
  // from the page to pick these up.
  self.style_table = @style.StyleTable::new()
  self.hyperlink_table = @hyperlink.HyperlinkTable::new()
  self.grapheme_table = @page.GraphemeTable::new()
}

///|
fn PageList::clear_history(self : PageList) -> Unit {
  for row in self.history {
    self.mark_pins_for_row_garbage(row)
  }
  self.history.clear()
  self.viewport = Active
  self.viewport_pin_row_offset = None
}

///|
fn PageList::track_pin(
  self : PageList,
  node : PageListNode,
  y : @size.CellCountInt,
  x : Int,
) -> PageListPin {
  let pin = { node, y, x, garbage: false }
  self.tracked_pins.push(pin)
  pin
}

///|
fn PageList::pin(
  self : PageList,
  grid : ScreenGridState,
  point : @point.Point,
) -> PageListPin? {
  self.track_pin_at_point(grid, point)
}

///|
fn PageList::track_pin_at_point(
  self : PageList,
  grid : ScreenGridState,
  point : @point.Point,
) -> PageListPin? {
  let x = point.coord().x().to_int()
  if x < 0 || x >= grid.cols.to_int() {
    return None
  }
  match self.row_source_for_point(grid, point) {
    Some(History(index)) =>
      Some(self.track_pin(self.history[index].node, self.history[index].y, x))
    Some(Screen(index)) =>
      Some(self.track_pin(self.active_node, index.to_uint16(), x))
    None => None
  }
}

///|
fn PageList::untrack_pin(self : PageList, pin : PageListPin) -> Unit {
  let next : Array[PageListPin] = []
  for tracked in self.tracked_pins {
    if !physical_equal(tracked, pin) {
      next.push(tracked)
    }
  }
  self.tracked_pins = next
}

///|
fn PageList::tracked_pin_index(self : PageList, pin : PageListPin) -> Int? {
  for index in 0..<self.tracked_pins.length() {
    if physical_equal(self.tracked_pins[index], pin) {
      return Some(index)
    }
  }
  None
}

///|
fn PageList::point_from_pin(
  self : PageList,
  grid : ScreenGridState,
  pin : PageListPin,
  tag : @point.Tag,
) -> @point.Coordinate? {
  match self.tracked_pin_index(pin) {
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
fn PageList::pin_from_tracked_pin(
  self : PageList,
  pin : PageListPin,
) -> PageListPin? {
  match self.tracked_pin_index(pin) {
    Some(index) => {
      let pin = self.tracked_pins[index]
      if pin.garbage {
        None
      } else {
        Some(self.track_pin(pin.node, pin.y, pin.x))
      }
    }
    None => None
  }
}

///|
fn PageList::point_from_pin_ref(
  self : PageList,
  grid : ScreenGridState,
  pin : Pin,
  tag : @point.Tag,
) -> @point.Coordinate? {
  self.point_from_pin(grid, pin.pin, tag)
}

///|
fn PageList::untrack_pin_ref(self : PageList, pin : Pin) -> Unit {
  self.untrack_pin(pin.pin)
}

///|
fn PageList::pin_x(self : PageList, pin : PageListPin) -> @size.CellCountInt? {
  match self.tracked_pin_index(pin) {
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
  tag : @point.Tag,
) -> @point.Coordinate? {
  let x = pin.x.to_uint16()
  match self.row_source_for_pin(pin) {
    Some(source) => self.point_from_source(grid, source, x, tag)
    None => None
  }
}

///|
fn PageList::point_from_source(
  self : PageList,
  grid : ScreenGridState,
  source : PageListRowSource,
  x : @size.CellCountInt,
  tag : @point.Tag,
) -> @point.Coordinate? {
  match source {
    History(index) =>
      match tag {
        Active => None
        Viewport =>
          self
          .viewport_index_for_source(grid, source)
          .map(fn(row) { @point.Coordinate::new(x, row.reinterpret_as_uint()) })
        Screen => Some(@point.Coordinate::new(x, index.reinterpret_as_uint()))
        History => Some(@point.Coordinate::new(x, index.reinterpret_as_uint()))
      }
    Screen(index) =>
      match tag {
        Active => Some(@point.Coordinate::new(x, index.reinterpret_as_uint()))
        Viewport =>
          self
          .viewport_index_for_source(grid, source)
          .map(fn(row) { @point.Coordinate::new(x, row.reinterpret_as_uint()) })
        Screen =>
          Some(
            @point.Coordinate::new(
              x,
              (self.history.length() + index).reinterpret_as_uint(),
            ),
          )
        History => None
      }
  }
}

///|
fn PageList::row_source_for_pin(
  self : PageList,
  pin : PageListPin,
) -> PageListRowSource? {
  if physical_equal(pin.node, self.active_node) {
    let index = pin.y.to_int()
    if index >= 0 && index < self.rows.to_int() {
      return Some(Screen(index))
    }
    return None
  }

  for index in 0..<self.history.length() {
    if physical_equal(pin.node, self.history[index].node) &&
      pin.y == self.history[index].y {
      return Some(History(index))
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
    History(index) => index
    Screen(index) => self.history.length() + index
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
  cursor_pin : PageListPin?,
) -> PageListPreservedCursor? {
  match cursor_pin {
    Some(pin) =>
      match self.tracked_pin_index(pin) {
        Some(pin_index) => {
          let pin = self.tracked_pins[pin_index]
          match self.point_from_pin_node(grid, pin, Active) {
            Some(point) => {
              let y = point.y().reinterpret_as_int()
              Some({
                tracked_pin: pin,
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
    Some(Screen(index)) => {
      let mut wrapped = 0
      for row_idx in 0..<=index {
        if row_idx < grid.descs.length() &&
          grid.descs[row_idx].wrap_continuation() {
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
  source_y : @size.CellCountInt,
  source_x : Int,
  target_node : PageListNode,
  target_y : @size.CellCountInt,
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
  source_y : @size.CellCountInt,
  target_node : PageListNode,
  target_y : @size.CellCountInt,
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
fn PageList::clamp_pins_to_cols(
  self : PageList,
  cols : @size.CellCountInt,
) -> Unit {
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
  match self.viewport_pin {
    Some(viewport_pin) =>
      if physical_equal(self.tracked_pins[index], viewport_pin) {
        self.tracked_pins[index].node = self.active_node
        self.tracked_pins[index].y = 0
        self.tracked_pins[index].x = 0
        self.tracked_pins[index].garbage = false
        return
      }
    None => ()
  }
  self.tracked_pins[index].node = self.active_node
  self.tracked_pins[index].y = 0
  self.tracked_pins[index].x = 0
  self.tracked_pins[index].garbage = true
}

///|
fn PageList::tracked_viewport_pin_index(self : PageList) -> Int? {
  match self.viewport_pin {
    Some(pin) => self.tracked_pin_index(pin)
    None => None
  }
}

///|
fn PageList::reset_tracked_viewport_pin(
  self : PageList,
  row : PageListRow,
) -> Bool {
  match self.tracked_viewport_pin_index() {
    Some(index) => {
      self.tracked_pins[index].node = row.node
      self.tracked_pins[index].y = row.y
      self.tracked_pins[index].x = 0
      self.tracked_pins[index].garbage = false
      true
    }
    None => false
  }
}

///|
fn PageList::reset_or_create_viewport_pin(
  self : PageList,
  row : PageListRow,
) -> Unit {
  if !self.reset_tracked_viewport_pin(row) {
    self.viewport_pin = Some(self.track_pin(row.node, row.y, 0))
  }
}

///|
fn PageList::set_viewport_row_offset(self : PageList, row : Int) -> Unit {
  if self.max_rows <= 0 {
    self.viewport = Active
    self.viewport_pin_row_offset = None
    return
  }
  let top = scrollback_clamp_int(row, 0, self.history.length())
  if top >= self.history.length() {
    self.viewport = Active
    self.viewport_pin_row_offset = None
  } else if top == 0 {
    self.viewport = Top
    self.viewport_pin_row_offset = None
  } else {
    let row = self.history[top]
    self.set_viewport_pin(row)
    self.viewport = Pin
    self.viewport_pin_row_offset = Some(top)
  }
}

///|
fn PageList::pin_is_active(self : PageList, pin : PageListPin) -> Bool {
  match self.row_source_for_pin(pin) {
    Some(Screen(_)) => true
    _ => false
  }
}

///|
fn PageList::fixup_viewport(self : PageList, removed : Int) -> Unit {
  match self.viewport {
    Active => ()
    Pin =>
      match self.tracked_viewport_pin_index() {
        Some(index) =>
          if self.pin_is_active(self.tracked_pins[index]) {
            self.viewport = Active
            self.viewport_pin_row_offset = None
          } else {
            match self.viewport_pin_row_offset {
              Some(offset) =>
                if offset < removed {
                  self.viewport = Top
                  self.viewport_pin_row_offset = None
                } else {
                  self.viewport_pin_row_offset = Some(offset - removed)
                }
              None => ()
            }
          }
        None => {
          self.viewport = Active
          self.viewport_pin_row_offset = None
        }
      }
    Top =>
      // The viewport sits at the top of history; if history is now empty it
      // collapses back to the active screen. (Was: first node == active_node.)
      if self.history.is_empty() {
        self.viewport = Active
        self.viewport_pin_row_offset = None
      }
  }
}

///|
fn PageList::pin_row_offset(self : PageList, pin : PageListPin) -> Int? {
  // A pin's absolute row offset: history rows precede the active screen, so a
  // history pin maps to its history index and an active pin to
  // history.length() + its screen row. Same mapping as
  // viewport_index_for_source; replaces the old backward node-list walk.
  match self.row_source_for_pin(pin) {
    Some(History(index)) => Some(index)
    Some(Screen(index)) => Some(self.history.length() + index)
    None => None
  }
}

///|
fn PageList::set_viewport_pin(self : PageList, row : PageListRow) -> Unit {
  self.reset_or_create_viewport_pin(row)
}

///|
fn PageList::resize(
  self : PageList,
  grid : ScreenGridState,
  cols : @size.CellCountInt,
  rows : @size.CellCountInt,
  cursor : @cursor.TerminalCursorState,
  saved_cursor : ScreenSavedCursor?,
) -> PageListResizeResult {
  let target_cols = screen_dimension(cols)
  let target_rows = screen_dimension(rows)
  self.viewport_pin_row_offset = None
  let cursor_pin = self.track_pin_at_point(
    grid,
    Active(@point.Coordinate::new(cursor.x(), cursor.y().to_uint())),
  )
  let saved_pin = match saved_cursor {
    Some(saved) =>
      self.track_pin_at_point(
        grid,
        Active(@point.Coordinate::new(saved.x(), saved.y().to_uint())),
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
    Some(pin) => self.untrack_pin(pin)
    None => ()
  }
  match saved_pin {
    Some(pin) => self.untrack_pin(pin)
    None => ()
  }
  result
}

///|
fn PageList::resize_without_reflow(
  self : PageList,
  grid : ScreenGridState,
  cols : @size.CellCountInt,
  rows : @size.CellCountInt,
  cursor : @cursor.TerminalCursorState,
  cursor_pin : PageListPin?,
  saved_pin : PageListPin?,
) -> PageListResizeResult {
  if cols < grid.cols {
    self.clamp_pins_to_cols(cols)
  }
  if cols != grid.cols {
    let resized_history : Array[PageListRow] = []
    self.history.each(row => {
      let resized = make_pinned_row(
        row.row,
        row.cells,
        row.link_ids,
        cols,
        row.row.wrap(),
        row.row.wrap_continuation(),
        false,
      )
      self.move_pins_for_row(row.node, row.y, resized.node, resized.y)
      resized_history.push(resized)
    })
    self.history = @deque.Deque::from_array(resized_history)
  }

  let active_rows : Array[PageListRow] = []
  for row_idx in 0..<grid.rows.to_int() {
    let row = snapshot_scrollback_row(grid, row_idx)
    active_rows.push({
      row: row.row,
      cells: row.cells,
      link_ids: row.link_ids,
      node: self.active_node,
      y: row_idx.to_uint16(),
    })
  }

  let target_rows = rows.to_int()
  let current_rows = active_rows.length()
  let grid_rows : Array[PageListRow] = []

  if target_rows < current_rows {
    let max_trim = current_rows - target_rows
    let trimmed = self.trim_trailing_blank_rows(active_rows, max_trim)
    let remaining = current_rows - trimmed
    // Match upstream PageList.resizeWithoutReflow: row shrink keeps the bottom
    // active rows after trailing blank trim. Cursor pins moved into history
    // stop resolving as active and reload to active top-left.
    let history_count = max_int(0, remaining - target_rows)

    for index in 0..<history_count {
      let source = active_rows[index]
      if self.max_rows > 0 {
        let history_row = make_pinned_row(
          source.row,
          source.cells,
          source.link_ids,
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
        self.history.push_back(history_row)
      } else {
        self.mark_pins_for_row_garbage(source)
      }
    }

    for index in history_count..<remaining {
      let row = copy_pinned_row(active_rows[index], cols)
      grid_rows.push(row)
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
      self.history = @deque.Deque::from_array(history_rows)
    }

    for index in 0..<pulled_rows.length() {
      grid_rows.push(pulled_rows[index])
    }
    for index in 0..<active_rows.length() {
      grid_rows.push(copy_pinned_row(active_rows[index], cols))
    }
    for _ in 0..<(grow_count - pull_count) {
      let row = make_pinned_row(
        @page.PageRowState::new(),
        [],
        None,
        cols,
        false,
        false,
        false,
      )
      grid_rows.push(row)
    }
  } else {
    for index in 0..<active_rows.length() {
      grid_rows.push(copy_pinned_row(active_rows[index], cols))
    }
  }

  self.trim_history() |> ignore

  let resized_grid = screen_grid_from_rows(
    rows,
    cols,
    grid_rows,
    self.style_table,
    self.hyperlink_table,
    self.grapheme_table,
  )
  let active_node = PageListNode::new({
    rows: resized_grid.rows,
    cols: resized_grid.cols,
    descs: resized_grid.descs,
    cells: resized_grid.cells,
    link_ids: resized_grid.link_ids,
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
  cols : @size.CellCountInt,
  cursor_pin : PageListPin?,
  saved_pin : PageListPin?,
) -> PageListResizeResult {
  let preserved_cursor = self.preserved_cursor(grid, cursor_pin)
  self.cols = cols

  let source_rows : Array[PageListRow] = []
  for row in self.history {
    source_rows.push(row)
  }
  for row_idx in 0..<grid.rows.to_int() {
    let row = snapshot_scrollback_row(grid, row_idx)
    source_rows.push({
      row: row.row,
      cells: row.cells,
      link_ids: row.link_ids,
      node: self.active_node,
      y: row_idx.to_uint16(),
    })
  }

  let cursor = PageListReflowCursor::new(cols)
  for row in source_rows {
    cursor.reflow_row(self, row)
  }
  let reflowed = cursor.finish(self)
  while cursor.total_rows < self.rows.to_int() {
    reflowed.push(
      make_pinned_row(
        @page.PageRowState::new(),
        [],
        None,
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
            if desired > bottom_start {
              let mut rows_to_append = desired - bottom_start
              while rows_to_append > 0 {
                reflowed.push(
                  make_pinned_row(
                    @page.PageRowState::new(),
                    [],
                    None,
                    cols,
                    false,
                    false,
                    false,
                  ),
                )
                rows_to_append -= 1
              }
              desired
            } else {
              scrollback_clamp_int(desired, 0, bottom_start)
            }
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
  self.history = @deque.Deque::from_array(history_rows)
  // Reflow rebuilds the grid with a fresh pool, so evicted rows aren't recycled.
  self.trim_history() |> ignore

  let grid_rows : Array[PageListRow] = []
  for index in active_start..<active_end {
    grid_rows.push(reflowed[index])
  }

  let resized_grid = screen_grid_from_rows(
    self.rows,
    cols,
    grid_rows,
    self.style_table,
    self.hyperlink_table,
    self.grapheme_table,
  )
  let active_node = PageListNode::new({
    rows: resized_grid.rows,
    cols: resized_grid.cols,
    descs: resized_grid.descs,
    cells: resized_grid.cells,
    link_ids: resized_grid.link_ids,
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

  {
    grid: resized_grid,
    cursor: self.page_point_from_pin_rows(grid_rows, cols, cursor_pin),
    saved_cursor: self.page_point_from_pin_rows(grid_rows, cols, saved_pin),
  }
}

///|
fn PageListReflowCursor::new(cols : @size.CellCountInt) -> PageListReflowCursor {
  {
    cols,
    rows: [],
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
    row: self.node.page.descs[0],
    cells: self.node.page.cells[0],
    link_ids: self.node.page.link_ids[0],
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
    row.recompute_cell_flags()
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
    // Keep trailing cells that carry a background color: they are `is_empty()`
    // (no glyph) now that bg lives in the style, but `has_styling()` is true.
    while cols_len > 0 &&
          source.cells[cols_len - 1].is_empty() &&
          !source.cells[cols_len - 1].has_styling() {
      cols_len -= 1
    }
    if cols_len == 0 && source.row.semantic_prompt() != None {
      cols_len = 1
    }
  }

  let pin_clamp_x = if self.new_rows > 0 { 0 } else { self.x }
  for index in 0..<list.tracked_pins.length() {
    let pin = list.tracked_pins[index]
    if !pin.garbage &&
      physical_equal(pin.node, source.node) &&
      pin.y == source.y {
      if pin.x >= cols_len {
        list.tracked_pins[index].x = min_int(
          pin.x,
          self.cols.to_int() - 1 - pin_clamp_x,
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
    self.cursor_scroll_or_new_page()
    self.new_rows -= 1
  }

  self.copy_row_metadata(source.row)
  let mut x = 0
  while x < cols_len {
    if self.pending_wrap {
      self.node.page.descs[0] = self.node.page.descs[0].with_wrap(true)
      self.cursor_scroll_or_new_page()
      self.copy_row_metadata(source.row)
      let desc = self.node.page.descs[0].with_wrap_continuation(true)
      self.node.page.descs[0] = if desc.semantic_prompt() == Prompt {
        desc.with_semantic_prompt(PromptContinuation)
      } else {
        desc
      }
    }

    let target_node = self.node
    let target_x = self.x
    match self.write_cell(source.cells[x], link_at(source.link_ids, x)) {
      Success => {
        list.move_pins_for_cell(
          source.node,
          source.y,
          x,
          target_node,
          0,
          target_x,
        )
        x += 1
      }
      SkipNext => {
        list.move_pins_for_cell(
          source.node,
          source.y,
          x,
          target_node,
          0,
          target_x,
        )
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
      Repeat => ()
    }
  }

  if !source.row.wrap() {
    self.new_rows += 1
  }
}

///|
fn PageListReflowCursor::write_cell(
  self : PageListReflowCursor,
  cell : @page.PageCellState,
  link_id : @hyperlink.HyperlinkId,
) -> PageListReflowWriteResult {
  match cell.wide() {
    Narrow => {
      self.node.page.cells[0][self.x] = cell
      self.write_link(link_id)
      self.cursor_forward()
      Success
    }
    Wide =>
      if self.cols.to_int() > 1 {
        if self.x == self.cols.to_int() - 1 {
          // The wide char doesn't fit; place a spacer head (no link) and re-emit
          // the real cell — with its link — on the next row (Repeat keeps `x`).
          self.node.page.cells[0][self.x] = reflow_spacer_head_cell()
          self.cursor_forward()
          Repeat
        } else {
          self.node.page.cells[0][self.x] = cell
          self.write_link(link_id)
          self.cursor_forward()
          Success
        }
      } else {
        self.node.page.cells[0][self.x] = @page.PageCellState::new()
        self.cursor_forward()
        SkipNext
      }
    SpacerTail =>
      if self.cols.to_int() > 1 {
        self.node.page.cells[0][self.x] = cell
        self.write_link(link_id)
        self.cursor_forward()
        Success
      } else {
        Success
      }
    SpacerHead => Success
  }
}

///|
/// Store the source cell's hyperlink id at the current column of the row being
/// reflowed, allocating the destination row's link array on first use. A no-op
/// for the common link-free cell — the spacer/blank placeholders never call it.
fn PageListReflowCursor::write_link(
  self : PageListReflowCursor,
  link_id : @hyperlink.HyperlinkId,
) -> Unit {
  if link_id.is_none() {
    return
  }
  let links = match self.node.page.link_ids[0] {
    Some(links) => links
    None => {
      let links = FixedArray::make(
        self.cols.to_int(),
        @hyperlink.no_hyperlink_id,
      )
      self.node.page.link_ids[0] = Some(links)
      links
    }
  }
  links[self.x] = link_id
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
) -> Unit {
  let row = self.row()
  row.recompute_cell_flags()
  self.rows.push(row)
  self.node = PageListNode::new(PageListPage::new(1, self.cols))
  self.x = 0
  self.pending_wrap = false
  self.total_rows = self.rows.length() + 1
}

///|
fn PageListReflowCursor::copy_row_metadata(
  self : PageListReflowCursor,
  row : @page.PageRowState,
) -> Unit {
  // Known upstream bug: PageList.ReflowCursor.copyRowMetadata overwrites
  // semantic_prompt unconditionally. This keeps strict alignment, including
  // prompt-start loss when column-grow reflow merges Prompt and
  // PromptContinuation source rows into one destination row.
  self.node.page.descs[0] = self.node.page.descs[0].with_semantic_prompt(
    row.semantic_prompt(),
  )
}

///|
fn TerminalScreenStorage::resize(
  self : TerminalScreenStorage,
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
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
  cols : @size.CellCountInt,
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
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
  max_scrollback : Int,
) -> TerminalScreenStorage {
  let scrollback = PageList::new(rows, cols, max_scrollback)
  {
    grid: scrollback.active_grid(),
    cursor: @cursor.TerminalCursorState::new(rows, cols),
    saved_cursor: ScreenSavedCursorState::new(),
    scrollback,
    kitty_graphics: KittyGraphicsState::new(),
    semantic: ScreenSemanticState::new(),
  }
}

///|
fn PageList::page_point_from_pin_rows(
  self : PageList,
  rows : Array[PageListRow],
  cols : @size.CellCountInt,
  pin : PageListPin?,
) -> PageListPoint? {
  match pin {
    Some(pin) =>
      match self.tracked_pin_index(pin) {
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
fn PageList::point_from_point(
  self : PageList,
  grid : ScreenGridState,
  point : @point.Point,
  tag : @point.Tag,
) -> @point.Coordinate? {
  let x = point.coord().x()
  let x_idx = x.to_int()
  if x_idx < 0 || x_idx >= grid.cols.to_int() {
    return None
  }

  match self.row_source_for_point(grid, point) {
    Some(source) => self.point_from_source(grid, source, x, tag)
    None => None
  }
}

///|
fn PageList::cell_at_point(
  self : PageList,
  grid : ScreenGridState,
  point : @point.Point,
) -> @page.PageCellState? {
  let col_idx = point.coord().x().to_int()
  if col_idx < 0 || col_idx >= grid.cols.to_int() {
    return None
  }

  match self.row_source_for_point(grid, point) {
    Some(History(index)) => Some(self.history[index].cells[col_idx])
    Some(Screen(index)) => Some(grid.cells[index][col_idx])
    None => None
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
    Some(History(display_row))
  } else {
    Some(Screen(display_row - history_rows))
  }
}

///|
fn PageList::row_source_for_point(
  self : PageList,
  grid : ScreenGridState,
  point : @point.Point,
) -> PageListRowSource? {
  let y = point.coord().y().reinterpret_as_int()
  match point {
    Active(_) => self.active_row_source(grid, y)
    Viewport(_) => self.visible_row_source(grid.rows.to_int(), y)
    Screen(_) => self.screen_row_source(grid, y)
    History(_) => self.history_row_source(y)
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
    Some(Screen(y))
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
    Some(History(y))
  } else if y < history_rows + grid.rows.to_int() {
    Some(Screen(y - history_rows))
  } else {
    None
  }
}

///|
fn PageList::history_row_source(self : PageList, y : Int) -> PageListRowSource? {
  if y < 0 || y >= self.history.length() {
    None
  } else {
    Some(History(y))
  }
}

///|
fn PageList::viewport_row_offset(self : PageList) -> Int {
  match self.viewport {
    Top => 0
    Active => self.history.length()
    Pin =>
      match self.viewport_pin_row_offset {
        Some(offset) => scrollback_clamp_int(offset, 0, self.history.length())
        None =>
          match self.tracked_viewport_pin_index() {
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
                    self.viewport = Active
                    self.history.length()
                  }
                }
              } else {
                self.viewport = Active
                self.history.length()
              }
            None => {
              self.viewport = Active
              self.history.length()
            }
          }
      }
  }
}

///|
/// Returns the rows evicted from the front of history (empty if none), so the
/// caller can recycle their cell arrays. The rows are already dropped from
/// history and their pins marked garbage on return.
fn PageList::trim_history(self : PageList) -> Array[PageListRow] {
  if self.max_rows <= 0 {
    for row in self.history {
      self.mark_pins_for_row_garbage(row)
    }
    self.history.clear()
    self.viewport = Active
    self.viewport_pin_row_offset = None
    return []
  }

  let excess = self.history.length() - self.max_rows
  if excess <= 0 {
    return []
  }

  // Materialize a Pin viewport's offset before the front rows are dropped, so
  // fixup_viewport can shift it by `excess` (indices move down by that much).
  match self.viewport {
    Pin => {
      let _ = self.viewport_row_offset()
    }
    _ => ()
  }
  // Evict the oldest rows from the front of the ring buffer: O(excess) (== 1
  // per line feed once full), not an O(history) array rebuild.
  let removed : Array[PageListRow] = []
  for _ in 0..<excess {
    match self.history.pop_front() {
      Some(row) => removed.push(row)
      None => break
    }
  }
  self.fixup_viewport(excess)
  self.mark_pins_for_rows_garbage(removed)
  removed
}

///|
fn PageList::shift_active_pins_top_region_up(
  self : PageList,
  bottom : Int,
  count : Int,
) -> Unit {
  let removed_count = min_int(count, bottom + 1)
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
fn PageList::shift_active_pins_down(self : PageList, count : Int) -> Unit {
  let row_count = self.rows.to_int()
  let keep = row_count - count
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
) -> PageListRow {
  // Gather the row's cells by reference; make_pinned_row performs the single
  // deep copy into the history row (previously this pre-copied them too, so
  // every captured row was deep-copied twice).
  let width = grid.cols.to_int()
  let cells : FixedArray[@page.PageCellState] = FixedArray::make(
    width,
    @page.PageCellState::new(),
  )
  for col_idx in 0..<width {
    cells[col_idx] = grid.cells[row_idx][col_idx]
  }
  make_pinned_row(
    grid.descs[row_idx],
    cells,
    grid.link_ids[row_idx],
    grid.cols,
    grid.descs[row_idx].wrap(),
    grid.descs[row_idx].wrap_continuation(),
    false,
  )
}

///|
/// Move a soon-to-be-scrolled-off grid row into a history row, taking its cells
/// by reference instead of deep-copying them (unlike `snapshot_scrollback_row`).
///
/// Safe only because every caller (`capture_top_scroll_region_up`) is
/// immediately followed by the grid shift that overwrites `grid` row `row_idx`
/// with the row below — capture is guarded to top_margin==0 full-width and
/// harvests exactly the `count` top rows that the shift then vacates, so once
/// this returns nothing in the active grid aliases these cells. Render snapshots
/// deep-copy and pins track by node identity, so neither aliases them either.
fn harvest_scrollback_row(grid : ScreenGridState, row_idx : Int) -> PageListRow {
  let desc = grid.descs[row_idx]
  make_pinned_row_owned(
    desc,
    grid.cells[row_idx],
    grid.link_ids[row_idx],
    grid.cols,
    desc.wrap(),
    desc.wrap_continuation(),
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
    // Match upstream PageList.zig::trimTrailingBlankRows: blank-row trimming
    // is text-based, so background/style-only bottom rows are disposable.
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
    row.row.semantic_prompt() != None ||
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
fn copy_pinned_row(
  source : PageListRow,
  cols : @size.CellCountInt,
) -> PageListRow {
  let copied = make_pinned_row(
    source.row,
    source.cells,
    source.link_ids,
    cols,
    source.row.wrap(),
    source.row.wrap_continuation(),
    false,
  )
  {
    row: copied.row,
    cells: copied.cells,
    link_ids: copied.link_ids,
    node: source.node,
    y: source.y,
  }
}

///|
fn make_pinned_row(
  row_template : @page.PageRowState,
  source_cells : FixedArray[@page.PageCellState],
  source_link_ids : FixedArray[@hyperlink.HyperlinkId]?,
  cols : @size.CellCountInt,
  wrap : Bool,
  wrap_continuation : Bool,
  update_prompt_continuation : Bool,
) -> PageListRow {
  let width = cols.to_int()
  let cells : FixedArray[@page.PageCellState] = FixedArray::make(
    width,
    @page.PageCellState::new(),
  )
  let copy_len = min_int(width, source_cells.length())
  for col in 0..<copy_len {
    cells[col] = source_cells[col]
  }
  // Carry the source row's hyperlink ids into a fresh width-sized array, keeping
  // them column-aligned with the (possibly truncated) cells. A link-free source
  // stays `None` — no allocation for the common row.
  let link_ids = make_pinned_link_ids(source_link_ids, width, copy_len)
  let mut row = row_template
    .with_wrap(wrap)
    .with_wrap_continuation(wrap_continuation)
  if update_prompt_continuation &&
    wrap_continuation &&
    row.semantic_prompt() == Prompt {
    row = row.with_semantic_prompt(PromptContinuation)
  }
  row = apply_cell_flags_to_row(row, cells)
  let node = PageListNode::new({
    rows: 1,
    cols,
    descs: [row],
    cells: [cells],
    link_ids: [link_ids],
  })
  { row, cells, link_ids, node, y: 0 }
}

///|
/// Copy a source row's hyperlink ids into a fresh `width`-wide array (aligned by
/// column, truncated/zero-padded to `width`), or `None` when the source has no
/// link array — the common link-free row, which then needs no allocation.
fn make_pinned_link_ids(
  source_link_ids : FixedArray[@hyperlink.HyperlinkId]?,
  width : Int,
  copy_len : Int,
) -> FixedArray[@hyperlink.HyperlinkId]? {
  match source_link_ids {
    None => None
    Some(source) => {
      let links = FixedArray::make(width, @hyperlink.no_hyperlink_id)
      let len = min_int(copy_len, source.length())
      for col in 0..<len {
        links[col] = source[col]
      }
      Some(links)
    }
  }
}

///|
/// Like `make_pinned_row`, but takes ownership of `cells` by reference instead
/// of deep-copying each cell. `cells` must already be exactly `cols` wide. Used
/// only by the scroll-off capture hot path, where the source row is about to be
/// overwritten by the grid shift — see `harvest_scrollback_row`. Eliminates the
/// per-cell copy (and its style/array allocation) that dominated scroll cost.
fn make_pinned_row_owned(
  row_template : @page.PageRowState,
  cells : FixedArray[@page.PageCellState],
  link_ids : FixedArray[@hyperlink.HyperlinkId]?,
  cols : @size.CellCountInt,
  wrap : Bool,
  wrap_continuation : Bool,
) -> PageListRow {
  // No `apply_cell_flags_to_row` rescan here: this owned/harvest path receives
  // the *same* live grid row's descriptor and its exact cells (via
  // `harvest_scrollback_row`), and the grid maintains `grapheme`/`styled`/
  // `hyperlink` incrementally on every write/erase, so the template descriptor
  // already carries the correct flags. (`make_pinned_row` keeps the rescan: its
  // cells are rebuilt/reflowed and need not match the template.) Verified by
  // asserting live == rescanned across the suite and the styled/grapheme scroll
  // benchmarks before removing.
  let row = row_template
    .with_wrap(wrap)
    .with_wrap_continuation(wrap_continuation)
  // The link array is taken by reference alongside the cells (it was harvested
  // from the same live grid row).
  let node = PageListNode::new({
    rows: 1,
    cols,
    descs: [row],
    cells: [cells],
    link_ids: [link_ids],
  })
  { row, cells, link_ids, node, y: 0 }
}

///|
fn reflow_spacer_head_cell() -> @page.PageCellState {
  @page.PageCellState::new(wide=SpacerHead)
}

///|
/// Read the hyperlink id at `col` from an optional per-row link array, returning
/// `@hyperlink.no_hyperlink_id` when the row has none or the column is out of range.
fn link_at(
  link_ids : FixedArray[@hyperlink.HyperlinkId]?,
  col : Int,
) -> @hyperlink.HyperlinkId {
  match link_ids {
    Some(links) =>
      if col >= 0 && col < links.length() {
        links[col]
      } else {
        @hyperlink.no_hyperlink_id
      }
    None => @hyperlink.no_hyperlink_id
  }
}

///|
fn apply_cell_flags_to_row(
  row : @page.PageRowState,
  cells : FixedArray[@page.PageCellState],
) -> @page.PageRowState {
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
    if cell.has_hyperlink() {
      hyperlink = true
    }
  }
  row.with_grapheme(grapheme).with_styled(styled).with_hyperlink(hyperlink)
}

///|
/// Recompute the cell-derived flags of a pinned row and write the new descriptor
/// back to both `row` and the row's backing page line. `@page.PageRowState` is a value
/// type, so the two no longer share storage — keeping them in sync preserves the
/// aliased behaviour the previous mutable descriptor had.
fn PageListRow::recompute_cell_flags(self : PageListRow) -> Unit {
  let desc = apply_cell_flags_to_row(self.row, self.cells)
  self.row = desc
  self.node.page.descs[0] = desc
}

///|
fn reflow_cell_has_content(cell : @page.PageCellState) -> Bool {
  !cell.is_empty() ||
  cell.has_styling() ||
  cell.is_protected() ||
  cell.has_hyperlink() ||
  cell.semantic_content() != Output
}

///|
fn screen_grid_from_rows(
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
  pinned_rows : Array[PageListRow],
  style_table : @style.StyleTable,
  hyperlink_table : @hyperlink.HyperlinkTable,
  grapheme_table : @page.GraphemeTable,
) -> ScreenGridState {
  // Share the screen's tables: the pinned rows carry ids minted from them, so the
  // rebuilt grid must resolve against the same tables.
  let grid = ScreenGridState::new_with_table(
    rows, cols, style_table, hyperlink_table, grapheme_table,
  )
  let row_count = min_int(rows.to_int(), pinned_rows.length())
  for row_idx in 0..<row_count {
    grid.descs[row_idx] = pinned_rows[row_idx].row
    for col_idx in 0..<cols.to_int() {
      grid.cells[row_idx][col_idx] = pinned_rows[row_idx].cells[col_idx]
    }
    // Carry the row's hyperlink ids by reference; the pinned row owns a fresh
    // width-matched array (or `None`), so the grid can take it directly.
    grid.link_ids[row_idx] = pinned_rows[row_idx].link_ids
  }
  grid
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
