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
