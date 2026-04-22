///|
test "render row iterator/empty state is inert" {
  let state = RenderState::new()
  let rows = state.row_iterator()
  let cells_none = match rows.cells() {
    None => true
    Some(_) => false
  }

  guard !rows.next() &&
    rows.y() == None &&
    rows.row() == None &&
    rows.dirty() == None &&
    !rows.set_dirty(false) &&
    cells_none else {
    fail("expected inert iterator before any snapshot")
  }
}

///|
test "render row iterator/update tracks partial dirty rows" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(5, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before row iterator dirty test")
  }

  let state = RenderState::new()
  state.update(terminal)

  let clear = state.row_iterator()
  while clear.next() {
    guard clear.set_dirty(false) else {
      fail("expected row dirty reset after full snapshot")
    }
  }
  state.set_dirty(RenderDirty::False)

  terminal.next_slice(b"A")
  state.update(terminal)

  guard state.dirty() == RenderDirty::Partial else {
    fail("expected partial render dirty after row-local mutation")
  }

  let rows = state.row_iterator()
  guard rows.next() else { fail("expected first render row") }
  guard rows.y() == Some(0) && rows.dirty() == Some(true) else {
    fail("expected first row to be marked dirty")
  }

  let row = rows.row().unwrap()
  guard row.dirty() else {
    fail("expected row snapshot to carry render-side dirty bit")
  }

  let cells = rows.cells().unwrap()
  guard cells.next() else { fail("expected first cell in first row") }
  guard cells.x() == Some(0) &&
    cells.cell().unwrap().codepoint() == b'A'.to_uint() else {
    fail("expected first dirty row to contain rendered text")
  }

  guard rows.next() && rows.y() == Some(1) && rows.dirty() == Some(false) else {
    fail("expected second row to remain clean")
  }

  terminal.deinit()
}

///|
test "render row cells/select and next resolve style and content colors" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(3, 1, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before row cell color test")
  }

  terminal.next_slice(b"\x1B[31mR\x1B[44mB\x1B[48;5;4m\x1B[K")

  let state = RenderState::new()
  state.update(terminal)

  let rows = state.row_iterator()
  guard rows.next() else { fail("expected first render row for color test") }

  let cells = rows.cells().unwrap()
  guard cells.x() == None &&
    cells.cell() == None &&
    cells.background_color() == None &&
    cells.foreground_color() == None else {
    fail("expected row cells to stay invalid before selection")
  }

  guard !cells.select(3) else {
    fail("expected out-of-range row-cell select to stay false")
  }

  guard cells.select(0) else { fail("expected first row-cell selection") }
  let first = cells.cell().unwrap()
  guard first.codepoint() == b'R'.to_uint() &&
    first.has_text() &&
    cells.foreground_color() == Some(Name::Red.default_rgb()) &&
    cells.background_color() == None else {
    fail("expected style foreground resolution on first cell")
  }

  guard cells.next() &&
    cells.x() == Some(1) &&
    cells.cell().unwrap().codepoint() == b'B'.to_uint() &&
    cells.foreground_color() == Some(Name::Red.default_rgb()) &&
    cells.background_color() == Some(Name::Blue.default_rgb()) else {
    fail("expected style background resolution on second cell")
  }

  guard cells.next() && cells.x() == Some(2) else {
    fail("expected third row-cell selection via next")
  }
  let third = cells.cell().unwrap()
  guard !third.has_text() &&
    third.content_tag() == PageCellContentTag::BackgroundPalette &&
    cells.foreground_color() == None &&
    cells.background_color() == Some(Name::Blue.default_rgb()) else {
    fail("expected content-tag background resolution on blank cell")
  }

  guard !cells.next() else {
    fail("expected row-cell iteration to stop at row end")
  }

  terminal.deinit()
}

///|
test "render row cells/resolve direct rgb colors" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(5, 1, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before rgb color test")
  }

  terminal.next_slice(b"\x1B[38;2;1;2;3mX\x1B[48;2;4;5;6m\x1B[K")

  let state = RenderState::new()
  state.update(terminal)

  let rows = state.row_iterator()
  guard rows.next() else {
    fail("expected first render row for rgb color test")
  }

  let cells = rows.cells().unwrap()
  guard cells.select(0) &&
    cells.foreground_color() == Some(RGB::new(1, 2, 3)) &&
    cells.background_color() == None else {
    fail("expected direct rgb foreground resolution")
  }

  guard cells.select(1) &&
    cells.cell().unwrap().content_tag() == PageCellContentTag::BackgroundRgb &&
    cells.foreground_color() == None &&
    cells.background_color() == Some(RGB::new(4, 5, 6)) else {
    fail("expected background-rgb content resolution")
  }

  terminal.deinit()
}

///|
test "render state/viewport movement without cursor change still forces full" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(5, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before viewport-origin dirty test")
  }

  terminal.next_slice(b"hello\x1BD\x1BD\x1BD")
  terminal.scroll_viewport_top()

  let state = RenderState::new()
  state.update(terminal)
  state.set_dirty(RenderDirty::False)

  let clear = state.row_iterator()
  while clear.next() {
    ignore(clear.set_dirty(false))
  }

  terminal.scroll_viewport_delta(1)
  state.update(terminal)

  guard state.cursor_viewport() == None && state.dirty() == RenderDirty::Full else {
    fail("expected viewport-origin change to require full redraw")
  }

  terminal.deinit()
}
