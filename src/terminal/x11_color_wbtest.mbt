///|
test "x11 color lookup handles aliases case and trimming" {
  guard x11_color_lookup("   ") == None else {
    fail("expected blank trimmed lookup to fail")
  }
  guard x11_color_lookup("white") == Some({ r: 255, g: 255, b: 255 }) else {
    fail("expected white lookup")
  }
  guard x11_color_lookup("medium spring green") ==
    Some({ r: 0, g: 250, b: 154 }) else {
    fail("expected spaced alias lookup")
  }
  guard x11_color_lookup("ForestGreen") == Some({ r: 34, g: 139, b: 34 }) else {
    fail("expected mixed-case lookup")
  }
  guard x11_color_lookup("FoReStGReen") == Some({ r: 34, g: 139, b: 34 }) else {
    fail("expected case-insensitive lookup")
  }
  guard x11_color_lookup(" black ") == Some({ r: 0, g: 0, b: 0 }) else {
    fail("expected trimmed lookup")
  }
  guard x11_color_lookup("nosuchcolor") == None else {
    fail("unexpected missing color lookup")
  }
}

///|
test "x11 color/private helpers trim and compare ascii case-insensitively" {
  assert_eq(trim_name_bounds("  ForestGreen  "), (2, 13))
  assert_eq(trim_name_bounds("   "), (3, 3))
  guard ascii_equals_ignore_case("FoReStGrEeN", 0, "forestgreen") else {
    fail("expected exact mixed-case match")
  }
  guard ascii_equals_ignore_case("xxForestGreen", 2, "forestgreen") else {
    fail("expected offset mixed-case match")
  }
  guard !ascii_equals_ignore_case("Forest Blue", 0, "forestgreen") else {
    fail("expected helper mismatch")
  }
  assert_eq(ascii_lower('A'), 'a')
  assert_eq(ascii_lower('Z'), 'z')
  assert_eq(ascii_lower('a'), 'a')
  assert_eq(ascii_lower('9'), '9')
}
