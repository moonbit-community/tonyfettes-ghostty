///|
test "render state/new defaults and manual dirty setter" {
  let state = RenderState::new()

  guard state.rows() == 0 &&
    state.columns() == 0 &&
    state.dirty() == False &&
    state.background_color() == @color.RGB::new(0, 0, 0) &&
    state.foreground_color() == @color.RGB::new(0xFF, 0xFF, 0xFF) &&
    state.cursor_color() == None &&
    state.cursor_visual_style() == Block &&
    state.cursor_visible() &&
    !state.cursor_blinking() &&
    !state.cursor_password_input() &&
    state.cursor_viewport() == None &&
    !state.cursor_viewport_wide_tail() else {
    fail("expected render state defaults")
  }

  state.set_dirty(Partial)
  guard state.dirty() == Partial else {
    fail("expected partial dirty override")
  }

  state.set_dirty(Full)
  guard state.dirty() == Full else { fail("expected full dirty override") }
}

///|
test "render state/update captures terminal snapshot and reverse colors" {
  let terminal = StreamTerminal::new()
  let background = @color.RGB::new(1, 2, 3)
  let foreground = @color.RGB::new(4, 5, 6)
  let cursor = @color.RGB::new(7, 8, 9)

  terminal.set_default_background_color(Some(background))
  terminal.set_default_foreground_color(Some(foreground))
  terminal.set_default_cursor_color(Some(cursor))
  terminal.mode_set(ReverseColors, true)
  terminal.next_slice(b"\x1B[5 q")

  let state = RenderState::new()
  state.update(terminal)

  guard state.dirty() == Full &&
    state.rows() == terminal.rows() &&
    state.columns() == terminal.columns() &&
    state.background_color() == foreground &&
    state.foreground_color() == background &&
    state.cursor_color() == Some(cursor) &&
    state.cursor_visual_style() == Bar &&
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
  palette[0] = @color.RGB::new(0xAA, 0xBB, 0xCC)

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
  state.set_dirty(False)
  state.update(terminal)

  guard state.dirty() == False else {
    fail("expected stable render snapshot to stay clean")
  }

  terminal.deinit()
}

///|
test "render state/update becomes partial after terminal mutation" {
  let terminal = StreamTerminal::new()
  let state = RenderState::new()

  state.update(terminal)
  state.set_dirty(False)
  terminal.next_slice(b"A")
  state.update(terminal)

  guard state.dirty() == Partial else {
    fail("expected terminal mutation to dirty render state partially")
  }

  terminal.deinit()
}

///|
test "render state/hyperlink-only uri change dirties the row" {
  let terminal = StreamTerminal::new()
  let state = RenderState::new()

  // Print 'A' carrying an OSC 8 hyperlink, snapshot, and settle to clean.
  terminal.next_slice(b"\x1B]8;;https://a.example\x07A\x1B]8;;\x07")
  state.update(terminal)
  state.set_dirty(False)
  // A stable re-snapshot stays clean (the link id matches).
  state.update(terminal)
  guard state.dirty() == False else {
    fail("expected a stable snapshot to stay clean")
  }

  // Rewrite the SAME glyph + style at the same cell under a DIFFERENT uri. Only
  // the out-of-cell hyperlink id changes — the packed `@page.PageCellState` is byte-for-
  // byte identical and the row flags are unchanged — so the damage diff must flag
  // the row via the snapshotted link ids, not the cells.
  terminal.next_slice(b"\r\x1B]8;;https://b.example\x07A\x1B]8;;\x07")
  state.update(terminal)
  guard state.dirty() == Partial else {
    fail("expected a hyperlink-only uri change to mark the row dirty")
  }

  terminal.deinit()
}

///|
test "render state/full reset reusing intern ids still forces damage" {
  let terminal = StreamTerminal::new()
  let state = RenderState::new()

  // Print a red 'A' — the first non-default style mints style id 1. Snapshot and
  // settle to clean.
  terminal.next_slice(b"\x1B[31mA\x1B[0m")
  state.update(terminal)
  state.set_dirty(False)

  // RIS rebuilds the screen storage with fresh intern tables, so the next distinct
  // style mints the *same* numeric id (1). Redraw a blue 'A' at the same cell: the
  // packed cell is byte-identical to the pre-reset snapshot and only the table
  // behind id 1 changed, so the cell/id diff alone would read clean. A change of
  // table identity must still force a repaint.
  terminal.next_slice(b"\x1Bc\x1B[34mA\x1B[0m")
  state.update(terminal)
  guard state.dirty() == Full else {
    fail("expected a full reset that reuses intern ids to force full damage")
  }

  terminal.deinit()
}

///|
test "render state/cursor viewport follows terminal viewport" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(5, 2, 0U, 0U) == Success else {
    fail("expected resize before cursor viewport test")
  }

  let state = RenderState::new()
  terminal.next_slice(b"a\r\nb\r\nc\x1B[2;1H")
  guard terminal.scrollback_rows() > 0U && terminal.cursor_y() == 1 else {
    fail(
      "expected cursor viewport test to create scrollback with cursor at bottom",
    )
  }
  state.update(terminal)

  guard state.cursor_viewport() != None && !state.cursor_viewport_wide_tail() else {
    fail("expected cursor viewport inside active viewport")
  }

  state.set_dirty(False)
  terminal.scroll_viewport_top()
  state.update(terminal)

  guard state.cursor_viewport() == None &&
    !state.cursor_viewport_wide_tail() &&
    state.dirty() == Full else {
    fail("expected cursor viewport to disappear when scrolled away")
  }

  terminal.deinit()
}
