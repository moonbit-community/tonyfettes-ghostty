///|
test "device attributes/primary encodes defaults and features" {
  assert_eq(PrimaryDeviceAttributes::default().encode(), b"\x1B[?62;22c")
  assert_eq(
    PrimaryDeviceAttributes::new(Vt220, [AnsiColor, Clipboard]).encode(),
    b"\x1B[?62;22;52c",
  )
  assert_eq(
    PrimaryDeviceAttributes::new(Vt420, [Columns132, SelectiveErase, AnsiColor]).encode(),
    b"\x1B[?64;1;6;22c",
  )
  assert_eq(PrimaryDeviceAttributes::new(Vt100, []).encode(), b"\x1B[?1c")
}

///|
test "device attributes/secondary and tertiary encodings" {
  assert_eq(SecondaryDeviceAttributes::default().encode(), b"\x1B[>1;0;0c")
  assert_eq(
    TertiaryDeviceAttributes::default().encode(),
    b"\x1BP!|00000000\x1B\\",
  )
  assert_eq(
    TertiaryDeviceAttributes::new(0xAABBCCDD).encode(),
    b"\x1BP!|AABBCCDD\x1B\\",
  )
}

///|
test "device attributes/container encode dispatches by request" {
  let attributes = DeviceAttributes::default()
  assert_eq(attributes.encode(Primary), b"\x1B[?62;22c")
  assert_eq(attributes.encode(Secondary), b"\x1B[>1;0;0c")
  assert_eq(attributes.encode(Tertiary), b"\x1BP!|00000000\x1B\\")
}

///|
test "device attributes/constructors and accessors" {
  let primary = PrimaryDeviceAttributes::new(Vt220, [AnsiColor])
  guard primary.conformance_level() == Vt220 else {
    fail("expected primary conformance level")
  }
  guard primary.features() == [AnsiColor] else {
    fail("expected primary features")
  }

  let secondary = SecondaryDeviceAttributes::new(Vt220, 7, 8)
  guard secondary.device_type() == Vt220 else {
    fail("expected secondary device type")
  }
  assert_eq(secondary.firmware_version(), 7)
  assert_eq(secondary.rom_cartridge(), 8)

  let tertiary = TertiaryDeviceAttributes::new(9U)
  assert_eq(tertiary.unit_id(), 9U)

  let device_attributes = DeviceAttributes::new(primary, secondary, tertiary)
  guard device_attributes.primary() == primary else {
    fail("expected primary passthrough")
  }
  guard device_attributes.secondary() == secondary else {
    fail("expected secondary passthrough")
  }
  guard device_attributes.tertiary() == tertiary else {
    fail("expected tertiary passthrough")
  }
}

///|
test "device attributes/code helpers cover shared aliases" {
  let conformance : Array[(ConformanceLevel, UInt16)] = [
    (Vt100, 1),
    (Vt132, 4),
    (Vt102, 6),
    (Vt131, 7),
    (Vt125, 12),
    (Vt220, 62),
    (Vt240, 62),
    (Vt320, 63),
    (Vt340, 63),
    (Vt420, 64),
    (Vt510, 65),
    (Vt520, 65),
    (Vt525, 65),
  ]
  for entry in conformance {
    assert_eq(entry.0.code(), entry.1)
  }

  let features : Array[(PrimaryDeviceAttributeFeature, UInt16)] = [
    (Columns132, 1),
    (Printer, 2),
    (Regis, 3),
    (Sixel, 4),
    (SelectiveErase, 6),
    (UserDefinedKeys, 8),
    (NationalReplacement, 9),
    (TechnicalCharacters, 15),
    (Locator, 16),
    (TerminalState, 17),
    (Windowing, 18),
    (HorizontalScrolling, 21),
    (AnsiColor, 22),
    (RectangularEditing, 28),
    (AnsiTextLocator, 29),
    (Clipboard, 52),
  ]
  for entry in features {
    assert_eq(entry.0.code(), entry.1)
  }

  let device_types : Array[(DeviceType, UInt16)] = [
    (Vt100, 0),
    (Vt220, 1),
    (Vt240, 2),
    (Vt330, 18),
    (Vt340, 19),
    (Vt320, 24),
    (Vt382, 32),
    (Vt420, 41),
    (Vt510, 61),
    (Vt520, 64),
    (Vt525, 65),
  ]
  for entry in device_types {
    assert_eq(entry.0.code(), entry.1)
  }
}
