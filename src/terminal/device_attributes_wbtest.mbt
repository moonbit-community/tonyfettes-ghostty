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
