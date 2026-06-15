///|
/// X11 named-color resolution is exercised through the public `RGB::parse`
/// (the lookup table itself is private).
test "color/rgb parse resolves x11 names case-insensitively and trimmed" {
  let cases : Array[(Bytes, RGB)] = [
    (b"white", RGB::new(255, 255, 255)),
    (b"medium spring green", RGB::new(0, 250, 154)),
    (b"ForestGreen", RGB::new(34, 139, 34)),
    (b"FoReStGReen", RGB::new(34, 139, 34)),
    (b" black ", RGB::new(0, 0, 0)),
  ]
  for entry in cases {
    guard RGB::parse(entry.0) == entry.1 else {
      fail("unexpected x11 parse for \{entry.0}")
    }
  }

  // Blank (trims to empty) and unknown names are not colors.
  for bad in [b"   ", b"nosuchcolor"] {
    let result : Result[RGB, ColorParseError] = try RGB::parse(bad) catch {
      err => Err(err)
    } noraise {
      color => Ok(color)
    }
    guard result is Err(InvalidFormat) else {
      fail("expected invalid x11 name \{bad}")
    }
  }
}
