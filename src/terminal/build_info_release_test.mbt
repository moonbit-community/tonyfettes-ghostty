///|
test "build_info/release builds collapse to release_safe optimize mode" {
  guard build_info().optimize() == OptimizeMode::ReleaseSafe else {
    fail("expected release_safe optimize mode")
  }
}
