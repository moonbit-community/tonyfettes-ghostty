// Black-box scrollback behaviour tests, driving StreamTerminal through escape
// sequences and reading back the buffer via the public snapshot API. These
// guard the deque-based history and the row-object grid (a scroll moves whole
// line objects, so aliasing/ordering bugs would surface here) independently of
// the internal representation.
//
// screen_cell_snapshot reads the current VIEWPORT (rows 0..height-1):
// scroll_viewport_top() exposes the oldest rows (top of history),
// scroll_viewport_bottom() exposes the active screen.

///|
/// Codepoint at column 0 of viewport row `row`.
fn view_cp0(term : StreamTerminal, row : Int) -> UInt {
  term.screen_cell_snapshot(row.to_uint16(), 0).unwrap().codepoint()
}

///|
/// A fresh terminal sized to cols x rows.
fn sized_terminal(cols : Int, rows : Int) -> StreamTerminal {
  let term = StreamTerminal::new()
  ignore(term.resize(cols.to_uint16(), rows.to_uint16(), 8U, 16U))
  term
}

///|
test "scrollback/lines scroll into history in order" {
  let term = sized_terminal(10, 3)
  term.next_slice(b"A\r\nB\r\nC\r\nD\r\nE\r\nF")
  // 3-row screen: A,B,C scroll into history, D,E,F stay on screen.
  assert_eq(term.scrollback_rows(), 3U)
  assert_eq(term.total_rows(), 6U)
  term.scroll_viewport_bottom()
  assert_eq(view_cp0(term, 0), b'D'.to_uint())
  assert_eq(view_cp0(term, 1), b'E'.to_uint())
  assert_eq(view_cp0(term, 2), b'F'.to_uint())
  term.scroll_viewport_top()
  assert_eq(view_cp0(term, 0), b'A'.to_uint())
  assert_eq(view_cp0(term, 1), b'B'.to_uint())
  assert_eq(view_cp0(term, 2), b'C'.to_uint())
  term.deinit()
}

///|
test "scrollback/active screen edits do not corrupt history" {
  let term = sized_terminal(10, 3)
  term.next_slice(b"A\r\nB\r\nC\r\nD\r\nE\r\nF")
  // Overwrite the whole active screen in place; history must be untouched.
  // This is the regression guard for the row-object scroll: a moved line
  // transiently aliases its source slot, so a stale alias would let a screen
  // edit leak into scrollback.
  term.next_slice(b"\x1b[H1\r\n2\r\n3")
  term.scroll_viewport_top()
  assert_eq(view_cp0(term, 0), b'A'.to_uint())
  assert_eq(view_cp0(term, 1), b'B'.to_uint())
  assert_eq(view_cp0(term, 2), b'C'.to_uint())
  term.scroll_viewport_bottom()
  assert_eq(view_cp0(term, 0), b'1'.to_uint())
  assert_eq(view_cp0(term, 2), b'3'.to_uint())
  term.deinit()
}

///|
test "scrollback/multi-line scroll up preserves order and clears tail" {
  let term = sized_terminal(10, 4)
  term.next_slice(b"A\r\nB\r\nC\r\nD")
  assert_eq(term.scrollback_rows(), 0U)
  // Scroll up by 2 at once: the count>1 path is where an in-place clear of an
  // aliased scrolled-in row would corrupt a moved row.
  term.next_slice(b"\x1b[2S")
  assert_eq(term.scrollback_rows(), 2U)
  // Active screen: C,D then two blank rows.
  term.scroll_viewport_bottom()
  assert_eq(view_cp0(term, 0), b'C'.to_uint())
  assert_eq(view_cp0(term, 1), b'D'.to_uint())
  assert_eq(term.screen_cell_snapshot(2, 0).unwrap().is_empty(), true)
  assert_eq(term.screen_cell_snapshot(3, 0).unwrap().is_empty(), true)
  // Top of the buffer: A,B (history) then C,D.
  term.scroll_viewport_top()
  assert_eq(view_cp0(term, 0), b'A'.to_uint())
  assert_eq(view_cp0(term, 1), b'B'.to_uint())
  assert_eq(view_cp0(term, 2), b'C'.to_uint())
  assert_eq(view_cp0(term, 3), b'D'.to_uint())
  term.deinit()
}

///|
test "scrollback/alternate screen accumulates no history" {
  let term = sized_terminal(10, 3)
  term.next_slice(b"\x1b[?1049h")
  term.next_slice(b"A\r\nB\r\nC\r\nD\r\nE\r\nF")
  // The alternate screen has no scrollback; scrolling there must not grow it.
  assert_eq(term.scrollback_rows(), 0U)
  term.deinit()
}

///|
test "scrollback/wide character survives scroll into history" {
  let term = sized_terminal(10, 2)
  // "中" (a wide CJK cell) then enough newlines to push it into history.
  term.next_slice(b"\xE4\xB8\xAD\r\nx\r\ny\r\nz")
  term.scroll_viewport_top()
  let head = term.screen_cell_snapshot(0, 0).unwrap()
  assert_eq(head.codepoint(), 0x4E2D)
  guard head.wide() == Wide else {
    fail("expected wide head cell preserved in scrollback")
  }
  guard term.screen_cell_snapshot(0, 1).unwrap().wide() == SpacerTail else {
    fail("expected spacer tail after wide cell in scrollback")
  }
  term.deinit()
}

///|
test "scrollback/trailing spacer head survives scroll into history" {
  // Regression for the zero-copy enqueue. A wide character that cannot fit in
  // the last column leaves a trailing SpacerHead and wraps. When that row
  // scrolls off its cells are *moved* (shared) into the history row, and the
  // grid shift that immediately follows calls row_will_be_shifted on it — which
  // for a trailing SpacerHead clears that cell in place. With the shared array
  // that would corrupt the just-captured scrollback row, so the full-width
  // shift must skip the cleanup of rows it fully replaces. (The wide char at
  // column 0 is covered above; this guards the right-edge SpacerHead.)
  let term = sized_terminal(2, 2)
  // "x" then a wide emoji that can't fit in the last column: SpacerHead at col 1,
  // emoji wraps to row 1. The newline pushes the SpacerHead row into history.
  term.next_slice(b"x\xF0\x9F\x98\x80\r\n")
  term.scroll_viewport_top()
  assert_eq(view_cp0(term, 0), b'x'.to_uint())
  guard term.screen_cell_snapshot(0, 1).unwrap().wide() == SpacerHead else {
    fail("trailing SpacerHead was cleared in the captured scrollback row")
  }
  term.deinit()
}

///|
test "scrollback/reflow on resize preserves history content" {
  let term = sized_terminal(10, 3)
  term.next_slice(b"A\r\nB\r\nC\r\nD\r\nE")
  assert_eq(term.scrollback_rows(), 2U)
  // Narrowing the columns rebuilds the buffer through reflow (screen_grid_from_rows
  // + the row-object pages); short single-char rows must survive intact.
  ignore(term.resize(8, 3, 8U, 16U))
  term.scroll_viewport_top()
  assert_eq(view_cp0(term, 0), b'A'.to_uint())
  assert_eq(view_cp0(term, 1), b'B'.to_uint())
  assert_eq(view_cp0(term, 2), b'C'.to_uint())
  term.scroll_viewport_bottom()
  assert_eq(view_cp0(term, 2), b'E'.to_uint())
  term.deinit()
}
