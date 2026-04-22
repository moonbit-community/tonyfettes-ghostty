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

  let scrollback = TerminalScrollbackState::new(2, 1)
  guard scrollback.row(grid, 3) == None &&
    scrollback.cell(grid, 0, 9) == None &&
    scrollback.cell(grid, 3, 0) == None else {
    fail("expected out of bounds viewport access to stay safe")
  }

  scrollback.capture_full_screen_scroll_up(grid, 1)
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
test "terminal screen state/zero max scrollback trim and resets" {
  let grid = ScreenGridState::new(2, 3)
  fill_terminal_screen_row(grid, 0, [b'a', b'b', b'c'], CellStyle::new(), None)
  fill_terminal_screen_row(grid, 1, [b'd', b'e', b'f'], CellStyle::new(), None)

  let scrollback = TerminalScrollbackState::new(2, 0)
  scrollback.capture_full_screen_scroll_up(grid, 0)
  scrollback.capture_full_screen_scroll_down(grid, 0)
  scrollback.capture_full_screen_scroll_up(grid, 1)
  scrollback.trim_history()
  guard scrollback.scrollback_rows() == 0U else {
    fail("expected zero max scrollback to drop history")
  }

  let limited = TerminalScrollbackState::new(2, 1)
  limited.capture_full_screen_scroll_up(grid, 1)
  limited.scroll_top()
  limited.capture_full_screen_scroll_up(grid, 1)
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
test "terminal screen state/grid ref helpers cover row id mappings" {
  let grid = ScreenGridState::new(2, 3)
  fill_terminal_screen_row(grid, 0, [b'a', b'b', b'c'], CellStyle::new(), None)
  fill_terminal_screen_row(grid, 1, [b'd', b'e', b'f'], CellStyle::new(), None)

  let scrollback = TerminalScrollbackState::new(2, 2)
  scrollback.capture_full_screen_scroll_up(grid, 1)

  guard !scrollback.row_by_id(grid, 0UL).unwrap().hyperlink() &&
    scrollback.row_by_id(grid, 999UL) == None else {
    fail("expected row id lookup to cover history and missing rows")
  }
  guard scrollback.cell_by_id(grid, 0UL, 0).unwrap().codepoint() ==
    b'a'.to_uint() &&
    scrollback.cell_by_id(grid, 0UL, 9) == None &&
    scrollback.cell_by_id(grid, 999UL, 0) == None else {
    fail("expected cell id lookup bounds and missing-row guards")
  }

  guard scrollback.point_from_row_id(grid, 0UL, 9, Tag::History) == None &&
    scrollback.point_from_row_id(grid, 2UL, 0, Tag::Screen) ==
    Some(Coordinate::new(0, 2U)) &&
    scrollback.point_from_row_id(grid, 999UL, 0, Tag::Screen) == None else {
    fail("expected point reconstruction guards and screen coordinates")
  }

  let history_ref = scrollback
    .grid_ref(
      TerminalScreen::Primary,
      grid,
      Point::History(Coordinate::new(0, 0U)),
    )
    .unwrap()
  let screen_ref = scrollback
    .grid_ref(
      TerminalScreen::Primary,
      grid,
      Point::Screen(Coordinate::new(0, 2U)),
    )
    .unwrap()
  guard history_ref.row_id_value() == 0UL &&
    screen_ref.row_id_value() == 2UL &&
    scrollback.grid_ref(
      TerminalScreen::Primary,
      grid,
      Point::Active(Coordinate::new(0, 9U)),
    ) ==
    None &&
    scrollback.grid_ref(
      TerminalScreen::Primary,
      grid,
      Point::Screen(Coordinate::new(0, 9U)),
    ) ==
    None else {
    fail("expected point-to-row-id mapping to stay bounded")
  }

  guard scrollback.screen_row_source(grid, -1) == None &&
    scrollback.history_row_source(-1) == None &&
    scrollback.history_row_source(0)
    is Some(TerminalVisibleRowSource::History(_)) else {
    fail("expected screen/history source guards")
  }

  guard scrollback.viewport_index_of_row_id(grid, 0UL) == None &&
    scrollback.viewport_index_of_row_id(grid, 999UL) == None else {
    fail("expected viewport lookup miss cases at viewport bottom")
  }
  scrollback.scroll_top()
  guard scrollback.viewport_index_of_row_id(grid, 0UL) == Some(0) else {
    fail("expected viewport lookup hit after scrolling to top")
  }
}
