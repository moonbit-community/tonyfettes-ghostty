///|
test "focus/encode events" {
  assert_eq(FocusEvent::Gained.encode(), b"\x1B[I")
  assert_eq(FocusEvent::Lost.encode(), b"\x1B[O")
}
