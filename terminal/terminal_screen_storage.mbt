///|
priv struct TerminalScreenStorage {
  mut grid : @grid.ScreenGridState
  mut cursor : @cursor.TerminalCursorState
  saved_cursor : @pagelist.ScreenSavedCursorState
  mut scrollback : @pagelist.PageList
  mut kitty_graphics : KittyGraphicsState
  // Semantic-prompt state is per-screen: the alternate screen used by
  // fullscreen apps must not inherit the primary screen's OSC 133 zones,
  // and its rows must not be stamped with the primary's leftover prompt
  // state. Swapped alongside grid/cursor/scrollback in load/store.
  mut semantic : @semantic.ScreenSemanticState
}

///|
fn TerminalScreenStorage::resize(
  self : TerminalScreenStorage,
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
) -> @pagelist.PageListResizeResult {
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
fn TerminalScreenStorage::new(
  rows : @size.CellCountInt,
  cols : @size.CellCountInt,
  max_scrollback : Int,
) -> TerminalScreenStorage {
  let scrollback = @pagelist.PageList::new(rows, cols, max_scrollback)
  {
    grid: scrollback.active_grid(),
    cursor: @cursor.TerminalCursorState::new(rows, cols),
    saved_cursor: @pagelist.ScreenSavedCursorState::new(),
    scrollback,
    kitty_graphics: KittyGraphicsState::new(),
    semantic: @semantic.ScreenSemanticState::new(),
  }
}
