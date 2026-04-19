///|
fn test_parse(params : Array[UInt16]) -> Attribute {
  let parser : SgrParser = { params, params_sep: SepList::init_empty(), idx: 0 }
  parser.next().unwrap()
}

///|
fn parser_with_colons(
  params : Array[UInt16],
  colon_indices : Array[Int],
) -> SgrParser {
  let params_sep = SepList::init_empty()
  for index in colon_indices {
    params_sep.set(index)
  }
  { params, params_sep, idx: 0 }
}

///|
fn expect_attr_eq(
  actual : Attribute,
  expected : Attribute,
  message : String,
) -> Unit raise {
  guard actual == expected else { fail(message) }
}

///|
fn expect_next_eq(
  parser : SgrParser,
  expected : Attribute,
  message : String,
) -> Unit raise {
  guard parser.next() == Some(expected) else { fail(message) }
}

///|
fn expect_none(parser : SgrParser, message : String) -> Unit raise {
  guard parser.next() == None else { fail(message) }
}

///|
test "sgr/parser basic direct colors and empty input" {
  let empty = SgrParser::empty()
  expect_next_eq(empty, Unset, "expected empty sgr parser to yield unset")
  expect_attr_eq(test_parse([0]), Unset, "expected sgr 0 to unset")

  guard test_parse([38, 2, 40, 44, 52]) is DirectColorFg(rgb) &&
    rgb == { r: 40, g: 44, b: 52 } else {
    fail("expected direct fg color")
  }

  guard test_parse([48, 2, 40, 44, 52]) is DirectColorBg(rgb) &&
    rgb == { r: 40, g: 44, b: 52 } else {
    fail("expected direct bg color")
  }
}

///|
test "sgr/parser multiple next calls and null termination" {
  let parser : SgrParser = {
    params: [0, 38, 2, 40, 44, 52],
    params_sep: SepList::init_empty(),
    idx: 0,
  }
  expect_next_eq(parser, Unset, "expected first value to unset")
  guard parser.next() is Some(DirectColorFg(rgb)) &&
    rgb == { r: 40, g: 44, b: 52 } else {
    fail("expected direct fg color on second item")
  }
  expect_none(parser, "expected parser to finish after direct fg")
  expect_none(parser, "expected parser to stay finished")
}

///|
test "sgr/unsupported colon runs degrade to unknown and continue" {
  let one = parser_with_colons([0, 4, 1], [0])
  guard one.next() is Some(Unknown(_)) else {
    fail("expected first colon run to be unknown")
  }
  expect_next_eq(one, Bold, "expected bold after unknown colon run")
  expect_none(one, "expected one colon parser to finish")

  let many = parser_with_colons([0, 4, 2, 1], [0, 1])
  guard many.next() is Some(Unknown(_)) else {
    fail("expected multi-colon run to be unknown")
  }
  expect_next_eq(many, Bold, "expected bold after multi-colon unknown run")
  expect_none(many, "expected multi-colon parser to finish")
}

///|
test "sgr/style toggles and resets" {
  expect_attr_eq(test_parse([1]), Bold, "expected bold")
  expect_attr_eq(test_parse([2]), Faint, "expected faint")
  expect_attr_eq(test_parse([22]), ResetBold, "expected reset bold")
  expect_attr_eq(test_parse([3]), Italic, "expected italic")
  expect_attr_eq(test_parse([23]), ResetItalic, "expected reset italic")
  expect_attr_eq(test_parse([5]), Blink, "expected blink")
  expect_attr_eq(test_parse([6]), Blink, "expected rapid blink to map to blink")
  expect_attr_eq(test_parse([25]), ResetBlink, "expected reset blink")
  expect_attr_eq(test_parse([7]), Inverse, "expected inverse")
  expect_attr_eq(test_parse([27]), ResetInverse, "expected reset inverse")
  expect_attr_eq(test_parse([8]), Invisible, "expected invisible")
  expect_attr_eq(test_parse([28]), ResetInvisible, "expected reset invisible")
  expect_attr_eq(test_parse([9]), Strikethrough, "expected strikethrough")
  expect_attr_eq(
    test_parse([29]),
    ResetStrikethrough,
    "expected reset strikethrough",
  )
  expect_attr_eq(test_parse([53]), Overline, "expected overline")
  expect_attr_eq(test_parse([55]), ResetOverline, "expected reset overline")
}

///|
test "sgr/private helpers and fallback branches" {
  let trailing_unknown = parser_with_colons([1], [0])
  guard trailing_unknown.next() is Some(Unknown(unknown)) else {
    fail("expected trailing-colon run to be unknown")
  }
  guard unknown.partial == [1] else {
    fail("expected trailing-colon partial slice")
  }

  expect_next_eq(
    parser_with_colons([4, 9], [0]),
    Attribute::Underline(Underline::Single),
    "expected unknown underline style to fall back to single",
  )
  expect_attr_eq(test_parse([39]), ResetFg, "expected reset fg")
  expect_attr_eq(test_parse([49]), ResetBg, "expected reset bg")

  guard test_parse([999]) is Unknown(_) else {
    fail("expected unrecognized sgr to be unknown")
  }
  guard test_parse([38]) is Unknown(_) else {
    fail("expected short color selector to be unknown")
  }
  guard test_parse([38, 9]) is Unknown(_) else {
    fail("expected invalid color selector mode to be unknown")
  }
  guard test_parse([58]) is Unknown(_) else {
    fail("expected short underline color selector to be unknown")
  }
  guard test_parse([58, 5]) is Unknown(_) else {
    fail("expected short underline 256 selector to be unknown")
  }
  guard test_parse([58, 2, 1, 2]) is Unknown(_) else {
    fail("expected short direct underline selector to be unknown")
  }

  guard name_from_code(0) == Name::Black else { fail("expected black code") }
  guard name_from_code(2) == Name::Green else { fail("expected green code") }
  guard name_from_code(4) == Name::Blue else { fail("expected blue code") }
  guard name_from_code(9) == Name::BrightRed else {
    fail("expected bright red code")
  }
  guard name_from_code(12) == Name::BrightBlue else {
    fail("expected bright blue code")
  }
  guard name_from_code(5) == Name::Magenta else {
    fail("expected magenta code")
  }
  guard name_from_code(6) == Name::Cyan else { fail("expected cyan code") }
  guard name_from_code(7) == Name::White else { fail("expected white code") }
  guard name_from_code(10) == Name::BrightGreen else {
    fail("expected bright green code")
  }
  guard name_from_code(13) == Name::BrightMagenta else {
    fail("expected bright magenta code")
  }
  guard name_from_code(14) == Name::BrightCyan else {
    fail("expected bright cyan code")
  }
  guard name_from_code(255) == Name::BrightWhite else {
    fail("expected bright white fallback code")
  }

  let impossible_colorspace : SgrParser = {
    params: [0, 38, 2, 0, 1, 2],
    params_sep: SepList::init_empty(),
    idx: 1,
  }
  impossible_colorspace.params_sep.set(1)
  impossible_colorspace.params_sep.set(2)
  impossible_colorspace.params_sep.set(3)
  impossible_colorspace.params_sep.set(4)
  guard impossible_colorspace.parse_direct_color(1, true) == None else {
    fail("expected short colorspace path to return none")
  }
}

///|
test "sgr/underline forms and styles" {
  expect_attr_eq(
    test_parse([4]),
    Attribute::Underline(Underline::Single),
    "expected single underline",
  )
  expect_attr_eq(
    test_parse([24]),
    Attribute::Underline(Underline::None),
    "expected underline none",
  )
  expect_attr_eq(
    test_parse([21]),
    Attribute::Underline(Underline::Double),
    "expected double underline",
  )

  expect_next_eq(
    parser_with_colons([4, 0], [0]),
    Attribute::Underline(Underline::None),
    "expected underline style none",
  )
  expect_next_eq(
    parser_with_colons([4, 1], [0]),
    Attribute::Underline(Underline::Single),
    "expected underline style single",
  )
  expect_next_eq(
    parser_with_colons([4, 2], [0]),
    Attribute::Underline(Underline::Double),
    "expected underline style double",
  )
  expect_next_eq(
    parser_with_colons([4, 3], [0]),
    Attribute::Underline(Underline::Curly),
    "expected underline style curly",
  )
  expect_next_eq(
    parser_with_colons([4, 4], [0]),
    Attribute::Underline(Underline::Dotted),
    "expected underline style dotted",
  )
  expect_next_eq(
    parser_with_colons([4, 5], [0]),
    Attribute::Underline(Underline::Dashed),
    "expected underline style dashed",
  )
}

///|
test "sgr/underline colon regressions preserve continuation" {
  let extra = parser_with_colons([4, 2, 1], [0])
  expect_next_eq(
    extra,
    Attribute::Underline(Underline::Double),
    "expected double underline",
  )
  expect_next_eq(extra, Bold, "expected bold after underline style")
  expect_none(extra, "expected underline-style parser to finish")

  let too_many = parser_with_colons([4, 2, 3, 1], [0, 1])
  guard too_many.next() is Some(Unknown(_)) else {
    fail("expected underline with too many colons to be unknown")
  }
  expect_next_eq(too_many, Bold, "expected bold after too-many-colons unknown")
  expect_none(too_many, "expected too-many-colons parser to finish")
}

///|
test "sgr/named colors and bright colors" {
  let parser : SgrParser = {
    params: [31, 43, 90, 103],
    params_sep: SepList::init_empty(),
    idx: 0,
  }
  expect_next_eq(parser, Color8Fg(Name::Red), "expected red fg")
  expect_next_eq(parser, Color8Bg(Name::Yellow), "expected yellow bg")
  expect_next_eq(
    parser,
    BrightColor8Fg(Name::BrightBlack),
    "expected bright black fg",
  )
  expect_next_eq(
    parser,
    BrightColor8Bg(Name::BrightYellow),
    "expected bright yellow bg",
  )
  expect_none(parser, "expected named-color parser to finish")
}

///|
test "sgr/256-color selectors" {
  let parser : SgrParser = {
    params: [38, 5, 161, 48, 5, 236],
    params_sep: SepList::init_empty(),
    idx: 0,
  }
  expect_next_eq(parser, Color256Fg(161), "expected 256 fg")
  expect_next_eq(parser, Color256Bg(236), "expected 256 bg")
  expect_none(parser, "expected 256-color parser to finish")

  let underline : SgrParser = {
    params: [58, 5, 9],
    params_sep: SepList::init_empty(),
    idx: 0,
  }
  expect_next_eq(
    underline,
    Color256Underline(9),
    "expected underline 256 color",
  )
  expect_none(underline, "expected underline 256 parser to finish")
}

///|
test "sgr/direct and underline colors in colon forms" {
  guard parser_with_colons([48, 2, 1, 2, 3], [0, 1, 2, 3]).next()
    is Some(DirectColorBg(rgb0)) &&
    rgb0 == { r: 1, g: 2, b: 3 } else {
    fail("expected colon direct bg")
  }

  guard parser_with_colons([58, 2, 1, 2, 3], [0, 1, 2, 3]).next()
    is Some(UnderlineColor(rgb1)) &&
    rgb1 == { r: 1, g: 2, b: 3 } else {
    fail("expected colon underline color")
  }

  guard parser_with_colons([58, 2, 0, 1, 2, 3], [0, 1, 2, 3, 4]).next()
    is Some(UnderlineColor(rgb2)) &&
    rgb2 == { r: 1, g: 2, b: 3 } else {
    fail("expected colon underline color with colorspace")
  }

  expect_attr_eq(
    test_parse([59]),
    ResetUnderlineColor,
    "expected reset underline color",
  )
}

///|
test "sgr/underline fg and bg mixed sequence" {
  let parser : SgrParser = {
    params: [4, 38, 2, 255, 247, 219, 48, 2, 242, 93, 147, 4],
    params_sep: SepList::init_empty(),
    idx: 0,
  }
  expect_next_eq(
    parser,
    Attribute::Underline(Underline::Single),
    "expected first underline",
  )
  guard parser.next() is Some(DirectColorFg(fg)) &&
    fg == { r: 255, g: 247, b: 219 } else {
    fail("expected direct fg")
  }
  guard parser.next() is Some(DirectColorBg(bg)) &&
    bg == { r: 242, g: 93, b: 147 } else {
    fail("expected direct bg")
  }
  expect_next_eq(
    parser,
    Attribute::Underline(Underline::Single),
    "expected final underline",
  )
  expect_none(parser, "expected mixed underline fg bg parser to finish")
}

///|
test "sgr/missing selector payloads degrade to unknown instead of crashing" {
  guard test_parse([38, 5]) is Unknown(_) else {
    fail("expected fg short 256 selector to be unknown")
  }
  guard test_parse([48, 5]) is Unknown(_) else {
    fail("expected bg short 256 selector to be unknown")
  }
  guard test_parse([38, 2, 44, 52]) is Unknown(_) else {
    fail("expected short direct fg selector to be unknown")
  }
  guard test_parse([48, 2, 44, 52]) is Unknown(_) else {
    fail("expected short direct bg selector to be unknown")
  }
}

///|
test "sgr/direct color colorspace handling matches upstream" {
  guard parser_with_colons([38, 2, 0, 1, 2, 3], [0, 1, 2, 3, 4]).next()
    is Some(DirectColorFg(rgb0)) &&
    rgb0 == { r: 1, g: 2, b: 3 } else {
    fail("expected colon direct fg with colorspace")
  }
  guard parser_with_colons([48, 2, 0, 1, 2, 3], [0, 1, 2, 3, 4]).next()
    is Some(DirectColorBg(rgb1)) &&
    rgb1 == { r: 1, g: 2, b: 3 } else {
    fail("expected colon direct bg with colorspace")
  }
  guard parser_with_colons([58, 2, 0, 1, 2, 3], [0, 1, 2, 3, 4]).next()
    is Some(UnderlineColor(rgb2)) &&
    rgb2 == { r: 1, g: 2, b: 3 } else {
    fail("expected colon underline with colorspace")
  }

  guard test_parse([38, 2, 0, 1, 2, 3]) is DirectColorFg(rgb3) &&
    rgb3 == { r: 0, g: 1, b: 2 } else {
    fail("expected semicolon direct fg to treat colorspace slot as red")
  }
  guard test_parse([48, 2, 0, 1, 2, 3]) is DirectColorBg(rgb4) &&
    rgb4 == { r: 0, g: 1, b: 2 } else {
    fail("expected semicolon direct bg to treat colorspace slot as red")
  }
  guard test_parse([58, 2, 0, 1, 2, 3]) is UnderlineColor(rgb5) &&
    rgb5 == { r: 0, g: 1, b: 2 } else {
    fail("expected semicolon underline to treat colorspace slot as red")
  }
}

///|
test "sgr/direct-color colon continuation and malformed runs" {
  let extra_colorspace = parser_with_colons([38, 2, 0, 1, 2, 3, 1], [
    0, 1, 2, 3, 4,
  ])
  guard extra_colorspace.next() is Some(DirectColorFg(rgb0)) &&
    rgb0 == { r: 1, g: 2, b: 3 } else {
    fail("expected direct fg with colorspace and extra param")
  }
  expect_next_eq(
    extra_colorspace,
    Bold,
    "expected bold after colorspace direct fg",
  )
  expect_none(
    extra_colorspace, "expected colorspace direct fg parser to finish",
  )

  let extra_plain = parser_with_colons([38, 2, 1, 2, 3, 1], [0, 1, 2, 3])
  guard extra_plain.next() is Some(DirectColorFg(rgb1)) &&
    rgb1 == { r: 1, g: 2, b: 3 } else {
    fail("expected direct fg without colorspace and extra param")
  }
  expect_next_eq(extra_plain, Bold, "expected bold after plain direct fg")
  expect_none(extra_plain, "expected plain direct fg parser to finish")

  let malformed = parser_with_colons([38, 2, 0, 1, 2, 3, 4, 1], [
    0, 1, 2, 3, 4, 5,
  ])
  guard malformed.next() is Some(Unknown(_)) else {
    fail("expected malformed direct fg colon run to be unknown")
  }
  expect_next_eq(malformed, Bold, "expected bold after malformed direct fg")
  expect_none(malformed, "expected malformed direct fg parser to finish")
}

///|
test "sgr/kakoune and trailing-colon regressions stay non-panicking" {
  let kakoune = parser_with_colons(
    [0, 4, 3, 38, 2, 175, 175, 215, 58, 2, 0, 190, 80, 70],
    [1, 8, 9, 10, 11, 12],
  )
  expect_next_eq(kakoune, Unset, "expected kakoune unset")
  expect_next_eq(
    kakoune,
    Attribute::Underline(Underline::Curly),
    "expected kakoune underline",
  )
  guard kakoune.next() is Some(DirectColorFg(fg)) &&
    fg == { r: 175, g: 175, b: 215 } else {
    fail("expected kakoune direct fg")
  }
  guard kakoune.next() is Some(UnderlineColor(ul)) &&
    ul == { r: 190, g: 80, b: 70 } else {
    fail("expected kakoune underline color")
  }

  let kakoune2 = parser_with_colons(
    [4, 3, 38, 2, 51, 51, 51, 48, 2, 170, 170, 170, 58, 2, 255, 97, 136],
    [0],
  )
  expect_next_eq(
    kakoune2,
    Attribute::Underline(Underline::Curly),
    "expected second kakoune underline",
  )
  guard kakoune2.next() is Some(DirectColorFg(fg2)) &&
    fg2 == { r: 51, g: 51, b: 51 } else {
    fail("expected second kakoune direct fg")
  }
  guard kakoune2.next() is Some(DirectColorBg(bg2)) &&
    bg2 == { r: 170, g: 170, b: 170 } else {
    fail("expected second kakoune direct bg")
  }
  guard kakoune2.next() is Some(UnderlineColor(ul2)) &&
    ul2 == { r: 255, g: 97, b: 136 } else {
    fail("expected second kakoune underline color")
  }
  expect_none(kakoune2, "expected second kakoune parser to finish")

  let trailing = parser_with_colons([58, 4], [0, 1])
  guard trailing.next() is Some(Unknown(_)) else {
    fail("expected malformed underline color to be unknown")
  }
  guard trailing.next() is Some(Unknown(_)) else {
    fail("expected trailing-colon underline to remain unknown")
  }
  expect_none(trailing, "expected trailing-colon parser to finish")
}
