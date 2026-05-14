///|
fn expect_row(grid : ScreenGridState, row : CellCountInt) -> PageRowState {
  grid.row(row).unwrap()
}

///|
fn ScreenGridState::cell(
  self : ScreenGridState,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState? {
  let row_idx = row.to_int()
  let col_idx = col.to_int()
  if row_idx < 0 ||
    row_idx >= self.rows.to_int() ||
    col_idx < 0 ||
    col_idx >= self.cols.to_int() {
    None
  } else {
    Some(self.cells[self.cell_index(row_idx, col_idx)])
  }
}

///|
fn expect_cell(
  grid : ScreenGridState,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState {
  grid.cell(row, col).unwrap()
}

///|
fn fill_ascii(grid : ScreenGridState, row : Int, chars : Array[Byte]) -> Unit {
  for i in 0..<chars.length() {
    grid.write_cell(
      row,
      i,
      chars[i].to_uint(),
      PageCellWide::Narrow,
      CellStyle::new(),
      false,
      SemanticContent::Output,
      None,
    )
  }
  grid.recompute_row_flags(row)
}

///|
test "screen grid/new clamps zero dimensions and accessors" {
  let grid = ScreenGridState::new(0, 0)
  guard grid.rows == 1 && grid.cols == 1 else {
    fail("expected zero dimensions to clamp to one")
  }

  let row = expect_row(grid, 0)
  guard !row.wrap() && row.semantic_prompt() == RowSemanticPrompt::None else {
    fail("expected default row")
  }

  let cell = expect_cell(grid, 0, 0)
  guard cell.codepoint() == 0U &&
    cell.wide() == PageCellWide::Narrow &&
    cell.is_empty() else {
    fail("expected default cell")
  }

  guard grid.row(1) == None && grid.cell(0, 1) == None else {
    fail("expected out of bounds access to return none")
  }
}

///|
test "screen grid/print stores metadata and repeat clamps zero count" {
  let grid = ScreenGridState::new(2, 5)
  let cursor = TerminalCursorState::new(2, 5)
  let style = CellStyle::new()
  style.apply_attribute(Bold)
  style.apply_attribute(Color256Bg(7))
  let hyperlink = CellHyperlink::explicit("https://example.com", "link")

  grid.print(
    cursor,
    b'A'.to_uint(),
    1,
    style,
    true,
    SemanticContent::Prompt,
    RowSemanticPrompt::Prompt,
    Some(hyperlink),
    true,
    false,
  )

  let cell = expect_cell(grid, 0, 0)
  guard cell.codepoint() == b'A'.to_uint() &&
    cell.style().bold() &&
    cell.is_protected() &&
    cell.hyperlink() == Some(hyperlink) &&
    cell.semantic_content() == SemanticContent::Prompt else {
    fail("expected printed cell metadata")
  }

  let row = expect_row(grid, 0)
  guard row.semantic_prompt() == RowSemanticPrompt::Prompt &&
    row.styled() &&
    row.hyperlink() &&
    row.dirty() else {
    fail("expected printed row metadata")
  }

  grid.print_repeat(
    cursor,
    b'B'.to_uint(),
    1,
    style,
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    true,
    false,
    0,
  )

  guard expect_cell(grid, 0, 1).codepoint() == b'B'.to_uint() &&
    cursor.x() == 2 &&
    cursor.y() == 0 else {
    fail("expected repeat with zero count to print once")
  }
}

///|
test "screen grid/print wide wrap and one-column fallback" {
  let grid = ScreenGridState::new(2, 4)
  let cursor = TerminalCursorState::new(2, 4)
  cursor.x = 3

  grid.print(
    cursor,
    0x4E2DU,
    2,
    CellStyle::new(),
    false,
    SemanticContent::Prompt,
    RowSemanticPrompt::Prompt,
    None,
    true,
    false,
  )

  guard expect_row(grid, 0).wrap() && expect_row(grid, 1).wrap_continuation() else {
    fail("expected wide print to mark wrap and continuation")
  }
  guard expect_cell(grid, 0, 3).wide() == PageCellWide::SpacerHead &&
    expect_cell(grid, 1, 0).wide() == PageCellWide::Wide &&
    expect_cell(grid, 1, 1).wide() == PageCellWide::SpacerTail &&
    cursor.x() == 2 &&
    cursor.y() == 1 else {
    fail("expected wrapped wide cell layout")
  }

  let skinny = ScreenGridState::new(1, 1)
  let skinny_cursor = TerminalCursorState::new(1, 1)
  skinny.print(
    skinny_cursor,
    0x4E2DU,
    2,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    true,
    false,
  )

  guard expect_cell(skinny, 0, 0).wide() == PageCellWide::Narrow &&
    expect_cell(skinny, 0, 0).codepoint() == 0U &&
    skinny_cursor.pending_wrap() else {
    fail("expected one-column fallback to write a narrow spacer")
  }
}

///|
test "screen grid/print edge branches and insert mode" {
  let no_width_grid = ScreenGridState::new(1, 3)
  let no_width_cursor = TerminalCursorState::new(1, 3)
  no_width_grid.print(
    no_width_cursor,
    b'X'.to_uint(),
    0,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    true,
    false,
  )
  guard expect_cell(no_width_grid, 0, 0).is_empty() else {
    fail("expected width<=0 print to no-op")
  }

  let right_limit_grid = ScreenGridState::new(1, 4)
  let right_limit_cursor = TerminalCursorState::new(1, 4)
  right_limit_cursor.right_margin = 1
  right_limit_cursor.x = 3
  right_limit_grid.print(
    right_limit_cursor,
    b'R'.to_uint(),
    1,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    true,
    false,
  )
  guard expect_cell(right_limit_grid, 0, 3).codepoint() == b'R'.to_uint() &&
    right_limit_cursor.pending_wrap() else {
    fail("expected cursor outside margin to use full-width right limit")
  }

  let wrap_grid = ScreenGridState::new(2, 3)
  let wrap_cursor = TerminalCursorState::new(2, 3)
  wrap_cursor.x = 2
  wrap_cursor.pending_wrap = true
  wrap_grid.print(
    wrap_cursor,
    b'W'.to_uint(),
    1,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    true,
    false,
  )
  guard wrap_cursor.y() == 1 &&
    wrap_cursor.x() == 1 &&
    expect_cell(wrap_grid, 1, 0).codepoint() == b'W'.to_uint() else {
    fail("expected pending wrap to move to the next row before printing")
  }

  let insert_grid = ScreenGridState::new(1, 4)
  let insert_cursor = TerminalCursorState::new(1, 4)
  fill_ascii(insert_grid, 0, [b'A', b'B', b'C', b'D'])
  insert_cursor.x = 1
  insert_grid.print(
    insert_cursor,
    b'X'.to_uint(),
    1,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    true,
    true,
  )
  guard expect_cell(insert_grid, 0, 1).codepoint() == b'X'.to_uint() &&
    expect_cell(insert_grid, 0, 2).codepoint() == b'B'.to_uint() &&
    expect_cell(insert_grid, 0, 3).codepoint() == b'C'.to_uint() else {
    fail("expected insert-mode print to shift existing cells")
  }

  let no_wrap_grid = ScreenGridState::new(1, 4)
  let no_wrap_cursor = TerminalCursorState::new(1, 4)
  no_wrap_cursor.x = 3
  no_wrap_grid.print(
    no_wrap_cursor,
    0x4E2DU,
    2,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    false,
    false,
  )
  guard expect_cell(no_wrap_grid, 0, 3).is_empty() else {
    fail("expected wide print at edge to no-op without wraparound")
  }

  let partial_grid = ScreenGridState::new(2, 4)
  let partial_cursor = TerminalCursorState::new(2, 4)
  partial_cursor.right_margin = 1
  partial_cursor.x = 1
  partial_grid.print(
    partial_cursor,
    0x4E2DU,
    2,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    true,
    false,
  )
  guard expect_cell(partial_grid, 0, 1).wide() == PageCellWide::Narrow &&
    expect_cell(partial_grid, 0, 1).codepoint() == 0U &&
    expect_cell(partial_grid, 1, 0).wide() == PageCellWide::Wide else {
    fail(
      "expected partial-margin wrap to use a narrow clear instead of spacer head",
    )
  }

  let default_width_grid = ScreenGridState::new(1, 2)
  let default_width_cursor = TerminalCursorState::new(1, 2)
  default_width_grid.print(
    default_width_cursor,
    b'Q'.to_uint(),
    3,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    RowSemanticPrompt::None,
    None,
    true,
    false,
  )
  guard expect_cell(default_width_grid, 0, 0).is_empty() else {
    fail("expected unsupported widths to no-op")
  }
}

///|
test "screen grid/insert delete and erase chars preserve backgrounds and protection" {
  let grid = ScreenGridState::new(2, 5)
  let cursor = TerminalCursorState::new(2, 5)
  let bg_style = CellStyle::new()
  bg_style.apply_attribute(Color256Bg(3))

  fill_ascii(grid, 0, [b'A', b'B', b'C', b'D', b'E'])
  cursor.x = 1
  grid.insert_blanks(cursor, bg_style, 1)
  guard expect_cell(grid, 0, 0).codepoint() == b'A'.to_uint() &&
    expect_cell(grid, 0, 1).content_tag() ==
    PageCellContentTag::BackgroundPalette &&
    expect_cell(grid, 0, 1).palette_index() == Some(3) &&
    expect_cell(grid, 0, 2).codepoint() == b'B'.to_uint() &&
    expect_cell(grid, 0, 4).codepoint() == b'D'.to_uint() &&
    !cursor.pending_wrap() else {
    fail("expected insert blanks to shift cells and preserve background")
  }

  fill_ascii(grid, 0, [b'A', b'B', b'C', b'D', b'E'])
  expect_row(grid, 0).set_wrap(true)
  expect_row(grid, 1).set_wrap_continuation(true)
  cursor.x = 1
  grid.delete_chars(cursor, CellStyle::new(), 2)
  guard expect_cell(grid, 0, 0).codepoint() == b'A'.to_uint() &&
    expect_cell(grid, 0, 1).codepoint() == b'D'.to_uint() &&
    expect_cell(grid, 0, 2).codepoint() == b'E'.to_uint() &&
    expect_cell(grid, 0, 3).is_empty() &&
    !expect_row(grid, 0).wrap() &&
    !expect_row(grid, 1).wrap_continuation() else {
    fail("expected delete chars to shift left and reset wrap markers")
  }

  fill_ascii(grid, 0, [b'A', b'B', b'C', b'D', b'E'])
  expect_cell(grid, 0, 1).set_protected(true)
  cursor.x = 1
  grid.erase_chars(cursor, bg_style, ProtectedMode::Iso, 2)
  guard expect_cell(grid, 0, 1).codepoint() == b'B'.to_uint() &&
    expect_cell(grid, 0, 2).content_tag() ==
    PageCellContentTag::BackgroundPalette &&
    expect_cell(grid, 0, 2).palette_index() == Some(3) else {
    fail("expected erase chars to respect iso protection")
  }
}

///|
test "screen grid/char editing edge branches and helper math" {
  let grid = ScreenGridState::new(1, 5)
  let cursor = TerminalCursorState::new(1, 5)
  let style = CellStyle::new()
  style.apply_attribute(Color256Bg(5))

  cursor.pending_wrap = true
  grid.insert_blanks(cursor, style, 0)
  guard cursor.pending_wrap() == false else {
    fail("expected insert blanks zero count to still clear pending wrap")
  }

  cursor.left_margin = 1
  cursor.right_margin = 3
  cursor.x = 0
  fill_ascii(grid, 0, [b'A', b'B', b'C', b'D', b'E'])
  grid.insert_blanks(cursor, style, 1)
  guard expect_cell(grid, 0, 0).codepoint() == b'A'.to_uint() else {
    fail("expected insert blanks outside margins to no-op")
  }

  grid.write_cell(
    0,
    0,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  grid.write_cell(
    0,
    1,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  grid.write_cell(
    0,
    3,
    b'Z'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  grid.write_cell(
    0,
    4,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  cursor.x = 1
  cursor.left_margin = 0
  cursor.right_margin = 3
  grid.insert_blanks(cursor, style, 1)
  guard expect_cell(grid, 0, 0).palette_index() == Some(5) &&
    expect_cell(grid, 0, 1).palette_index() == Some(5) &&
    expect_cell(grid, 0, 4).palette_index() == Some(5) else {
    fail(
      "expected insert blanks to clear spacer-tail and right-edge wide boundaries",
    )
  }

  let end_grid = ScreenGridState::new(1, 5)
  let end_cursor = TerminalCursorState::new(1, 5)
  fill_ascii(end_grid, 0, [b'A', b'B', b'C', b'D', b'E'])
  end_grid.write_cell(
    0,
    3,
    b'Q'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  end_grid.write_cell(
    0,
    4,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  end_cursor.x = 1
  end_grid.insert_blanks(end_cursor, style, 1)
  guard expect_cell(end_grid, 0, 4).palette_index() == Some(5) else {
    fail("expected insert blanks to clear a wide cell at the shift end")
  }

  grid.delete_chars(cursor, style, 0)
  guard expect_cell(grid, 0, 0).palette_index() == Some(5) else {
    fail("expected delete chars zero count to no-op")
  }
  cursor.x = 4
  cursor.left_margin = 0
  cursor.right_margin = 3
  grid.delete_chars(cursor, style, 1)
  guard expect_cell(grid, 0, 4).palette_index() == Some(5) else {
    fail("expected delete chars outside margins to no-op")
  }

  let erase_grid = ScreenGridState::new(1, 4)
  let erase_cursor = TerminalCursorState::new(1, 4)
  fill_ascii(erase_grid, 0, [b'A', b'B', b'C', b'D'])
  erase_grid.write_cell(
    0,
    1,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  erase_cursor.x = 1
  erase_grid.erase_chars(erase_cursor, style, ProtectedMode::Off, 0)
  guard expect_cell(erase_grid, 0, 1).palette_index() == Some(5) &&
    expect_cell(erase_grid, 0, 2).palette_index() == Some(5) else {
    fail("expected erase chars to extend over wide tails")
  }

  let wrap_grid = ScreenGridState::new(1, 4)
  let wrap_cursor = TerminalCursorState::new(1, 4)
  expect_row(wrap_grid, 0).set_wrap(true)
  wrap_grid.write_cell(
    0,
    3,
    0U,
    PageCellWide::SpacerHead,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  wrap_grid.cursor_reset_wrap(wrap_cursor, style)
  guard expect_cell(wrap_grid, 0, 3).palette_index() == Some(5) &&
    !expect_row(wrap_grid, 0).wrap() else {
    fail("expected cursor reset wrap to clear spacer heads")
  }

  guard repeat_count(2) == 2 &&
    max_int(0, 1) == 1 &&
    clamp_int(-1, 0, 3) == 0 &&
    clamp_int(9, 0, 3) == 3 else {
    fail("expected helper math branches")
  }

  let rgb_style = CellStyle::new()
  rgb_style.apply_attribute(DirectColorBg(RGB::new(1, 2, 3)))
  guard blank_cell(rgb_style).background_rgb() == Some(RGB::new(1, 2, 3)) else {
    fail("expected rgb blank cell")
  }
}

///|
test "screen grid/erase line and display modes" {
  let right_grid = ScreenGridState::new(2, 4)
  let right_cursor = TerminalCursorState::new(2, 4)
  let bg_style = CellStyle::new()
  bg_style.apply_attribute(Color256Bg(4))
  right_grid.write_cell(
    0,
    0,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  right_grid.write_cell(
    0,
    1,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  right_grid.write_cell(
    0,
    2,
    b'X'.to_uint(),
    PageCellWide::Narrow,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  right_grid.recompute_row_flags(0)
  right_cursor.x = 1
  right_grid.erase_line(
    right_cursor,
    bg_style,
    ScreenEraseLineMode::Right,
    ProtectedMode::Off,
    false,
  )
  guard expect_cell(right_grid, 0, 0).palette_index() == Some(4) &&
    expect_cell(right_grid, 0, 1).palette_index() == Some(4) &&
    expect_cell(right_grid, 0, 2).palette_index() == Some(4) else {
    fail("expected erase line right to clear from spacer tail boundary")
  }

  let left_grid = ScreenGridState::new(1, 4)
  let left_cursor = TerminalCursorState::new(1, 4)
  fill_ascii(left_grid, 0, [b'A', b'B', b'C', b'D'])
  left_grid.write_cell(
    0,
    1,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  left_grid.write_cell(
    0,
    2,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  left_cursor.x = 1
  left_grid.erase_line(
    left_cursor,
    CellStyle::new(),
    ScreenEraseLineMode::Left,
    ProtectedMode::Off,
    false,
  )
  guard expect_cell(left_grid, 0, 0).is_empty() &&
    expect_cell(left_grid, 0, 1).is_empty() &&
    expect_cell(left_grid, 0, 2).is_empty() &&
    expect_cell(left_grid, 0, 3).codepoint() == b'D'.to_uint() else {
    fail("expected erase line left to clear wide tails")
  }

  let complete_grid = ScreenGridState::new(2, 3)
  let complete_cursor = TerminalCursorState::new(2, 3)
  fill_ascii(complete_grid, 0, [b'A', b'B', b'C'])
  fill_ascii(complete_grid, 1, [b'D', b'E', b'F'])
  expect_row(complete_grid, 1).set_semantic_prompt(RowSemanticPrompt::Prompt)
  complete_grid.erase_display(
    complete_cursor,
    CellStyle::new(),
    ScreenEraseDisplayMode::Complete,
    ProtectedMode::Off,
    false,
  )
  guard expect_cell(complete_grid, 0, 0).is_empty() &&
    expect_cell(complete_grid, 1, 2).is_empty() &&
    expect_row(complete_grid, 1).semantic_prompt() == RowSemanticPrompt::None else {
    fail("expected erase display complete to reset full rows")
  }

  let above_grid = ScreenGridState::new(3, 3)
  let above_cursor = TerminalCursorState::new(3, 3)
  fill_ascii(above_grid, 0, [b'A', b'B', b'C'])
  fill_ascii(above_grid, 1, [b'D', b'E', b'F'])
  fill_ascii(above_grid, 2, [b'G', b'H', b'I'])
  expect_cell(above_grid, 0, 0).set_protected(true)
  above_cursor.y = 1
  above_cursor.x = 1
  above_grid.erase_display(
    above_cursor,
    bg_style,
    ScreenEraseDisplayMode::Above,
    ProtectedMode::Iso,
    false,
  )
  guard expect_cell(above_grid, 0, 0).codepoint() == b'A'.to_uint() &&
    expect_cell(above_grid, 0, 1).palette_index() == Some(4) &&
    expect_cell(above_grid, 1, 0).palette_index() == Some(4) else {
    fail("expected erase display above to respect protection")
  }

  let scroll_grid = ScreenGridState::new(1, 3)
  let scroll_cursor = TerminalCursorState::new(1, 3)
  fill_ascii(scroll_grid, 0, [b'X', b'Y', b'Z'])
  scroll_grid.erase_display(
    scroll_cursor,
    CellStyle::new(),
    ScreenEraseDisplayMode::ScrollComplete,
    ProtectedMode::Off,
    false,
  )
  guard expect_cell(scroll_grid, 0, 0).is_empty() else {
    fail("expected scroll complete to fall back to complete clear")
  }

  let line_complete_grid = ScreenGridState::new(1, 3)
  let line_complete_cursor = TerminalCursorState::new(1, 3)
  fill_ascii(line_complete_grid, 0, [b'Q', b'R', b'S'])
  line_complete_grid.erase_line(
    line_complete_cursor,
    CellStyle::new(),
    ScreenEraseLineMode::Complete,
    ProtectedMode::Off,
    false,
  )
  guard expect_cell(line_complete_grid, 0, 0).is_empty() &&
    expect_cell(line_complete_grid, 0, 2).is_empty() else {
    fail("expected erase line complete to clear the whole line")
  }

  let below_grid = ScreenGridState::new(2, 3)
  let below_cursor = TerminalCursorState::new(2, 3)
  fill_ascii(below_grid, 0, [b'A', b'B', b'C'])
  fill_ascii(below_grid, 1, [b'D', b'E', b'F'])
  below_cursor.x = 1
  below_grid.erase_display(
    below_cursor,
    bg_style,
    ScreenEraseDisplayMode::Below,
    ProtectedMode::Off,
    false,
  )
  guard expect_cell(below_grid, 0, 1).palette_index() == Some(4) &&
    expect_cell(below_grid, 1, 0).palette_index() == Some(4) else {
    fail("expected erase display below to clear current-right and rows below")
  }
}

///|
test "screen grid/line shifts scroll and helper boundaries" {
  let grid = ScreenGridState::new(4, 4)
  let cursor = TerminalCursorState::new(4, 4)
  fill_ascii(grid, 0, [b'A', b'0', b'0', b'0'])
  fill_ascii(grid, 1, [b'B', b'1', b'1', b'1'])
  fill_ascii(grid, 2, [b'C', b'2', b'2', b'2'])
  fill_ascii(grid, 3, [b'D', b'3', b'3', b'3'])

  cursor.y = 1
  grid.insert_lines(cursor, CellStyle::new(), 1)
  guard expect_cell(grid, 1, 0).is_empty() &&
    expect_cell(grid, 2, 0).codepoint() == b'B'.to_uint() &&
    expect_cell(grid, 3, 0).codepoint() == b'C'.to_uint() &&
    cursor.x() == 0 else {
    fail("expected insert lines to shift rows down")
  }

  fill_ascii(grid, 0, [b'A', b'0', b'0', b'0'])
  fill_ascii(grid, 1, [b'B', b'1', b'1', b'1'])
  fill_ascii(grid, 2, [b'C', b'2', b'2', b'2'])
  fill_ascii(grid, 3, [b'D', b'3', b'3', b'3'])
  cursor.y = 1
  grid.delete_lines(cursor, CellStyle::new(), 1)
  guard expect_cell(grid, 1, 0).codepoint() == b'C'.to_uint() &&
    expect_cell(grid, 2, 0).codepoint() == b'D'.to_uint() &&
    expect_cell(grid, 3, 0).is_empty() else {
    fail("expected delete lines to shift rows up")
  }

  fill_ascii(grid, 0, [b'A', b'0', b'0', b'0'])
  fill_ascii(grid, 1, [b'B', b'1', b'1', b'1'])
  fill_ascii(grid, 2, [b'C', b'2', b'2', b'2'])
  fill_ascii(grid, 3, [b'D', b'3', b'3', b'3'])
  cursor.x = 2
  cursor.y = 2
  cursor.pending_wrap = true
  grid.scroll_down(cursor, CellStyle::new(), 1)
  guard cursor.x() == 2 &&
    cursor.y() == 2 &&
    cursor.pending_wrap() &&
    expect_cell(grid, 0, 0).is_empty() &&
    expect_cell(grid, 1, 0).codepoint() == b'A'.to_uint() else {
    fail("expected scroll down to preserve cursor and insert at top margin")
  }

  fill_ascii(grid, 0, [b'A', b'0', b'0', b'0'])
  fill_ascii(grid, 1, [b'B', b'1', b'1', b'1'])
  fill_ascii(grid, 2, [b'C', b'2', b'2', b'2'])
  fill_ascii(grid, 3, [b'D', b'3', b'3', b'3'])
  cursor.x = 3
  cursor.y = 3
  cursor.pending_wrap = true
  grid.scroll_up(cursor, CellStyle::new(), 1)
  guard cursor.x() == 3 &&
    cursor.y() == 3 &&
    cursor.pending_wrap() &&
    expect_cell(grid, 0, 0).codepoint() == b'B'.to_uint() &&
    expect_cell(grid, 3, 0).is_empty() else {
    fail("expected scroll up to preserve cursor and delete from top margin")
  }

  let boundary_grid = ScreenGridState::new(2, 4)
  let style = CellStyle::new()
  style.apply_attribute(Color256Bg(6))
  boundary_grid.write_cell(
    0,
    3,
    0U,
    PageCellWide::SpacerHead,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  expect_row(boundary_grid, 0).set_wrap(true)
  boundary_grid.split_cell_boundary(0, 4, style)
  guard expect_cell(boundary_grid, 0, 3).palette_index() == Some(6) else {
    fail("expected split boundary at row end to clear spacer head")
  }

  boundary_grid.write_cell(
    0,
    3,
    0U,
    PageCellWide::SpacerHead,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  boundary_grid.write_cell(
    1,
    0,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  expect_row(boundary_grid, 1).set_wrap_continuation(true)
  boundary_grid.split_cell_boundary(1, 0, style)
  guard expect_cell(boundary_grid, 0, 3).palette_index() == Some(6) else {
    fail("expected split boundary at row start to clear previous spacer head")
  }

  boundary_grid.write_cell(
    1,
    0,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  boundary_grid.write_cell(
    1,
    1,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  boundary_grid.split_cell_boundary(1, 1, style)
  guard expect_cell(boundary_grid, 1, 0).palette_index() == Some(6) &&
    expect_cell(boundary_grid, 1, 1).palette_index() == Some(6) else {
    fail("expected split boundary in row middle to clear wide pair")
  }

  boundary_grid.write_cell(
    0,
    0,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  boundary_grid.write_cell(
    0,
    1,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  boundary_grid.write_cell(
    0,
    2,
    b'Z'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  boundary_grid.write_cell(
    0,
    3,
    0U,
    PageCellWide::SpacerHead,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  boundary_grid.row_will_be_shifted(0, 1, 2, style)
  guard expect_cell(boundary_grid, 0, 0).palette_index() == Some(6) &&
    expect_cell(boundary_grid, 0, 1).palette_index() == Some(6) &&
    expect_cell(boundary_grid, 0, 2).palette_index() == Some(6) &&
    expect_cell(boundary_grid, 0, 3).palette_index() == Some(6) else {
    fail("expected row-will-be-shifted to clear split wide boundaries")
  }
}

///|
test "screen grid/shift helpers partial regions and split early return" {
  let grid = ScreenGridState::new(3, 4)
  let cursor = TerminalCursorState::new(3, 4)
  fill_ascii(grid, 0, [b'A', b'B', b'C', b'D'])
  fill_ascii(grid, 1, [b'E', b'F', b'G', b'H'])
  fill_ascii(grid, 2, [b'I', b'J', b'K', b'L'])

  grid.insert_lines(cursor, CellStyle::new(), 0)
  grid.delete_lines(cursor, CellStyle::new(), 0)
  guard expect_cell(grid, 0, 0).codepoint() == b'A'.to_uint() else {
    fail("expected zero-count line edits to no-op")
  }

  cursor.x = 3
  cursor.left_margin = 0
  cursor.right_margin = 2
  cursor.y = 0
  grid.insert_lines(cursor, CellStyle::new(), 1)
  guard expect_cell(grid, 0, 0).codepoint() == b'A'.to_uint() else {
    fail("expected insert lines outside region to no-op")
  }
  grid.delete_lines(cursor, CellStyle::new(), 1)
  guard expect_cell(grid, 0, 0).codepoint() == b'A'.to_uint() else {
    fail("expected delete lines outside region to no-op")
  }

  fill_ascii(grid, 0, [b'A', b'B', b'C', b'D'])
  fill_ascii(grid, 1, [b'E', b'F', b'G', b'H'])
  fill_ascii(grid, 2, [b'I', b'J', b'K', b'L'])
  grid.shift_region_down(1, 2, 1, 2, 1, CellStyle::new())
  guard expect_cell(grid, 1, 1).is_empty() &&
    expect_cell(grid, 2, 1).codepoint() == b'F'.to_uint() else {
    fail("expected partial shift down to use region copies")
  }

  fill_ascii(grid, 0, [b'A', b'B', b'C', b'D'])
  fill_ascii(grid, 1, [b'E', b'F', b'G', b'H'])
  fill_ascii(grid, 2, [b'I', b'J', b'K', b'L'])
  grid.shift_region_up(0, 2, 1, 2, 1, CellStyle::new())
  guard expect_cell(grid, 0, 1).codepoint() == b'F'.to_uint() &&
    expect_cell(grid, 2, 1).is_empty() else {
    fail("expected partial shift up to use region copies")
  }

  let bottom_grid = ScreenGridState::new(2, 3)
  let bottom_cursor = TerminalCursorState::new(2, 3)
  fill_ascii(bottom_grid, 0, [b'A', b'B', b'C'])
  fill_ascii(bottom_grid, 1, [b'D', b'E', b'F'])
  bottom_cursor.y = 1
  bottom_grid.index(bottom_cursor, CellStyle::new())
  guard expect_cell(bottom_grid, 0, 0).codepoint() == b'D'.to_uint() &&
    expect_cell(bottom_grid, 1, 0).is_empty() else {
    fail("expected index at bottom margin to scroll up")
  }

  expect_row(bottom_grid, 1).set_wrap(false)
  bottom_grid.split_cell_boundary(1, 3, CellStyle::new())
  guard expect_cell(bottom_grid, 1, 0).is_empty() else {
    fail(
      "expected split boundary at row end without wrap to leave data unchanged",
    )
  }
}

///|
test "screen grid/recompute row flags sees grapheme styling and hyperlinks" {
  let grid = ScreenGridState::new(1, 3)
  let style = CellStyle::new()
  style.apply_attribute(Bold)
  let cell = expect_cell(grid, 0, 0)
  cell.set_codepoint(b'G'.to_uint(), true)
  cell.set_style(style)
  cell.set_hyperlink(Some(CellHyperlink::implicit("https://example.com", 9)))
  grid.recompute_row_flags(0)
  let row = expect_row(grid, 0)
  guard row.grapheme() && row.styled() && row.hyperlink() else {
    fail("expected recompute row flags to notice graphemes, styles, and links")
  }
}

///|
test "screen grid/print cell clears prior wide and spacer forms" {
  let grid = ScreenGridState::new(2, 4)
  let cursor = TerminalCursorState::new(2, 4)
  let style = CellStyle::new()
  style.apply_attribute(Color256Bg(8))

  grid.write_cell(
    0,
    3,
    0U,
    PageCellWide::SpacerHead,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  cursor.y = 1
  cursor.x = 1
  grid.write_cell(
    1,
    1,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  grid.write_cell(
    1,
    2,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  grid.print_cell(
    cursor,
    b'N'.to_uint(),
    PageCellWide::Narrow,
    style,
    false,
    SemanticContent::Output,
    None,
  )
  guard expect_cell(grid, 1, 1).codepoint() == b'N'.to_uint() &&
    expect_cell(grid, 1, 2).palette_index() == Some(8) &&
    expect_cell(grid, 0, 3).palette_index() == Some(8) else {
    fail(
      "expected print cell to clear prior wide cells and previous spacer heads",
    )
  }

  grid.write_cell(
    0,
    3,
    0U,
    PageCellWide::SpacerHead,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  grid.write_cell(
    1,
    0,
    b'W'.to_uint(),
    PageCellWide::Wide,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  grid.write_cell(
    1,
    1,
    0U,
    PageCellWide::SpacerTail,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  cursor.x = 1
  grid.print_cell(
    cursor,
    b'S'.to_uint(),
    PageCellWide::Narrow,
    style,
    false,
    SemanticContent::Output,
    None,
  )
  guard expect_cell(grid, 1, 0).palette_index() == Some(8) &&
    expect_cell(grid, 1, 1).codepoint() == b'S'.to_uint() &&
    expect_cell(grid, 0, 3).palette_index() == Some(8) else {
    fail(
      "expected print cell to clear prior spacer tails and previous spacer heads",
    )
  }

  grid.write_cell(
    1,
    1,
    0U,
    PageCellWide::SpacerHead,
    CellStyle::new(),
    false,
    SemanticContent::Output,
    None,
  )
  grid.print_cell(
    cursor,
    b'H'.to_uint(),
    PageCellWide::Narrow,
    style,
    false,
    SemanticContent::Output,
    None,
  )
  guard expect_cell(grid, 1, 1).codepoint() == b'H'.to_uint() else {
    fail("expected print cell to overwrite prior spacer heads")
  }
}

///|
test "screen grid/decaln and full reset" {
  let grid = ScreenGridState::new(2, 3)
  let fill_style = CellStyle::new()
  fill_style.apply_attribute(Color8Fg(Name::Red))
  fill_style.apply_attribute(Color256Bg(2))

  grid.decaln(fill_style)
  guard expect_cell(grid, 0, 0).codepoint() == b'E'.to_uint() &&
    expect_cell(grid, 1, 2).codepoint() == b'E'.to_uint() &&
    expect_cell(grid, 0, 0).style().fg_color().palette_index() ==
    Some(Name::Red.code()) &&
    expect_cell(grid, 0, 0).style().bg_color().palette_index() == Some(2) &&
    expect_row(grid, 0).dirty() &&
    expect_row(grid, 1).dirty() else {
    fail("expected decaln fill")
  }

  grid.full_reset()
  guard expect_cell(grid, 0, 0).is_empty() &&
    expect_cell(grid, 1, 2).is_empty() &&
    !expect_row(grid, 0).dirty() &&
    !expect_row(grid, 1).dirty() else {
    fail("expected full reset to clear screen state")
  }
}
