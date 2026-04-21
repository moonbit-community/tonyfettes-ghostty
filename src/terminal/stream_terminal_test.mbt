///|
struct StreamTerminalEffectsRecorder {
  writes : Array[Bytes]
  mut bell_count : Int
  mut title_changed_count : Int
}

///|
fn StreamTerminalEffectsRecorder::new() -> StreamTerminalEffectsRecorder {
  { writes: [], bell_count: 0, title_changed_count: 0 }
}

///|
fn StreamTerminalEffectsRecorder::write_pty(
  self : StreamTerminalEffectsRecorder,
  data : Bytes,
) -> Unit {
  self.writes.push(data)
}

///|
fn StreamTerminalEffectsRecorder::bell(
  self : StreamTerminalEffectsRecorder,
) -> Unit {
  self.bell_count += 1
}

///|
fn StreamTerminalEffectsRecorder::title_changed(
  self : StreamTerminalEffectsRecorder,
) -> Unit {
  self.title_changed_count += 1
}

///|
fn expect_stream_write(
  recorder : StreamTerminalEffectsRecorder,
  index : Int,
  expected : Bytes,
) -> Unit raise {
  guard recorder.writes[index] == expected else {
    fail("expected captured PTY write")
  }
}

///|
fn expect_terminal_cell(
  terminal : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState {
  terminal.screen_cell_snapshot(row, col).unwrap()
}

///|
test "stream terminal/applies bytes across split escape writes" {
  let terminal = StreamTerminal::new()

  guard terminal.title() == None &&
    terminal.cursor_x() == 0 &&
    terminal.cursor_y() == 0 &&
    terminal.cursor_visual_style() == CursorVisualStyle::Block &&
    !terminal.palette_dirty() &&
    terminal.screen_row_snapshot(24) == None &&
    terminal.screen_cell_snapshot(0, 80) == None else {
    fail("expected default public state")
  }

  terminal.next_slice(b"Hello \x1B")
  terminal.next_slice(b"[1mBold\x1B[0m")

  let row = terminal.screen_row_snapshot(0).unwrap()
  guard row.styled() && row.dirty() else {
    fail("expected row snapshot after split escape writes")
  }
  guard expect_terminal_cell(terminal, 0, 0).codepoint() == b'H'.to_uint() &&
    expect_terminal_cell(terminal, 0, 6).codepoint() == b'B'.to_uint() &&
    expect_terminal_cell(terminal, 0, 6).style().bold() &&
    expect_terminal_cell(terminal, 0, 9).codepoint() == b'd'.to_uint() else {
    fail("expected split escape sequence to preserve parser state")
  }

  terminal.deinit()
}

///|
test "stream terminal/routes query replies and callbacks" {
  let recorder = StreamTerminalEffectsRecorder::new()
  let attributes = DeviceAttributes::new(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt420, [
      PrimaryDeviceAttributeFeature::AnsiColor,
      PrimaryDeviceAttributeFeature::Clipboard,
    ]),
    SecondaryDeviceAttributes::new(DeviceType::Vt420, 100, 7),
    TertiaryDeviceAttributes::new(9U),
  )
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    bell=fn() { recorder.bell() },
    color_scheme=fn() { Some(ColorScheme::Light) },
    device_attributes=fn() { Some(attributes) },
    enquiry=fn() { b"ghostty" },
    size=fn() { Some(Size::new(24, 80, 9, 18)) },
    title_changed=fn() { recorder.title_changed() },
    xtversion=fn() { "ghostty 1.2.3" },
  )

  terminal.next(0x07)
  terminal.next_slice(
    b"\x1B]2;Hello World\x1B\\\x1B[?7$p\x1B[c\x1B[>c\x1B[=c\x1B[18t\x1B[>q\x1B[?996n\x05",
  )

  guard recorder.bell_count == 1 &&
    recorder.title_changed_count == 1 &&
    terminal.title() == Some("Hello World") else {
    fail("expected bell and title callbacks")
  }
  guard recorder.writes.length() == 8 else {
    fail("expected query replies to be captured")
  }
  expect_stream_write(recorder, 0, b"\x1B[?7;1$y")
  expect_stream_write(recorder, 1, b"\x1B[?64;22;52c")
  expect_stream_write(recorder, 2, b"\x1B[>41;100;7c")
  expect_stream_write(recorder, 3, b"\x1BP!|00000009\x1B\\")
  expect_stream_write(recorder, 4, b"\x1B[8;24;80t")
  expect_stream_write(recorder, 5, b"\x1BP>|ghostty 1.2.3\x1B\\")
  expect_stream_write(recorder, 6, b"\x1B[?997;2n")
  expect_stream_write(recorder, 7, b"ghostty")

  terminal.deinit()
}

///|
test "stream terminal/uses readonly fallbacks and palette dirtiness" {
  let recorder = StreamTerminalEffectsRecorder::new()
  let terminal = StreamTerminal::new(write_pty=fn(data) {
    recorder.write_pty(data)
  })

  terminal.next_slice(
    b"\x1B[c\x1B[18t\x1B[?996n\x1B[>q\x05\x1B]21;5=rgb:01/02/03\x07A",
  )

  guard recorder.writes.length() == 2 else {
    fail("expected only default DA and XTVERSION replies")
  }
  expect_stream_write(recorder, 0, b"\x1B[?62;22c")
  expect_stream_write(recorder, 1, b"\x1BP>|libghostty\x1B\\")

  guard terminal.palette_dirty() &&
    expect_terminal_cell(terminal, 0, 0).codepoint() == b'A'.to_uint() else {
    fail("expected palette dirtiness and printable text")
  }
  terminal.clear_palette_dirty()
  guard !terminal.palette_dirty() else {
    fail("expected public palette dirty clear")
  }

  terminal.deinit()
}
