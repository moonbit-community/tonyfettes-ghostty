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
test "color/all named colors roundtrip through default palette data" {
  let names : Array[(Name, Byte, RGB)] = [
    (Name::Black, 0, { r: 0x1D, g: 0x1F, b: 0x21 }),
    (Name::Red, 1, { r: 0xCC, g: 0x66, b: 0x66 }),
    (Name::Green, 2, { r: 0xB5, g: 0xBD, b: 0x68 }),
    (Name::Yellow, 3, { r: 0xF0, g: 0xC6, b: 0x74 }),
    (Name::Blue, 4, { r: 0x81, g: 0xA2, b: 0xBE }),
    (Name::Magenta, 5, { r: 0xB2, g: 0x94, b: 0xBB }),
    (Name::Cyan, 6, { r: 0x8A, g: 0xBE, b: 0xB7 }),
    (Name::White, 7, { r: 0xC5, g: 0xC8, b: 0xC6 }),
    (Name::BrightBlack, 8, { r: 0x66, g: 0x66, b: 0x66 }),
    (Name::BrightRed, 9, { r: 0xD5, g: 0x4E, b: 0x53 }),
    (Name::BrightGreen, 10, { r: 0xB9, g: 0xCA, b: 0x4A }),
    (Name::BrightYellow, 11, { r: 0xE7, g: 0xC5, b: 0x47 }),
    (Name::BrightBlue, 12, { r: 0x7A, g: 0xA6, b: 0xDA }),
    (Name::BrightMagenta, 13, { r: 0xC3, g: 0x97, b: 0xD8 }),
    (Name::BrightCyan, 14, { r: 0x70, g: 0xC0, b: 0xB1 }),
    (Name::BrightWhite, 15, { r: 0xEA, g: 0xEA, b: 0xEA }),
  ]

  for entry in names {
    assert_eq(entry.0.code(), entry.1)
    guard entry.0.default_rgb() == entry.2 else {
      fail("unexpected default rgb for named color \{entry.1}")
    }
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
test "color/dynamic codes cover every osc dynamic slot" {
  let entries : Array[(Dynamic, UInt16)] = [
    (Dynamic::Foreground, 10),
    (Dynamic::Background, 11),
    (Dynamic::Cursor, 12),
    (Dynamic::PointerForeground, 13),
    (Dynamic::PointerBackground, 14),
    (Dynamic::TektronixForeground, 15),
    (Dynamic::TektronixBackground, 16),
    (Dynamic::HighlightBackground, 17),
    (Dynamic::TektronixCursor, 18),
    (Dynamic::HighlightForeground, 19),
  ]
  for entry in entries {
    assert_eq(entry.0.code(), entry.1)
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
    "", "rgb;", "rgb:", "rgbi0/0/0", "rgb:abcd", ":a/a/a", "a/a/a", "rgb:a/a/a/",
    "rgb:00000///", "rgb:000/", "rgbi:a/a/a", "rgb:0.5/0.0/1.0", "rgb:not/hex/zz",
    "#", "#ff", "#ffff", "#fffff", "#gggggg",
  ]

  for value in invalid {
    let result : Result[RGB, ColorParseError] = try? RGB::parse(value)
    guard result is Err(ColorParseError::InvalidFormat) else {
      fail("expected invalid format for \{value}")
    }
  }
}

///|
test "color/private helper parsing covers widths intensities and search" {
  assert_eq(parse_hex_component("A", 0, 1), 0xAA)
  assert_eq(parse_hex_component("80", 0, 2), 0x80)
  assert_eq(parse_hex_component("800", 0, 3), 0x7F)
  assert_eq(parse_hex_component("8000", 0, 4), 0x7F)

  assert_eq(parse_intensity_component("1", 0, 1), 0xFF)
  assert_eq(parse_intensity_component("0.5", 0, 3), 0x7F)
  assert_eq(parse_intensity_component(".5", 0, 2), 0x7F)
  assert_eq(parse_intensity_component("1.", 0, 2), 0xFF)

  guard find_char("rgb:1/2/3", 0, '/') == Some(5) else {
    fail("expected first slash position")
  }
  guard find_char("rgb:1/2/3", 6, '/') == Some(7) else {
    fail("expected second slash position")
  }
  guard find_char("rgb:1/2/3", 8, '/') == None else {
    fail("expected no later slash")
  }

  guard hex_digit('0') == Some(0) else { fail("expected decimal zero") }
  guard hex_digit('f') == Some(15) else { fail("expected lowercase hex") }
  guard hex_digit('A') == Some(10) else { fail("expected uppercase hex") }
  guard hex_digit('x') == None else { fail("expected invalid hex digit") }
}

///|
test "color/private helper parsing rejects invalid helper inputs" {
  let invalid_hex : Array[(String, Int, Int)] = [
    ("", 0, 0),
    ("12345", 0, 5),
    ("zz", 0, 2),
  ]
  for entry in invalid_hex {
    let result : Result[Byte, ColorParseError] = try? parse_hex_component(
      entry.0,
      entry.1,
      entry.2,
    )
    guard result is Err(ColorParseError::InvalidFormat) else {
      fail("expected invalid hex helper input for \{entry.0}")
    }
  }

  let invalid_intensity : Array[(String, Int, Int)] = [
    ("", 0, 0),
    (".", 0, 1),
    ("1.1", 0, 3),
    ("1..0", 0, 4),
    ("a", 0, 1),
  ]
  for entry in invalid_intensity {
    let result : Result[Byte, ColorParseError] = try? parse_intensity_component(
      entry.0,
      entry.1,
      entry.2,
    )
    guard result is Err(ColorParseError::InvalidFormat) else {
      fail("expected invalid intensity helper input for \{entry.0}")
    }
  }
}
