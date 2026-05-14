///|
fn fill_terminal_screen_row(
  grid : ScreenGridState,
  row : Int,
  chars : Array[Byte],
  style : CellStyle,
  hyperlink : CellHyperlink?,
) -> Unit {
  for index in 0..<chars.length() {
    grid.write_cell(
      row,
      index,
      chars[index].to_uint(),
      PageCellWide::Narrow,
      style,
      false,
      SemanticContent::Prompt,
      hyperlink,
    )
  }
  grid.recompute_row_flags(row)
}

///|
test "terminal screen state/scrollback snapshots and viewport movement" {
  let grid = ScreenGridState::new(2, 5)
  let style = CellStyle::new()
  style.apply_attribute(Bold)
  let hyperlink = CellHyperlink::explicit("https://example.com", "id")
  fill_terminal_screen_row(
    grid,
    0,
    [b'h', b'e', b'l', b'l', b'o'],
    style,
    Some(hyperlink),
  )
  fill_terminal_screen_row(
    grid,
    1,
    [b'w', b'o', b'r', b'l', b'd'],
    CellStyle::new(),
    None,
  )

  let scrollback = PageList::new(2, 5, 1)
  guard scrollback.row(grid, 3) == None &&
    scrollback.cell(grid, 0, 9) == None &&
    scrollback.cell(grid, 3, 0) == None else {
    fail("expected out of bounds viewport access to stay safe")
  }

  scrollback.capture_top_scroll_region_up(grid, grid.rows.to_int() - 1, 1)
  scrollback.scroll_top()

  let row = scrollback.row(grid, 0).unwrap()
  let cell = scrollback.cell(grid, 0, 0).unwrap()
  guard row.styled() &&
    cell.codepoint() == b'h'.to_uint() &&
    cell.style().bold() &&
    cell.hyperlink() == Some(hyperlink) else {
    fail("expected scrollback history snapshots")
  }

  scrollback.scroll_delta(999)
  guard scrollback.cell(grid, 0, 0).unwrap().codepoint() == b'h'.to_uint() else {
    fail("expected clamp at top of scrollback")
  }
  scrollback.scroll_delta(-999)
  guard scrollback.cell(grid, 0, 0).unwrap().codepoint() == b'h'.to_uint() else {
    fail("expected clamp at bottom of scrollback")
  }
}

///|
test "terminal screen state/viewport top survives future scrollback" {
  let grid = ScreenGridState::new(2, 3)
  fill_terminal_screen_row(grid, 0, [b'a', b'b', b'c'], CellStyle::new(), None)
  fill_terminal_screen_row(grid, 1, [b'd', b'e', b'f'], CellStyle::new(), None)

  let scrollback = PageList::new(2, 3, 2)
  scrollback.scroll_top()
  scrollback.capture_top_scroll_region_up(grid, grid.rows.to_int() - 1, 1)

  guard scrollback.viewport_row_offset() == 0 else {
    fail("expected top viewport to remain pinned when scrollback appears")
  }
}

///|
test "terminal screen state/zero max scrollback trim and resets" {
  let grid = ScreenGridState::new(2, 3)
  fill_terminal_screen_row(grid, 0, [b'a', b'b', b'c'], CellStyle::new(), None)
  fill_terminal_screen_row(grid, 1, [b'd', b'e', b'f'], CellStyle::new(), None)

  let scrollback = PageList::new(2, 3, 0)
  scrollback.capture_top_scroll_region_up(grid, grid.rows.to_int() - 1, 0)
  scrollback.capture_full_screen_scroll_down(grid, 0)
  scrollback.capture_top_scroll_region_up(grid, grid.rows.to_int() - 1, 1)
  scrollback.trim_history()
  guard scrollback.scrollback_rows() == 0U else {
    fail("expected zero max scrollback to drop history")
  }

  let limited = PageList::new(2, 3, 1)
  limited.capture_top_scroll_region_up(grid, grid.rows.to_int() - 1, 1)
  limited.scroll_top()
  limited.capture_top_scroll_region_up(grid, grid.rows.to_int() - 1, 1)
  guard limited.scrollback_rows() == 1U else {
    fail("expected history trimming")
  }
  limited.capture_full_screen_scroll_down(grid, 1)
  limited.full_reset(2)
  guard limited.scrollback_rows() == 0U &&
    limited.cell(grid, 0, 0).unwrap().codepoint() == b'a'.to_uint() else {
    fail("expected full reset to clear history and viewport state")
  }
}

///|
test "terminal screen state/point helpers cover source mappings" {
  let grid = ScreenGridState::new(2, 3)
  fill_terminal_screen_row(grid, 0, [b'a', b'b', b'c'], CellStyle::new(), None)
  fill_terminal_screen_row(grid, 1, [b'd', b'e', b'f'], CellStyle::new(), None)

  let scrollback = PageList::new(2, 3, 2)
  scrollback.capture_top_scroll_region_up(grid, grid.rows.to_int() - 1, 1)

  let history_cell = scrollback
    .cell_at_point(grid, Point::History(Coordinate::new(0, 0U)))
    .unwrap()
  let out_of_col = scrollback.cell_at_point(
    grid,
    Point::History(Coordinate::new(9, 0U)),
  )
  let out_of_row = scrollback.cell_at_point(
    grid,
    Point::Screen(Coordinate::new(0, 9U)),
  )
  guard history_cell.codepoint() == b'a'.to_uint() &&
    out_of_col == None &&
    out_of_row == None else {
    fail("expected point cell lookup bounds and missing-row guards")
  }

  let history_as_screen = scrollback.point_from_point(
    grid,
    Point::History(Coordinate::new(0, 0U)),
    Tag::Screen,
  )
  let screen_as_active = scrollback.point_from_point(
    grid,
    Point::Screen(Coordinate::new(0, 2U)),
    Tag::Active,
  )
  let out_of_active = scrollback.point_from_point(
    grid,
    Point::Active(Coordinate::new(0, 9U)),
    Tag::Screen,
  )
  guard history_as_screen == Some(Coordinate::new(0, 0U)) &&
    screen_as_active == Some(Coordinate::new(0, 1U)) &&
    out_of_active == None else {
    fail("expected point reconstruction guards and screen coordinates")
  }

  guard scrollback.screen_row_source(grid, -1) is None &&
    scrollback.history_row_source(-1) is None &&
    scrollback.history_row_source(0) is Some(PageListRowSource::History(_)) else {
    fail("expected screen/history source guards")
  }

  let history_as_viewport_bottom = scrollback.point_from_point(
    grid,
    Point::History(Coordinate::new(0, 0U)),
    Tag::Viewport,
  )
  guard history_as_viewport_bottom == None else {
    fail("expected viewport lookup miss cases at viewport bottom")
  }
  scrollback.scroll_top()
  let history_as_viewport_top = scrollback.point_from_point(
    grid,
    Point::History(Coordinate::new(0, 0U)),
    Tag::Viewport,
  )
  guard history_as_viewport_top == Some(Coordinate::new(0, 0U)) else {
    fail("expected viewport lookup hit after scrolling to top")
  }
}
