///|
/// X11 named-color resolution is exercised through the public `RGB::parse`
/// (the lookup table itself is private).
test "color/rgb parse resolves x11 names case-insensitively and trimmed" {
  let cases : Array[(Bytes, @color.RGB)] = [
    (b"white", @color.RGB::new(255, 255, 255)),
    (b"medium spring green", @color.RGB::new(0, 250, 154)),
    (b"ForestGreen", @color.RGB::new(34, 139, 34)),
    (b"FoReStGReen", @color.RGB::new(34, 139, 34)),
    (b" black ", @color.RGB::new(0, 0, 0)),
  ]
  for entry in cases {
    guard @color.RGB::parse(entry.0) == entry.1 else {
      fail("unexpected x11 parse for \{entry.0}")
    }
  }

  // Blank (trims to empty) and unknown names are not colors.
  for bad in [b"   ", b"nosuchcolor"] {
    let result : Result[@color.RGB, @color.ColorParseError] = try
      @color.RGB::parse(bad)
    catch {
      err => Err(err)
    } noraise {
      color => Ok(color)
    }
    guard result is Err(InvalidFormat) else {
      fail("expected invalid x11 name \{bad}")
    }
  }
}
