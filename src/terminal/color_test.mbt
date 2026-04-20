///|
test "color/name defaults and codes" {
  assert_eq(Name::Black.code(), 0)
  assert_eq(Name::BrightWhite.code(), 15)
  guard Name::Red.default_rgb() == RGB::new(0xCC, 0x66, 0x66) else {
    fail("unexpected red default")
  }
  guard Name::BrightBlue.default_rgb() == RGB::new(0x7A, 0xA6, 0xDA) else {
    fail("unexpected bright blue default")
  }
}

///|
test "color/all named colors roundtrip through default palette data" {
  let names : Array[(Name, Byte, RGB)] = [
    (Name::Black, 0, RGB::new(0x1D, 0x1F, 0x21)),
    (Name::Red, 1, RGB::new(0xCC, 0x66, 0x66)),
    (Name::Green, 2, RGB::new(0xB5, 0xBD, 0x68)),
    (Name::Yellow, 3, RGB::new(0xF0, 0xC6, 0x74)),
    (Name::Blue, 4, RGB::new(0x81, 0xA2, 0xBE)),
    (Name::Magenta, 5, RGB::new(0xB2, 0x94, 0xBB)),
    (Name::Cyan, 6, RGB::new(0x8A, 0xBE, 0xB7)),
    (Name::White, 7, RGB::new(0xC5, 0xC8, 0xC6)),
    (Name::BrightBlack, 8, RGB::new(0x66, 0x66, 0x66)),
    (Name::BrightRed, 9, RGB::new(0xD5, 0x4E, 0x53)),
    (Name::BrightGreen, 10, RGB::new(0xB9, 0xCA, 0x4A)),
    (Name::BrightYellow, 11, RGB::new(0xE7, 0xC5, 0x47)),
    (Name::BrightBlue, 12, RGB::new(0x7A, 0xA6, 0xDA)),
    (Name::BrightMagenta, 13, RGB::new(0xC3, 0x97, 0xD8)),
    (Name::BrightCyan, 14, RGB::new(0x70, 0xC0, 0xB1)),
    (Name::BrightWhite, 15, RGB::new(0xEA, 0xEA, 0xEA)),
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
    ("rgbi:1.0/0/0", RGB::new(255, 0, 0)),
    ("rgb:7f/a0a0/0", RGB::new(127, 160, 0)),
    ("rgb:f/ff/fff", RGB::new(255, 255, 255)),
    ("#ffffff", RGB::new(255, 255, 255)),
    ("#fff", RGB::new(255, 255, 255)),
    ("#fffffffff", RGB::new(255, 255, 255)),
    ("#ffffffffffff", RGB::new(255, 255, 255)),
    ("#ff0010", RGB::new(255, 0, 16)),
    ("LawnGreen", RGB::new(124, 252, 0)),
    ("medium spring green", RGB::new(0, 250, 154)),
    (" Forest Green ", RGB::new(34, 139, 34)),
  ]

  for entry in cases {
    guard RGB::parse(entry.0) == entry.1 else {
      fail("unexpected parse result for \{entry.0}")
    }
  }
}

///|
test "color/rgb constructor and accessors" {
  let rgb = RGB::new(1, 2, 3)
  assert_eq(rgb.r(), 1)
  assert_eq(rgb.g(), 2)
  assert_eq(rgb.b(), 3)
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
test "color/rgb parse handles public width and intensity edge cases" {
  let valid : Array[(String, RGB)] = [
    ("#ABC", RGB::new(0xAA, 0xBB, 0xCC)),
    ("#800800800", RGB::new(0x7F, 0x7F, 0x7F)),
    ("#800080008000", RGB::new(0x7F, 0x7F, 0x7F)),
    ("rgbi:1/0/0", RGB::new(0xFF, 0, 0)),
    ("rgbi:0.5/0/0", RGB::new(0x7F, 0, 0)),
    ("rgbi:.5/0/0", RGB::new(0x7F, 0, 0)),
    ("rgbi:1./0/0", RGB::new(0xFF, 0, 0)),
  ]
  for entry in valid {
    guard RGB::parse(entry.0) == entry.1 else {
      fail("unexpected public parse result for \{entry.0}")
    }
  }
}

///|
test "color/rgb parse rejects malformed public edge cases" {
  let invalid : Array[String] = [
    "#12345", "#zzzzzz", "rgb:12345/0/0", "rgbi:./0/0", "rgbi:1.1/0/0", "rgbi:1..0/0/0",
    "rgb:1/2/3/",
  ]
  for value in invalid {
    let result : Result[RGB, ColorParseError] = try? RGB::parse(value)
    guard result is Err(ColorParseError::InvalidFormat) else {
      fail("expected invalid public parse input for \{value}")
    }
  }
}

///|
test "color/default palette covers named cube and grayscale entries" {
  let palette = default_palette()
  guard palette[0] == Name::Black.default_rgb() else {
    fail("expected named palette entry")
  }
  guard palette[15] == Name::BrightWhite.default_rgb() else {
    fail("expected bright named palette entry")
  }
  guard palette[16] == RGB::new(0, 0, 0) else {
    fail("expected color cube start")
  }
  guard palette[21] == RGB::new(0, 0, 255) else {
    fail("expected color cube blue edge")
  }
  guard palette[231] == RGB::new(255, 255, 255) else {
    fail("expected color cube end")
  }
  guard palette[232] == RGB::new(8, 8, 8) else {
    fail("expected grayscale ramp start")
  }
  guard palette[255] == RGB::new(238, 238, 238) else {
    fail("expected grayscale ramp end")
  }
}

///|
test "color/dynamic rgb unset set and reset" {
  let unset = DynamicRGB::unset()
  guard unset.get() == None else {
    fail("expected unset dynamic rgb to have no value")
  }

  let value = DynamicRGB::init(RGB::new(1, 2, 3))
  guard value.get() == Some(RGB::new(1, 2, 3)) else {
    fail("expected default dynamic rgb value")
  }

  value.set(RGB::new(4, 5, 6))
  guard value.get() == Some(RGB::new(4, 5, 6)) else {
    fail("expected override dynamic rgb value")
  }

  value.reset()
  guard value.get() == Some(RGB::new(1, 2, 3)) else {
    fail("expected reset dynamic rgb value")
  }
}

///|
test "color/dynamic palette set reset and reset_all" {
  let palette = DynamicPalette::new()
  let default_zero = palette.color(0)

  let color = RGB::new(255, 0, 0)
  palette.set(0, color)
  guard palette.color(0) == color else {
    fail("expected palette override color")
  }

  palette.reset(0)
  guard palette.color(0) == default_zero else {
    fail("expected palette reset to restore original color")
  }

  palette.set(0, color)
  palette.set(5, RGB::new(0, 255, 0))
  palette.reset_all()
  guard palette.color(0) == default_zero else {
    fail("expected reset_all to restore index 0")
  }
  guard palette.color(5) == Name::Magenta.default_rgb() else {
    fail("expected reset_all to restore index 5")
  }
}

///|
test "color/dynamic palette change_default preserves overrides" {
  let palette = DynamicPalette::new()
  let custom = RGB::new(255, 0, 0)
  palette.set(5, custom)

  let defaults = default_palette()
  defaults[0] = RGB::new(100, 100, 100)
  defaults[5] = RGB::new(50, 50, 50)
  palette.change_default(defaults)

  guard palette.color(0) == RGB::new(100, 100, 100) else {
    fail("expected unchanged indexes to adopt new defaults")
  }
  guard palette.color(5) == custom else {
    fail("expected overridden indexes to keep custom colors")
  }
}

///|
test "color/terminal colors wrap dynamic color state" {
  let colors = TerminalColors::new()
  guard colors.background() == None &&
    colors.foreground() == None &&
    colors.cursor() == None else {
    fail("expected terminal colors to start unset")
  }
  guard colors.palette_color(1) == Name::Red.default_rgb() else {
    fail("expected terminal colors to expose default palette")
  }

  colors.set_background(RGB::new(1, 2, 3))
  colors.set_foreground(RGB::new(4, 5, 6))
  colors.set_cursor(RGB::new(7, 8, 9))
  colors.set_palette_color(1, RGB::new(9, 9, 9))
  guard colors.background() == Some(RGB::new(1, 2, 3)) &&
    colors.foreground() == Some(RGB::new(4, 5, 6)) &&
    colors.cursor() == Some(RGB::new(7, 8, 9)) &&
    colors.palette_color(1) == RGB::new(9, 9, 9) else {
    fail("expected terminal colors mutations to stick")
  }

  colors.reset_background()
  colors.reset_foreground()
  colors.reset_cursor()
  colors.reset_palette_color(1)
  guard colors.background() == None &&
    colors.foreground() == None &&
    colors.cursor() == None &&
    colors.palette_color(1) == Name::Red.default_rgb() else {
    fail("expected terminal colors resets to restore defaults")
  }

  let defaults = default_palette()
  defaults[2] = RGB::new(33, 44, 55)
  colors.change_default_palette(defaults)
  guard colors.palette_color(2) == RGB::new(33, 44, 55) else {
    fail("expected terminal colors default palette update")
  }

  colors.set_palette_color(3, RGB::new(66, 77, 88))
  colors.reset_palette()
  guard colors.palette_color(2) == RGB::new(33, 44, 55) else {
    fail("expected reset_palette to keep changed defaults")
  }
  guard colors.palette_color(3) == Name::Yellow.default_rgb() else {
    fail("expected reset_palette to clear palette overrides")
  }
}
