///|
fn new_terminal(cols : CellCountInt, rows : CellCountInt) -> StreamTerminal {
  let term = StreamTerminal::new(size=fn() {
    Some(Size::new(rows, cols, 0U, 0U))
  })
  ignore(term.resize(cols, rows, 0U, 0U))
  term
}

///|
fn plain_format(term : StreamTerminal) -> Bytes {
  Formatter::new_terminal(term, FormatterOptions::new(Format::Plain, trim=true)).format()
}

///|
fn cell_codepoint(
  term : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> UInt {
  term.screen_cell_snapshot(row, col).unwrap().codepoint()
}

///|
fn cell_wide(
  term : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellWide {
  term.screen_cell_snapshot(row, col).unwrap().wide()
}

///|
test "resize preserves active contents" {
  let term = new_terminal(5, 3)
  term.next_slice(b"abc")
  assert_eq(plain_format(term), b"abc")
  ignore(term.resize(10, 3, 0U, 0U))
  assert_eq(plain_format(term), b"abc")
}

///|
test "resize preserves scrollback contents" {
  let term = new_terminal(5, 3)
  term.next_slice(b"1\r\n2\r\n3\r\n4")
  assert_eq(term.scrollback_rows(), 1U)
  ignore(term.resize(10, 3, 0U, 0U))
  assert_eq(term.scrollback_rows(), 1U)
  let (history, _) = term.format_scrollback_rows_since(None)
  assert_eq(history, b"1\r\n")
}

///|
test "resize reflow narrow scrollback keeps row id watermark monotonic" {
  let term = new_terminal(8, 3)
  term.next_slice(b"abcdefgh\r\nzz\r\n333\r\n444\r\n555")
  ignore(term.resize(4, 3, 0U, 0U))
  let (first, last) = term.format_scrollback_rows_since(None)
  guard first.length() > 0 else {
    fail("expected scrollback rows after resize")
  }
  let (second, next) = term.format_scrollback_rows_since(last)
  assert_eq(second, b"")
  assert_eq(next, last)
}

///|
test "resize preserves cursor on tracked blank trailing row" {
  let term = new_terminal(5, 3)
  term.next_slice(b"abc\r\n")
  assert_eq(term.cursor_x(), 0)
  assert_eq(term.cursor_y(), 1)
  ignore(term.resize(3, 3, 0U, 0U))
  assert_eq(term.cursor_x(), 0)
  assert_eq(term.cursor_y(), 1)
}

///|
test "resize row shrink keeps tracked blank cursor row visible" {
  let term = new_terminal(5, 5)
  term.next_slice(b"abc\r\n")
  assert_eq(term.cursor_x(), 0)
  assert_eq(term.cursor_y(), 1)
  ignore(term.resize(5, 2, 0U, 0U))
  assert_eq(term.cursor_x(), 0)
  assert_eq(term.cursor_y(), 1)
  assert_eq(plain_format(term), b"abc")
}

///|
test "resize alternate screen keeps 1049 saved primary cursor" {
  let term = new_terminal(5, 3)
  term.next_slice(b"\x1B[2;5H")
  assert_eq(term.cursor_x(), 4)
  assert_eq(term.cursor_y(), 1)
  term.next_slice(b"\x1B[?1049h")
  assert_true(term.active_screen() == TerminalScreen::Alternate)
  term.next_slice(b"\x1B[Halt")
  ignore(term.resize(3, 3, 0U, 0U))
  term.next_slice(b"\x1B[?1049l")
  assert_true(term.active_screen() == TerminalScreen::Primary)
  assert_eq(term.cursor_x(), 2)
  assert_eq(term.cursor_y(), 1)
}

///|
test "resize preserves primary and alternate screen contents" {
  let term = new_terminal(5, 3)
  term.next_slice(b"pri")
  term.next_slice(b"\x1B[?1049h")
  assert_true(term.active_screen() == TerminalScreen::Alternate)
  term.next_slice(b"\x1B[Halt")
  ignore(term.resize(10, 3, 0U, 0U))
  assert_true(term.active_screen() == TerminalScreen::Alternate)
  assert_eq(plain_format(term), b"alt")
  term.next_slice(b"\x1B[?1049l")
  assert_true(term.active_screen() == TerminalScreen::Primary)
  assert_eq(plain_format(term), b"pri")
}

///|
test "resize reflows active contents to fewer columns" {
  let term = new_terminal(5, 3)
  term.next_slice(b"abcdef")
  ignore(term.resize(3, 3, 0U, 0U))
  assert_eq(cell_codepoint(term, 0, 0), 0x61U)
  assert_eq(cell_codepoint(term, 0, 1), 0x62U)
  assert_eq(cell_codepoint(term, 0, 2), 0x63U)
  assert_eq(cell_codepoint(term, 1, 0), 0x64U)
  assert_eq(cell_codepoint(term, 1, 1), 0x65U)
  assert_eq(cell_codepoint(term, 1, 2), 0x66U)
}

///|
test "resize reflows soft wrapped active contents to more columns" {
  let term = new_terminal(3, 3)
  term.next_slice(b"abcdef")
  ignore(term.resize(6, 3, 0U, 0U))
  assert_eq(cell_codepoint(term, 0, 0), 0x61U)
  assert_eq(cell_codepoint(term, 0, 1), 0x62U)
  assert_eq(cell_codepoint(term, 0, 2), 0x63U)
  assert_eq(cell_codepoint(term, 0, 3), 0x64U)
  assert_eq(cell_codepoint(term, 0, 4), 0x65U)
  assert_eq(cell_codepoint(term, 0, 5), 0x66U)
}

///|
test "resize reflow more columns remaps pending wrap cursor" {
  let term = new_terminal(3, 3)
  term.next_slice(b"abcdef")
  assert_eq(term.cursor_x(), 2)
  assert_eq(term.cursor_y(), 1)
  assert_eq(term.cursor_pending_wrap(), true)
  ignore(term.resize(6, 3, 0U, 0U))
  assert_eq(term.cursor_x(), 5)
  assert_eq(term.cursor_y(), 0)
  assert_eq(term.cursor_pending_wrap(), true)
}

///|
test "resize reflow more columns remaps saved cursor" {
  let term = new_terminal(3, 3)
  term.next_slice(b"abcdef\x1B7")
  ignore(term.resize(6, 3, 0U, 0U))
  term.next_slice(b"\x1B[H\x1B8")
  assert_eq(term.cursor_x(), 5)
  assert_eq(term.cursor_y(), 0)
  assert_eq(term.cursor_pending_wrap(), true)
}

///|
test "resize reflow to one column eliminates wide character" {
  let term = new_terminal(2, 1)
  term.next_slice(b"\xF0\x9F\x98\x80")
  ignore(term.resize(1, 1, 0U, 0U))
  assert_eq(cell_codepoint(term, 0, 0), 0U)
  assert_true(cell_wide(term, 0, 0) == PageCellWide::Narrow)
}

///|
test "resize reflow wraps wide character with spacer head" {
  let term = new_terminal(3, 2)
  term.next_slice(b"x\xF0\x9F\x98\x80")
  ignore(term.resize(2, 2, 0U, 0U))
  assert_eq(cell_codepoint(term, 0, 0), 0x78U)
  assert_true(cell_wide(term, 0, 0) == PageCellWide::Narrow)
  assert_eq(cell_codepoint(term, 0, 1), 0U)
  assert_true(cell_wide(term, 0, 1) == PageCellWide::SpacerHead)
  assert_eq(cell_codepoint(term, 1, 0), 0x1F600U)
  assert_true(cell_wide(term, 1, 0) == PageCellWide::Wide)
  assert_eq(cell_codepoint(term, 1, 1), 0U)
  assert_true(cell_wide(term, 1, 1) == PageCellWide::SpacerTail)
}
