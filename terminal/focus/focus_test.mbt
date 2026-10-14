///|
test "focus/encode events" {
  assert_eq(@focus.FocusEvent::Gained.encode(), b"\x1B[I")
  assert_eq(@focus.FocusEvent::Lost.encode(), b"\x1B[O")
}
