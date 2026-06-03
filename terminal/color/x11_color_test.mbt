///|
test "x11 color lookup handles aliases case and trimming" {
  guard x11_color_lookup("   ") == None else {
    fail("expected blank trimmed lookup to fail")
  }
  guard x11_color_lookup("white") == Some(RGB::new(255, 255, 255)) else {
    fail("expected white lookup")
  }
  guard x11_color_lookup("medium spring green") == Some(RGB::new(0, 250, 154)) else {
    fail("expected spaced alias lookup")
  }
  guard x11_color_lookup("ForestGreen") == Some(RGB::new(34, 139, 34)) else {
    fail("expected mixed-case lookup")
  }
  guard x11_color_lookup("FoReStGReen") == Some(RGB::new(34, 139, 34)) else {
    fail("expected case-insensitive lookup")
  }
  guard x11_color_lookup(" black ") == Some(RGB::new(0, 0, 0)) else {
    fail("expected trimmed lookup")
  }
  guard x11_color_lookup("nosuchcolor") == None else {
    fail("unexpected missing color lookup")
  }
}
