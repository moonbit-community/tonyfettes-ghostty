///|
test "build_info/debug builds report debug optimize mode" {
  guard @terminal.build_info().optimize() == Debug else {
    fail("expected debug optimize mode")
  }
}
