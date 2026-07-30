///|
test "terminal screen state/reuses an evicted history row for the next blank" {
  let scrollback = PageList::new(2, 2, 1)
  let grid = scrollback.active_grid()
  let style = @style.CellStyle::new()
  let cursor = @cursor.TerminalCursorState::new(2, 2)
  grid.write_cell(0, 0, b'A'.to_uint(), Narrow, style, false, Output, None)
  grid.write_cell(1, 0, b'B'.to_uint(), Narrow, style, false, Output, None)

  // The first scroll fills the one-row history without evicting anything.
  scrollback.capture_top_scroll_region_up(grid, 1, 1)
  grid.scroll_up(cursor, style, 1)
  grid.write_cell(1, 0, b'C'.to_uint(), Narrow, style, false, Output, None)

  // The second capture evicts A and offers its cell buffer to the grid. The
  // following shift must reuse that buffer as a blank row without aliasing B
  // in history or C on the active screen.
  scrollback.capture_top_scroll_region_up(grid, 1, 1)
  grid.scroll_up(cursor, style, 1)
  guard grid.row_cells(0)[0].codepoint() == b'C'.to_uint() &&
    grid.row_cells(1)[0].is_empty() else {
    fail("expected recycled storage to become a distinct active blank row")
  }

  scrollback.scroll_top()
  guard scrollback.cell(grid, 0, 0).unwrap().codepoint() == b'B'.to_uint() else {
    fail("expected the retained history row to survive pooled blank reuse")
  }
}
