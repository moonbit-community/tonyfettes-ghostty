///|
fn new_5x5_terminal() -> StreamTerminal {
  let term = StreamTerminal::new(size=fn() { Some(Size::new(5, 5, 0U, 0U)) })
  ignore(term.resize(5, 5, 0U, 0U))
  term
}

///|
test "index at bottom of top attached partial scroll region captures scrollback" {
  let term = new_5x5_terminal()
  term.next_slice(b"1\r\n2\r\n3")
  term.next_slice(b"\x1B[1;3r\x1B[3;1H\nY")
  assert_eq(term.scrollback_rows(), 1U)
  term.scroll_viewport_top()
  assert_eq(
    term.screen_cell_snapshot(0, 0).unwrap().codepoint(),
    b'1'.to_uint(),
  )
}

///|
test "scroll up in top attached partial scroll region captures scrollback" {
  let term = new_5x5_terminal()
  term.next_slice(b"1\r\n2\r\n3")
  term.next_slice(b"\x1B[1;3r\x1B[1S")
  assert_eq(term.scrollback_rows(), 1U)
  term.scroll_viewport_top()
  assert_eq(
    term.screen_cell_snapshot(0, 0).unwrap().codepoint(),
    b'1'.to_uint(),
  )
}
