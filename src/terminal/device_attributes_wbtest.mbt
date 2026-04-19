///|
fn encode_hex8(value : UInt) -> Bytes {
  let buffer = @buffer.new(size_hint=8)
  write_hex8(buffer, value)
  buffer.contents()
}

///|
test "device attributes/primary encodes defaults and features" {
  assert_eq(PrimaryDeviceAttributes::default().encode(), b"\x1B[?62;22c")
  assert_eq(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt220, [
      PrimaryDeviceAttributeFeature::AnsiColor,
      PrimaryDeviceAttributeFeature::Clipboard,
    ]).encode(),
    b"\x1B[?62;22;52c",
  )
  assert_eq(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt420, [
      PrimaryDeviceAttributeFeature::Columns132,
      PrimaryDeviceAttributeFeature::SelectiveErase,
      PrimaryDeviceAttributeFeature::AnsiColor,
    ]).encode(),
    b"\x1B[?64;1;6;22c",
  )
  assert_eq(
    PrimaryDeviceAttributes::new(ConformanceLevel::Vt100, []).encode(),
    b"\x1B[?1c",
  )
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
  assert_eq(attributes.encode(DeviceAttributeRequest::Primary), b"\x1B[?62;22c")
  assert_eq(
    attributes.encode(DeviceAttributeRequest::Secondary),
    b"\x1B[>1;0;0c",
  )
  assert_eq(
    attributes.encode(DeviceAttributeRequest::Tertiary),
    b"\x1BP!|00000000\x1B\\",
  )
}

///|
test "device attributes/constructors and accessors" {
  let primary = PrimaryDeviceAttributes::new(ConformanceLevel::Vt220, [
    PrimaryDeviceAttributeFeature::AnsiColor,
  ])
  guard primary.conformance_level() == ConformanceLevel::Vt220 else {
    fail("expected primary conformance level")
  }
  guard primary.features() == [PrimaryDeviceAttributeFeature::AnsiColor] else {
    fail("expected primary features")
  }

  let secondary = SecondaryDeviceAttributes::new(DeviceType::Vt220, 7, 8)
  guard secondary.device_type() == DeviceType::Vt220 else {
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
    (ConformanceLevel::Vt100, 1),
    (ConformanceLevel::Vt132, 4),
    (ConformanceLevel::Vt102, 6),
    (ConformanceLevel::Vt131, 7),
    (ConformanceLevel::Vt125, 12),
    (ConformanceLevel::Vt220, 62),
    (ConformanceLevel::Vt240, 62),
    (ConformanceLevel::Vt320, 63),
    (ConformanceLevel::Vt340, 63),
    (ConformanceLevel::Vt420, 64),
    (ConformanceLevel::Vt510, 65),
    (ConformanceLevel::Vt520, 65),
    (ConformanceLevel::Vt525, 65),
  ]
  for entry in conformance {
    assert_eq(entry.0.code(), entry.1)
  }

  let features : Array[(PrimaryDeviceAttributeFeature, UInt16)] = [
    (PrimaryDeviceAttributeFeature::Columns132, 1),
    (PrimaryDeviceAttributeFeature::Printer, 2),
    (PrimaryDeviceAttributeFeature::Regis, 3),
    (PrimaryDeviceAttributeFeature::Sixel, 4),
    (PrimaryDeviceAttributeFeature::SelectiveErase, 6),
    (PrimaryDeviceAttributeFeature::UserDefinedKeys, 8),
    (PrimaryDeviceAttributeFeature::NationalReplacement, 9),
    (PrimaryDeviceAttributeFeature::TechnicalCharacters, 15),
    (PrimaryDeviceAttributeFeature::Locator, 16),
    (PrimaryDeviceAttributeFeature::TerminalState, 17),
    (PrimaryDeviceAttributeFeature::Windowing, 18),
    (PrimaryDeviceAttributeFeature::HorizontalScrolling, 21),
    (PrimaryDeviceAttributeFeature::AnsiColor, 22),
    (PrimaryDeviceAttributeFeature::RectangularEditing, 28),
    (PrimaryDeviceAttributeFeature::AnsiTextLocator, 29),
    (PrimaryDeviceAttributeFeature::Clipboard, 52),
  ]
  for entry in features {
    assert_eq(entry.0.code(), entry.1)
  }

  let device_types : Array[(DeviceType, UInt16)] = [
    (DeviceType::Vt100, 0),
    (DeviceType::Vt220, 1),
    (DeviceType::Vt240, 2),
    (DeviceType::Vt330, 18),
    (DeviceType::Vt340, 19),
    (DeviceType::Vt320, 24),
    (DeviceType::Vt382, 32),
    (DeviceType::Vt420, 41),
    (DeviceType::Vt510, 61),
    (DeviceType::Vt520, 64),
    (DeviceType::Vt525, 65),
  ]
  for entry in device_types {
    assert_eq(entry.0.code(), entry.1)
  }
}

///|
test "device attributes/private hex helpers produce fixed width uppercase text" {
  assert_eq(encode_hex8(0), b"00000000")
  assert_eq(encode_hex8(0x1234), b"00001234")
  assert_eq(encode_hex8(0x89ABCDEF), b"89ABCDEF")
  assert_eq(hex_digit_upper(0), b'0')
  assert_eq(hex_digit_upper(9), b'9')
  assert_eq(hex_digit_upper(10), b'A')
  assert_eq(hex_digit_upper(15), b'F')
}
