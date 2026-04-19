///|
test "device attributes/primary encodes defaults and features" {
  assert_eq(PrimaryDeviceAttributes::default().encode(), "\u{001B}[?62;22c")
  assert_eq(
    {
      conformance_level: ConformanceLevel::Vt220,
      features: [
        PrimaryDeviceAttributeFeature::AnsiColor,
        PrimaryDeviceAttributeFeature::Clipboard,
      ],
    }.encode(),
    "\u{001B}[?62;22;52c",
  )
  assert_eq(
    {
      conformance_level: ConformanceLevel::Vt420,
      features: [
        PrimaryDeviceAttributeFeature::Columns132,
        PrimaryDeviceAttributeFeature::SelectiveErase,
        PrimaryDeviceAttributeFeature::AnsiColor,
      ],
    }.encode(),
    "\u{001B}[?64;1;6;22c",
  )
  assert_eq(
    { conformance_level: ConformanceLevel::Vt100, features: [] }.encode(),
    "\u{001B}[?1c",
  )
}

///|
test "device attributes/secondary and tertiary encodings" {
  assert_eq(SecondaryDeviceAttributes::default().encode(), "\u{001B}[>1;0;0c")
  assert_eq(
    TertiaryDeviceAttributes::default().encode(),
    "\u{001B}P!|00000000\u{001B}\\",
  )
  assert_eq({ unit_id: 0xAABBCCDD }.encode(), "\u{001B}P!|AABBCCDD\u{001B}\\")
}

///|
test "device attributes/container encode dispatches by request" {
  let attributes = DeviceAttributes::default()
  assert_eq(
    attributes.encode(DeviceAttributeRequest::Primary),
    "\u{001B}[?62;22c",
  )
  assert_eq(
    attributes.encode(DeviceAttributeRequest::Secondary),
    "\u{001B}[>1;0;0c",
  )
  assert_eq(
    attributes.encode(DeviceAttributeRequest::Tertiary),
    "\u{001B}P!|00000000\u{001B}\\",
  )
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
  assert_eq(hex8(0), "00000000")
  assert_eq(hex8(0x1234), "00001234")
  assert_eq(hex8(0x89ABCDEF), "89ABCDEF")
  assert_eq(hex_digit_upper(0), '0')
  assert_eq(hex_digit_upper(9), '9')
  assert_eq(hex_digit_upper(10), 'A')
  assert_eq(hex_digit_upper(15), 'F')
}
