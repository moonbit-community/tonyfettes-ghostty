///|
test "stream terminal/grid ref exposes cell row style and grapheme snapshots" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(b"Hello")

  let grid_ref = terminal
    .grid_ref(Point::Active(Coordinate::new(0, 0U)))
    .unwrap()
  let cell = terminal.grid_ref_cell(grid_ref).unwrap()
  let row = terminal.grid_ref_row(grid_ref).unwrap()
  let style = terminal.grid_ref_style(grid_ref).unwrap()
  let graphemes = terminal.grid_ref_graphemes(grid_ref).unwrap()

  guard cell.codepoint() == b'H'.to_uint() &&
    row.dirty() &&
    style.is_default() &&
    graphemes == [b'H'.to_uint()] &&
    terminal.grid_ref_hyperlink_uri(grid_ref) == None else {
    fail("expected typed grid-ref snapshots")
  }
  guard terminal.grid_ref(Point::Active(Coordinate::new(80, 0U))) == None &&
    terminal.grid_ref(Point::Viewport(Coordinate::new(0, 24U))) == None else {
    fail("expected out-of-bounds grid-ref lookup to stay safe")
  }

  terminal.deinit()
}

///|
test "stream terminal/grid ref roundtrips active and viewport coordinates" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(b"Hello")

  let active_ref = terminal
    .grid_ref(Point::Active(Coordinate::new(2, 0U)))
    .unwrap()
  guard terminal.point_from_grid_ref(active_ref, Tag::Active) ==
    Some(Coordinate::new(2, 0U)) else {
    fail("expected active point roundtrip")
  }

  let viewport_ref = terminal
    .grid_ref(Point::Viewport(Coordinate::new(0, 0U)))
    .unwrap()
  guard terminal.point_from_grid_ref(viewport_ref, Tag::Viewport) ==
    Some(Coordinate::new(0, 0U)) else {
    fail("expected viewport point roundtrip")
  }

  terminal.deinit()
}

///|
test "stream terminal/grid ref history stays addressable through screen coords" {
  let terminal = StreamTerminal::new()

  guard terminal.resize(5, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before history grid-ref test")
  }
  terminal.next_slice(b"hello\x1BD\x1BD\x1BD")

  let grid_ref = terminal
    .grid_ref(Point::Screen(Coordinate::new(0, 0U)))
    .unwrap()
  guard terminal.grid_ref_cell(grid_ref).unwrap().codepoint() == b'h'.to_uint() else {
    fail("expected screen ref to read scrollback cell")
  }
  guard terminal.point_from_grid_ref(grid_ref, Tag::Screen) ==
    Some(Coordinate::new(0, 0U)) &&
    terminal.point_from_grid_ref(grid_ref, Tag::History) ==
    Some(Coordinate::new(0, 0U)) &&
    terminal.point_from_grid_ref(grid_ref, Tag::Active) == None else {
    fail("expected history refs to reject active coordinates")
  }

  terminal.deinit()
}

///|
test "stream terminal/grid ref exposes hyperlink uri and styled cell" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(
    b"\x1B]8;;https://example.com\x1B\\\x1B[1mlink\x1B[0m\x1B]8;;\x1B\\",
  )

  let grid_ref = terminal
    .grid_ref(Point::Active(Coordinate::new(0, 0U)))
    .unwrap()
  guard terminal.grid_ref_style(grid_ref).unwrap().bold() &&
    terminal.grid_ref_hyperlink_uri(grid_ref) == Some("https://example.com") else {
    fail("expected hyperlink and style snapshots through grid ref")
  }

  terminal.deinit()
}

///|
test "stream terminal/grid ref survives inactive screen snapshots safely" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(b"Hello")

  let primary_ref = terminal
    .grid_ref(Point::Active(Coordinate::new(0, 0U)))
    .unwrap()
  let edge_ref = terminal
    .grid_ref(Point::Active(Coordinate::new(4, 0U)))
    .unwrap()
  guard terminal.mode_get(Mode::AltScreenLegacy) == false else {
    fail("expected primary screen before alt-screen switch")
  }

  terminal.mode_set(Mode::AltScreenLegacy, true)
  terminal.next_slice(b"alt")
  let alternate_ref = terminal
    .grid_ref(Point::Active(Coordinate::new(0, 0U)))
    .unwrap()

  guard terminal.point_from_grid_ref(primary_ref, Tag::Active) == None &&
    terminal.grid_ref_row(primary_ref).unwrap().dirty() &&
    terminal.grid_ref_cell(primary_ref).unwrap().codepoint() == b'H'.to_uint() else {
    fail("expected primary grid ref to stay queryable but not point-resolvable")
  }

  terminal.mode_set(Mode::AltScreenLegacy, false)
  ignore(terminal.grid_ref_row(alternate_ref))
  ignore(terminal.grid_ref_cell(alternate_ref))
  ignore(terminal.point_from_grid_ref(alternate_ref, Tag::Active))

  guard terminal.point_from_grid_ref(primary_ref, Tag::Active) ==
    Some(Coordinate::new(0, 0U)) else {
    fail("expected primary grid ref to recover after screen restore")
  }

  guard terminal.resize(2, 2, 0U, 0U) == TerminalResultCode::Success &&
    terminal.grid_ref_hyperlink_uri(edge_ref) == None else {
    fail("expected invalidated cell lookup to stay safe")
  }

  terminal.deinit()
}
