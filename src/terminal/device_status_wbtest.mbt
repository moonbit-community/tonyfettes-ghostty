///|
test "device status/request lookup and packed tag layout" {
  guard device_status_request_from_int(5, false) ==
    Some(DeviceStatusRequest::OperatingStatus) else {
    fail("expected operating status request")
  }
  guard device_status_request_from_int(6, false) ==
    Some(DeviceStatusRequest::CursorPosition) else {
    fail("expected cursor position request")
  }
  guard device_status_request_from_int(996, true) ==
    Some(DeviceStatusRequest::ColorScheme) else {
    fail("expected color scheme request")
  }
  guard device_status_request_from_int(996, false) == None else {
    fail("unexpected non-question color scheme request")
  }

  let tag = DeviceStatusRequest::ColorScheme.tag()
  assert_eq(tag.raw(), 0x83E4)
  assert_eq(tag.value(), 996)
  assert_eq(tag.question(), true)

  let roundtrip = device_status_tag_from_raw(0x8005)
  assert_eq(roundtrip.value(), 5)
  assert_eq(roundtrip.question(), true)
}
