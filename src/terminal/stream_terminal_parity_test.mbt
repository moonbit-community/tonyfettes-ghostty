///|
struct StreamTerminalParityRecorder {
  writes : Array[Bytes]
  mut bell_count : Int
  mut title_changed_count : Int
}

///|
fn StreamTerminalParityRecorder::new() -> StreamTerminalParityRecorder {
  { writes: [], bell_count: 0, title_changed_count: 0 }
}

///|
fn StreamTerminalParityRecorder::write_pty(
  self : StreamTerminalParityRecorder,
  data : Bytes,
) -> Unit {
  self.writes.push(data)
}

///|
fn StreamTerminalParityRecorder::bell(
  self : StreamTerminalParityRecorder,
) -> Unit {
  self.bell_count += 1
}

///|
fn StreamTerminalParityRecorder::title_changed(
  self : StreamTerminalParityRecorder,
) -> Unit {
  self.title_changed_count += 1
}

///|
fn expect_parity_write(
  recorder : StreamTerminalParityRecorder,
  index : Int,
  expected : Bytes,
) -> Unit raise {
  guard recorder.writes[index] == expected else {
    fail("expected captured PTY write")
  }
}

///|
fn expect_parity_cell(
  terminal : StreamTerminal,
  row : CellCountInt,
  col : CellCountInt,
) -> PageCellState {
  terminal.screen_cell_snapshot(row, col).unwrap()
}

///|
fn expect_ascii_text(
  terminal : StreamTerminal,
  row : CellCountInt,
  start_col : CellCountInt,
  expected : Bytes,
) -> Unit raise {
  for offset in 0..<expected.length() {
    let col = start_col + offset.to_uint16()
    guard expect_parity_cell(terminal, row, col).codepoint() ==
      expected[offset].to_uint() else {
      fail("expected ASCII text in screen cells")
    }
  }
}

///|
test "stream terminal parity/vt_write" {
  let terminal = StreamTerminal::new()

  terminal.next_slice(b"Hello")

  expect_ascii_text(terminal, 0, 0, b"Hello")
  guard terminal.cursor_x() == 5 && terminal.cursor_y() == 0 else {
    fail("expected printable write parity")
  }

  terminal.deinit()
}

///|
test "stream terminal parity/vt_write split escape sequence" {
  let terminal = StreamTerminal::new()

  terminal.next_slice(b"Hello \x1B")
  terminal.next_slice(b"[1mBold\x1B[0m")

  expect_ascii_text(terminal, 0, 0, b"Hello Bold")
  let row = terminal.screen_row_snapshot(0).unwrap()
  guard row.styled() && expect_parity_cell(terminal, 0, 6).style().bold() else {
    fail("expected split escape sequence parity")
  }

  terminal.deinit()
}

///|
test "stream terminal parity/set write_pty callback" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(write_pty=fn(data) {
    recorder.write_pty(data)
  })

  terminal.next_slice(b"\x1B[?7$p")

  guard recorder.writes.length() == 1 else {
    fail("expected write_pty callback parity")
  }
  expect_parity_write(recorder, 0, b"\x1B[?7;1$y")

  terminal.deinit()
}

///|
test "stream terminal parity/set bell callback" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(bell=fn() { recorder.bell() })

  terminal.next_slice(b"\x07")
  terminal.next_slice(b"\x07\x07")

  guard recorder.bell_count == 3 else { fail("expected bell callback parity") }

  terminal.deinit()
}

///|
test "stream terminal parity/set enquiry callback" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    enquiry=fn() { b"OK" },
  )

  terminal.next(0x05)

  guard recorder.writes.length() == 1 else {
    fail("expected enquiry callback parity")
  }
  expect_parity_write(recorder, 0, b"OK")

  terminal.deinit()
}

///|
test "stream terminal parity/set xtversion callback" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    xtversion=fn() { "myterm 1.0" },
  )

  terminal.next_slice(b"\x1B[>q")

  guard recorder.writes.length() == 1 else {
    fail("expected xtversion callback parity")
  }
  expect_parity_write(recorder, 0, b"\x1BP>|myterm 1.0\x1B\\")

  terminal.deinit()
}

///|
test "stream terminal parity/xtversion without callback reports default" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(write_pty=fn(data) {
    recorder.write_pty(data)
  })

  terminal.next_slice(b"\x1B[>q")

  guard recorder.writes.length() == 1 else {
    fail("expected default xtversion parity")
  }
  expect_parity_write(recorder, 0, b"\x1BP>|libghostty\x1B\\")

  terminal.deinit()
}

///|
test "stream terminal parity/set title_changed callback" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(title_changed=fn() {
    recorder.title_changed()
  })

  terminal.next_slice(b"\x1B]2;Hello\x1B\\")
  terminal.next_slice(b"\x1B]2;World\x1B\\")

  guard recorder.title_changed_count == 2 && terminal.title() == Some("World") else {
    fail("expected title_changed callback parity")
  }

  terminal.deinit()
}

///|
test "stream terminal parity/replaces and clears callbacks on the same terminal" {
  let first = StreamTerminalParityRecorder::new()
  let second = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { first.write_pty(data) },
    bell=fn() { first.bell() },
    title_changed=fn() { first.title_changed() },
  )

  terminal.next_slice(b"\x1B[?7$p\x07\x1B]2;First\x1B\\")
  guard first.writes.length() == 1 &&
    first.bell_count == 1 &&
    first.title_changed_count == 1 else {
    fail("expected initial callbacks to fire")
  }

  terminal.set_write_pty(fn(data) { second.write_pty(data) })
  terminal.set_bell(fn() { second.bell() })
  terminal.set_title_changed(fn() { second.title_changed() })

  terminal.next_slice(b"\x1B[?7$p\x07\x1B]2;Second\x1B\\")
  guard first.writes.length() == 1 &&
    first.bell_count == 1 &&
    first.title_changed_count == 1 &&
    second.writes.length() == 1 &&
    second.bell_count == 1 &&
    second.title_changed_count == 1 else {
    fail("expected callback replacement on the existing terminal")
  }

  terminal.clear_write_pty()
  terminal.clear_bell()
  terminal.clear_title_changed()
  terminal.next_slice(b"\x1B[?7$p\x07\x1B]2;Third\x1B\\")
  guard second.writes.length() == 1 &&
    second.bell_count == 1 &&
    second.title_changed_count == 1 else {
    fail("expected cleared callbacks to restore silent/default behavior")
  }

  terminal.deinit()
}

///|
test "stream terminal parity/replaces callbacks with default fallback paths" {
  let recorder = StreamTerminalParityRecorder::new()
  let attributes = DeviceAttributes::new(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt220, [
      PrimaryDeviceAttributeFeature::AnsiColor,
    ]),
    SecondaryDeviceAttributes::new(DeviceType::Vt220, 10, 0),
    TertiaryDeviceAttributes::new(0U),
  )
  let terminal = StreamTerminal::new(write_pty=fn(data) {
    recorder.write_pty(data)
  })

  terminal.set_enquiry(fn() { b"OK" })
  terminal.set_xtversion(fn() { "myterm 1.0" })
  terminal.set_size(fn() { Some(Size::new(24, 80, 8, 16)) })
  terminal.set_color_scheme(fn() { Some(ColorScheme::Light) })
  terminal.set_device_attributes(fn() { Some(attributes) })
  terminal.next_slice(b"\x05\x1B[>q\x1B[18t\x1B[?996n\x1B[c")

  guard recorder.writes.length() == 5 else {
    fail("expected replaced callbacks to respond")
  }
  expect_parity_write(recorder, 0, b"OK")
  expect_parity_write(recorder, 1, b"\x1BP>|myterm 1.0\x1B\\")
  expect_parity_write(recorder, 2, b"\x1B[8;24;80t")
  expect_parity_write(recorder, 3, b"\x1B[?997;2n")
  expect_parity_write(recorder, 4, b"\x1B[?62;22c")

  terminal.clear_enquiry()
  terminal.clear_xtversion()
  terminal.clear_size()
  terminal.clear_color_scheme()
  terminal.clear_device_attributes()
  terminal.next_slice(b"\x05\x1B[>q\x1B[18t\x1B[?996n\x1B[c")

  guard recorder.writes.length() == 7 else {
    fail("expected clear paths to restore defaults and silences")
  }
  expect_parity_write(recorder, 5, b"\x1BP>|libghostty\x1B\\")
  expect_parity_write(recorder, 6, b"\x1B[?62;22c")

  terminal.deinit()
}

///|
test "stream terminal parity/set size callback" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    size=fn() { Some(Size::new(24, 80, 8, 16)) },
  )

  terminal.next_slice(b"\x1B[18t")

  guard recorder.writes.length() == 1 else {
    fail("expected size callback parity")
  }
  expect_parity_write(recorder, 0, b"\x1B[8;24;80t")

  terminal.deinit()
}

///|
test "stream terminal parity/metadata mode and reset controls" {
  let terminal = StreamTerminal::new()

  terminal.set_title("Hello")
  terminal.set_pwd("/workspace")
  terminal.set_pwd("")
  guard terminal.pwd() == None else {
    fail("expected empty pwd to clear state")
  }
  terminal.set_pwd("/workspace")
  terminal.mode_set(Mode::CursorVisible, false)
  terminal.mode_set(Mode::BracketedPaste, true)
  terminal.next_slice(b"Hello")

  guard terminal.title() == Some("Hello") &&
    terminal.pwd() == Some("/workspace") &&
    !terminal.mode_get(Mode::CursorVisible) &&
    terminal.mode_get(Mode::BracketedPaste) &&
    terminal.cursor_x() == 5 else {
    fail("expected metadata and mode controls before reset")
  }

  terminal.reset()
  guard terminal.title() == None else { fail("expected reset title default") }
  guard terminal.pwd() == None else { fail("expected reset pwd default") }
  guard terminal.mode_get(Mode::CursorVisible) else {
    fail("expected reset cursor-visible mode default")
  }
  guard !terminal.mode_get(Mode::BracketedPaste) else {
    fail("expected reset bracketed-paste mode default")
  }
  guard terminal.cursor_x() == 0 else { fail("expected reset cursor x") }
  guard terminal.cursor_y() == 0 else { fail("expected reset cursor y") }

  terminal.deinit()
}

///|
test "stream terminal parity/set device_attributes callback primary" {
  let recorder = StreamTerminalParityRecorder::new()
  let attributes = DeviceAttributes::new(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt420, [
      PrimaryDeviceAttributeFeature::AnsiColor,
      PrimaryDeviceAttributeFeature::Clipboard,
    ]),
    SecondaryDeviceAttributes::new(DeviceType::Vt220, 10, 0),
    TertiaryDeviceAttributes::new(0U),
  )
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    device_attributes=fn() { Some(attributes) },
  )

  terminal.next_slice(b"\x1B[c")

  guard recorder.writes.length() == 1 else {
    fail("expected primary device attributes parity")
  }
  expect_parity_write(recorder, 0, b"\x1B[?64;22;52c")

  terminal.deinit()
}

///|
test "stream terminal parity/set device_attributes callback secondary" {
  let recorder = StreamTerminalParityRecorder::new()
  let attributes = DeviceAttributes::new(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt220, [
      PrimaryDeviceAttributeFeature::AnsiColor,
    ]),
    SecondaryDeviceAttributes::new(DeviceType::Vt220, 10, 0),
    TertiaryDeviceAttributes::new(0U),
  )
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    device_attributes=fn() { Some(attributes) },
  )

  terminal.next_slice(b"\x1B[>c")

  guard recorder.writes.length() == 1 else {
    fail("expected secondary device attributes parity")
  }
  expect_parity_write(recorder, 0, b"\x1B[>1;10;0c")

  terminal.deinit()
}

///|
test "stream terminal parity/set device_attributes callback tertiary" {
  let recorder = StreamTerminalParityRecorder::new()
  let attributes = DeviceAttributes::new(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt220, []),
    SecondaryDeviceAttributes::new(DeviceType::Vt220, 0, 0),
    TertiaryDeviceAttributes::new(0xAABBCCDDU),
  )
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    device_attributes=fn() { Some(attributes) },
  )

  terminal.next_slice(b"\x1B[=c")

  guard recorder.writes.length() == 1 else {
    fail("expected tertiary device attributes parity")
  }
  expect_parity_write(recorder, 0, b"\x1BP!|AABBCCDD\x1B\\")

  terminal.deinit()
}

///|
test "stream terminal parity/device_attributes without callback uses default" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(write_pty=fn(data) {
    recorder.write_pty(data)
  })

  terminal.next_slice(b"\x1B[c")

  guard recorder.writes.length() == 1 else {
    fail("expected default device attributes parity")
  }
  expect_parity_write(recorder, 0, b"\x1B[?62;22c")

  terminal.deinit()
}

///|
test "stream terminal parity/device_attributes callback none uses default" {
  let recorder = StreamTerminalParityRecorder::new()
  let terminal = StreamTerminal::new(
    write_pty=fn(data) { recorder.write_pty(data) },
    device_attributes=fn() { None },
  )

  terminal.next_slice(b"\x1B[c")

  guard recorder.writes.length() == 1 else {
    fail("expected device attributes fallback parity")
  }
  expect_parity_write(recorder, 0, b"\x1B[?62;22c")

  terminal.deinit()
}

///|
test "stream terminal parity/get title set via vt_write" {
  let terminal = StreamTerminal::new()

  terminal.next_slice(b"\x1B]2;VT Title\x1B\\")

  guard terminal.title() == Some("VT Title") else {
    fail("expected title snapshot parity")
  }

  terminal.deinit()
}
