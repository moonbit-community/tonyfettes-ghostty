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
