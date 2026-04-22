///|
test "render state/new defaults and manual dirty setter" {
  let state = RenderState::new()

  guard state.rows() == 0 &&
    state.columns() == 0 &&
    state.dirty() == RenderDirty::False &&
    state.background_color() == RGB::new(0, 0, 0) &&
    state.foreground_color() == RGB::new(0xFF, 0xFF, 0xFF) &&
    state.cursor_color() == None &&
    state.cursor_visual_style() == CursorVisualStyle::Block &&
    state.cursor_visible() &&
    !state.cursor_blinking() &&
    !state.cursor_password_input() &&
    state.cursor_viewport() == None &&
    !state.cursor_viewport_wide_tail() else {
    fail("expected render state defaults")
  }

  state.set_dirty(RenderDirty::Partial)
  guard state.dirty() == RenderDirty::Partial else {
    fail("expected partial dirty override")
  }

  state.set_dirty(RenderDirty::Full)
  guard state.dirty() == RenderDirty::Full else {
    fail("expected full dirty override")
  }
}

///|
test "render state/update captures terminal snapshot and reverse colors" {
  let terminal = StreamTerminal::new()
  let background = RGB::new(1, 2, 3)
  let foreground = RGB::new(4, 5, 6)
  let cursor = RGB::new(7, 8, 9)

  terminal.set_default_background_color(Some(background))
  terminal.set_default_foreground_color(Some(foreground))
  terminal.set_default_cursor_color(Some(cursor))
  terminal.mode_set(Mode::ReverseColors, true)
  terminal.next_slice(b"\x1B[5 q")

  let state = RenderState::new()
  state.update(terminal)

  guard state.dirty() == RenderDirty::Full &&
    state.rows() == terminal.rows() &&
    state.columns() == terminal.columns() &&
    state.background_color() == foreground &&
    state.foreground_color() == background &&
    state.cursor_color() == Some(cursor) &&
    state.cursor_visual_style() == CursorVisualStyle::Bar &&
    state.cursor_visible() &&
    state.cursor_blinking() &&
    !state.cursor_password_input() else {
    fail("expected render snapshot to reflect terminal state")
  }

  terminal.deinit()
}

///|
test "render state/palette snapshot is cloned" {
  let terminal = StreamTerminal::new()
  let state = RenderState::new()
  state.update(terminal)

  let palette = state.palette()
  let original = state.palette()[0]
  palette[0] = RGB::new(0xAA, 0xBB, 0xCC)

  guard state.palette()[0] == original else {
    fail("expected cloned palette snapshots")
  }

  terminal.deinit()
}

///|
test "render state/update is false when snapshot is stable" {
  let terminal = StreamTerminal::new()
  let state = RenderState::new()

  state.update(terminal)
  state.set_dirty(RenderDirty::False)
  state.update(terminal)

  guard state.dirty() == RenderDirty::False else {
    fail("expected stable render snapshot to stay clean")
  }

  terminal.deinit()
}

///|
test "render state/update becomes partial after terminal mutation" {
  let terminal = StreamTerminal::new()
  let state = RenderState::new()

  state.update(terminal)
  state.set_dirty(RenderDirty::False)
  terminal.next_slice(b"A")
  state.update(terminal)

  guard state.dirty() == RenderDirty::Partial else {
    fail("expected terminal mutation to dirty render state partially")
  }

  terminal.deinit()
}

///|
test "render state/cursor viewport follows terminal viewport" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(5, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before cursor viewport test")
  }

  let state = RenderState::new()
  terminal.next_slice(b"hello\x1BD\x1BD\x1BD")
  state.update(terminal)

  let bottom_viewport = expected_cursor_viewport(terminal)
  guard bottom_viewport != None &&
    state.cursor_viewport() == bottom_viewport &&
    !state.cursor_viewport_wide_tail() else {
    fail("expected cursor viewport inside active viewport")
  }

  state.set_dirty(RenderDirty::False)
  terminal.scroll_viewport_top()
  state.update(terminal)

  guard expected_cursor_viewport(terminal) == None &&
    state.cursor_viewport() == None &&
    !state.cursor_viewport_wide_tail() &&
    state.dirty() == RenderDirty::Full else {
    fail("expected cursor viewport to disappear when scrolled away")
  }

  terminal.deinit()
}

///|
fn expected_cursor_viewport(terminal : StreamTerminal) -> Coordinate? {
  let cursor_point = Point::Active(
    Coordinate::new(terminal.cursor_x(), terminal.cursor_y().to_uint()),
  )
  match terminal.grid_ref(cursor_point) {
    Some(grid_ref) => terminal.point_from_grid_ref(grid_ref, Tag::Viewport)
    None => None
  }
}
