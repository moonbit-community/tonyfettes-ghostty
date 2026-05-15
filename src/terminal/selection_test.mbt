///|
test "selection/preserves endpoints and rectangle flag" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(8, 4, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before selection endpoint test")
  }
  terminal.next_slice(b"abcd\r\nefgh")

  let start = terminal.pin(Point::Active(Coordinate::new(1, 0U))).unwrap()
  let end_ = terminal.pin(Point::Active(Coordinate::new(2, 1U))).unwrap()
  let selection = Selection::new(start, end_, true)

  guard terminal.point_from_pin(selection.start(), Tag::Active) ==
    Some(Coordinate::new(1, 0U)) else {
    fail("expected selection start to be preserved")
  }
  guard terminal.point_from_pin(selection.end(), Tag::Active) ==
    Some(Coordinate::new(2, 1U)) else {
    fail("expected selection end to be preserved")
  }
  guard selection.rectangle() else {
    fail("expected selection rectangle flag to be preserved")
  }
  terminal.untrack_selection(selection)
  terminal.deinit()
}

///|
test "selection/untrack invalidates public pin handle" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(b"abc")

  let pin = terminal.pin(Point::Active(Coordinate::new(1, 0U))).unwrap()
  terminal.untrack_pin(pin)
  guard terminal.point_from_pin(pin, Tag::Active) == None else {
    fail("expected untracked pin handle to stop resolving")
  }

  terminal.deinit()
}

///|
test "selection/pin handles keep their screen owner across alt screen" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(4, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before screen-owned pin test")
  }
  terminal.next_slice(b"abc")
  let primary = terminal
    .selection(
      Point::Active(Coordinate::new(0, 0U)),
      Point::Active(Coordinate::new(2, 0U)),
      false,
    )
    .unwrap()

  terminal.mode_set(Mode::AltScreenLegacy, true)
  terminal.next_slice(b"xyz")
  let alternate = terminal
    .selection(
      Point::Active(Coordinate::new(0, 0U)),
      Point::Active(Coordinate::new(2, 0U)),
      false,
    )
    .unwrap()

  guard terminal.point_from_pin(primary.start(), Tag::Active) == None else {
    fail("expected primary pin to stop resolving while alternate is active")
  }
  guard terminal.point_from_pin(alternate.start(), Tag::Active) ==
    Some(Coordinate::new(0, 0U)) else {
    fail("expected alternate pin to resolve on alternate screen")
  }

  terminal.untrack_selection(primary)
  guard terminal.point_from_pin(alternate.start(), Tag::Active) ==
    Some(Coordinate::new(0, 0U)) else {
    fail("expected untracking primary selection to leave alternate pins intact")
  }

  terminal.untrack_selection(alternate)
  terminal.deinit()
}

///|
test "selection/supports non-rectangular selections" {
  let terminal = StreamTerminal::new()
  let selection = terminal
    .selection(
      Point::Active(Coordinate::new(0, 0U)),
      Point::Viewport(Coordinate::new(0, 0U)),
      false,
    )
    .unwrap()
  guard !selection.rectangle() else {
    fail("expected line selection to remain non-rectangular")
  }
  terminal.untrack_selection(selection)
  terminal.deinit()
}

///|
test "selection/rejects points outside the page list" {
  let terminal = StreamTerminal::new()
  let missing = terminal.selection(
    Point::Active(Coordinate::new(0, 1000U)),
    Point::Active(Coordinate::new(0, 0U)),
    false,
  )
  guard (match missing {
    None => true
    Some(_) => false
  }) else {
    fail("expected out-of-range selection point to be rejected")
  }
  terminal.deinit()
}
