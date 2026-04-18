///|
test "color/name defaults and codes" {
  assert_eq(Name::Black.code(), 0)
  assert_eq(Name::BrightWhite.code(), 15)
  guard Name::Red.default_rgb() == { r: 0xCC, g: 0x66, b: 0x66 } else {
    fail("unexpected red default")
  }
  guard Name::BrightBlue.default_rgb() == { r: 0x7A, g: 0xA6, b: 0xDA } else {
    fail("unexpected bright blue default")
  }
}

///|
test "color/special osc4" {
  assert_eq(Special::Bold.osc4(), 256)
  assert_eq(Special::Underline.osc4(), 257)
  assert_eq(Special::Blink.osc4(), 258)
  assert_eq(Special::Reverse.osc4(), 259)
  assert_eq(Special::Italic.osc4(), 260)
}

///|
test "color/dynamic next" {
  assert_eq(Dynamic::Foreground.code(), 10)
  guard Dynamic::Foreground.next() == Some(Dynamic::Background) else {
    fail("unexpected foreground successor")
  }
  guard Dynamic::Cursor.next() == Some(Dynamic::PointerForeground) else {
    fail("unexpected cursor successor")
  }
  guard Dynamic::TektronixCursor.next() == Some(Dynamic::HighlightForeground) else {
    fail("unexpected tektronix cursor successor")
  }
  guard Dynamic::HighlightForeground.next() == None else {
    fail("highlight foreground should end the sequence")
  }
}

///|
test "color/rgb parse accepts hash rgb rgbi and x11 names" {
  let cases : Array[(String, RGB)] = [
    ("rgbi:1.0/0/0", { r: 255, g: 0, b: 0 }),
    ("rgb:7f/a0a0/0", { r: 127, g: 160, b: 0 }),
    ("rgb:f/ff/fff", { r: 255, g: 255, b: 255 }),
    ("#ffffff", { r: 255, g: 255, b: 255 }),
    ("#fff", { r: 255, g: 255, b: 255 }),
    ("#fffffffff", { r: 255, g: 255, b: 255 }),
    ("#ffffffffffff", { r: 255, g: 255, b: 255 }),
    ("#ff0010", { r: 255, g: 0, b: 16 }),
    ("LawnGreen", { r: 124, g: 252, b: 0 }),
    ("medium spring green", { r: 0, g: 250, b: 154 }),
    (" Forest Green ", { r: 34, g: 139, b: 34 }),
  ]

  for entry in cases {
    guard RGB::parse(entry.0) == entry.1 else {
      fail("unexpected parse result for \{entry.0}")
    }
  }
}

///|
test "color/rgb parse rejects invalid formats" {
  let invalid : Array[String] = [
    "rgb;", "rgb:", ":a/a/a", "a/a/a", "rgb:a/a/a/", "rgb:00000///", "rgb:000/",
    "rgbi:a/a/a", "rgb:0.5/0.0/1.0", "rgb:not/hex/zz", "#", "#ff", "#ffff", "#fffff",
    "#gggggg",
  ]

  for value in invalid {
    let result : Result[RGB, ColorParseError] = try? RGB::parse(value)
    guard result is Err(ColorParseError::InvalidFormat) else {
      fail("expected invalid format for \{value}")
    }
  }
}
