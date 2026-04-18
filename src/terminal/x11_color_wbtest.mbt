///|
test "x11 color lookup handles aliases case and trimming" {
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
