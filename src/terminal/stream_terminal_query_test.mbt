///|
fn expect_rgb(actual : RGB?, expected : RGB?) -> Unit raise {
  guard actual == expected else { fail("expected RGB snapshot") }
}

///|
test "stream terminal query/exposes cursor and scrollbar state" {
  let terminal = StreamTerminal::new()

  guard terminal.columns() == 80 &&
    terminal.rows() == 24 &&
    terminal.cursor_x() == 0 &&
    terminal.cursor_y() == 0 &&
    terminal.cursor_visible() &&
    !terminal.cursor_pending_wrap() else {
    fail("expected default terminal query state")
  }

  let initial = terminal.scrollbar()
  guard initial.total() == 24U && initial.offset() == 0U && initial.len() == 24U else {
    fail("expected default scrollbar snapshot")
  }

  guard terminal.resize(4, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before cursor wrap query")
  }
  terminal.next_slice(b"abcd")
  guard terminal.cursor_pending_wrap() else {
    fail("expected pending wrap query after right-edge write")
  }

  guard terminal.resize(5, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before scrollbar query")
  }
  terminal.next_slice(b"hello\x1BD\x1BD\x1BD")

  let bottom = terminal.scrollbar()
  guard bottom.total() == 5U && bottom.offset() == 3U && bottom.len() == 2U else {
    fail(
      "expected active viewport scrollbar snapshot total=\{bottom.total()} offset=\{bottom.offset()} len=\{bottom.len()}",
    )
  }

  terminal.scroll_viewport_top()
  guard terminal.scrollbar().offset() == 0U else {
    fail("expected viewport-top scrollbar offset")
  }
  terminal.scroll_viewport_bottom()
  guard terminal.scrollbar().offset() == 3U else {
    fail("expected viewport-bottom scrollbar offset")
  }

  terminal.mode_set(Mode::AltScreenLegacy, true)
  let alternate = terminal.scrollbar()
  guard alternate.total() == 2U &&
    alternate.offset() == 0U &&
    alternate.len() == 2U else {
    fail("expected zero-scrollback alternate-screen scrollbar snapshot")
  }

  terminal.deinit()
}

///|
test "stream terminal query/exposes visibility mouse and kitty keyboard state" {
  let terminal = StreamTerminal::new()

  guard terminal.cursor_visible() &&
    !terminal.mouse_tracking() &&
    terminal.kitty_keyboard_flags().0 == 0 else {
    fail("expected default visibility and input query state")
  }

  terminal.mode_set(Mode::CursorVisible, false)
  guard !terminal.cursor_visible() else {
    fail("expected cursor visibility query to follow DEC mode 25")
  }

  terminal.mode_set(Mode::MouseEventAny, true)
  guard terminal.mouse_tracking() else {
    fail("expected mouse tracking aggregate query")
  }
  terminal.mode_set(Mode::MouseEventAny, false)
  guard !terminal.mouse_tracking() else {
    fail("expected mouse tracking aggregate clear")
  }

  terminal.next_slice(b"\x1B[>3u")
  guard terminal.kitty_keyboard_flags().0 == 3 else {
    fail("expected kitty keyboard flag query")
  }

  terminal.deinit()
}

///|
test "stream terminal query/exposes current and default colors" {
  let terminal = StreamTerminal::new()
  let default_fg = RGB::new(0xAA, 0xBB, 0xCC)
  let default_bg = RGB::new(0x11, 0x22, 0x33)
  let default_cursor = RGB::new(0xFF, 0x00, 0x88)

  expect_rgb(terminal.foreground_color(), None)
  expect_rgb(terminal.background_color(), None)
  expect_rgb(terminal.cursor_color(), None)
  expect_rgb(terminal.default_foreground_color(), None)
  expect_rgb(terminal.default_background_color(), None)
  expect_rgb(terminal.default_cursor_color(), None)

  terminal.set_default_foreground_color(Some(default_fg))
  terminal.set_default_background_color(Some(default_bg))
  terminal.set_default_cursor_color(Some(default_cursor))
  guard terminal.palette_dirty() else {
    fail("expected host-side default colors to mark palette dirty")
  }
  terminal.clear_palette_dirty()

  expect_rgb(terminal.foreground_color(), Some(default_fg))
  expect_rgb(terminal.background_color(), Some(default_bg))
  expect_rgb(terminal.cursor_color(), Some(default_cursor))
  expect_rgb(terminal.default_foreground_color(), Some(default_fg))
  expect_rgb(terminal.default_background_color(), Some(default_bg))
  expect_rgb(terminal.default_cursor_color(), Some(default_cursor))

  terminal.next_slice(
    b"\x1B]10;rgb:00/00/00\x07\x1B]11;rgb:01/02/03\x07\x1B]12;rgb:04/05/06\x07",
  )
  expect_rgb(terminal.foreground_color(), Some(RGB::new(0, 0, 0)))
  expect_rgb(terminal.background_color(), Some(RGB::new(1, 2, 3)))
  expect_rgb(terminal.cursor_color(), Some(RGB::new(4, 5, 6)))
  expect_rgb(terminal.default_foreground_color(), Some(default_fg))
  expect_rgb(terminal.default_background_color(), Some(default_bg))
  expect_rgb(terminal.default_cursor_color(), Some(default_cursor))

  terminal.set_default_foreground_color(None)
  terminal.set_default_background_color(None)
  terminal.set_default_cursor_color(None)
  expect_rgb(terminal.default_foreground_color(), None)
  expect_rgb(terminal.default_background_color(), None)
  expect_rgb(terminal.default_cursor_color(), None)

  terminal.next_slice(b"\x1B]110;\x07\x1B]111;\x07\x1B]112;\x07")
  expect_rgb(terminal.foreground_color(), None)
  expect_rgb(terminal.background_color(), None)
  expect_rgb(terminal.cursor_color(), None)

  terminal.deinit()
}

///|
test "stream terminal query/exposes current and default palette snapshots" {
  let terminal = StreamTerminal::new()
  let custom = default_palette()
  custom[0] = RGB::new(0x12, 0x34, 0x56)

  guard terminal.set_default_palette(Some(custom)) ==
    TerminalResultCode::Success else {
    fail("expected default palette update")
  }
  guard terminal.palette_dirty() else {
    fail("expected default palette update to mark palette dirty")
  }
  terminal.clear_palette_dirty()

  guard terminal.palette()[0] == RGB::new(0x12, 0x34, 0x56) &&
    terminal.default_palette()[0] == RGB::new(0x12, 0x34, 0x56) else {
    fail("expected default palette snapshot")
  }

  terminal.next_slice(b"\x1B]4;0;rgb:ff/ff/ff\x07")
  guard terminal.palette()[0] == RGB::new(0xFF, 0xFF, 0xFF) &&
    terminal.default_palette()[0] == RGB::new(0x12, 0x34, 0x56) else {
    fail("expected current palette override without losing defaults")
  }

  guard terminal.set_default_palette(Some([RGB::new(1, 2, 3)])) ==
    TerminalResultCode::InvalidValue else {
    fail("expected invalid palette length to be rejected")
  }
  guard terminal.default_palette()[0] == RGB::new(0x12, 0x34, 0x56) else {
    fail("expected invalid palette update to leave defaults untouched")
  }

  guard terminal.set_default_palette(None) == TerminalResultCode::Success else {
    fail("expected palette reset to builtin defaults")
  }
  guard terminal.default_palette()[0] == default_palette()[0] else {
    fail("expected builtin default palette after reset")
  }

  terminal.deinit()
}
