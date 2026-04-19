///|
fn feed_bytes(parser : OscParser, bytes : Bytes) -> Unit {
  for byte in bytes {
    parser.next(byte)
  }
}

///|
fn expect_color_command(
  bytes : Bytes,
  terminator : Byte?,
  op : ColorOperation,
  requests : Array[ColorRequest],
  expected_terminator : Terminator,
) -> Unit raise {
  let parser = OscParser::new()
  feed_bytes(parser, bytes)
  guard parser.end(terminator) is Some(ColorOperation(command)) else {
    fail("expected OSC color command")
  }
  guard command.op == op else { fail("unexpected OSC color operation") }
  guard command.requests == requests else {
    fail("unexpected OSC color requests")
  }
  guard command.terminator == expected_terminator else {
    fail("unexpected OSC terminator")
  }
}

///|
test "osc/title with bel terminator" {
  let parser = OscParser::new()
  parser.next(b'0')
  parser.next(b';')
  parser.next(b'a')
  parser.next(b'b')
  parser.next(b'c')

  let command = parser.end(Some(0x07))
  guard command is Some(ChangeWindowTitle(title)) && title == "abc" else {
    fail("expected OSC 0 title command")
  }
}

///|
test "osc/title may be empty" {
  let parser = OscParser::new()
  parser.next(b'0')
  parser.next(b';')

  let command = parser.end(Some(0x07))
  guard command is Some(ChangeWindowTitle(title)) && title == "" else {
    fail("expected empty OSC 0 title command")
  }
}

///|
test "osc/title with utf8 payload" {
  let parser = OscParser::new()
  parser.next(b'2')
  parser.next(b';')
  parser.next(0xE2)
  parser.next(0x80)
  parser.next(0x94)
  parser.next(b' ')
  parser.next(0xE2)
  parser.next(0x80)
  parser.next(0x90)

  let command = parser.end(Some(0x07))
  guard command is Some(ChangeWindowTitle(title)) && title == "— ‐" else {
    fail("expected OSC 2 utf8 title command")
  }
}

///|
test "osc/title with st terminator" {
  let parser = OscParser::new()
  parser.next(b'0')
  parser.next(b';')
  parser.next(b'a')
  parser.next(b'b')

  let command = parser.end(Some(0x1B))
  guard command is Some(ChangeWindowTitle(title)) && title == "ab" else {
    fail("expected OSC ST title command")
  }
}

///|
test "osc/title fixed buffer overflow invalidates parser" {
  let parser = OscParser::new()
  parser.next(b'0')
  parser.next(b';')
  for _ in 0..<OscMaxBuf {
    parser.next(b'a')
  }
  match parser.end(Some(0x07)) {
    None => ()
    _ => fail("expected oversized OSC title to be rejected")
  }
}

///|
test "osc/title exact fixed-buffer limit succeeds" {
  let parser = OscParser::new()
  parser.next(b'0')
  parser.next(b';')
  for _ in 0..<(OscMaxBuf - 1) {
    parser.next(b'a')
  }
  guard parser.end(Some(0x07)) is Some(ChangeWindowTitle(title)) else {
    fail("expected max-size OSC title to succeed")
  }
  guard title.length() == OscMaxBuf - 1 else {
    fail("expected title at exact fixed-buffer limit")
  }
}

///|
test "osc/incomplete and invalid prefixes are rejected" {
  for bytes in [b"0", b"1", b"2", b"7", b"22", b"6"] {
    let parser = OscParser::new()
    for byte in bytes {
      parser.next(byte)
    }
    match parser.end(Some(0x07)) {
      None => ()
      _ => fail("expected incomplete or invalid OSC prefix to be rejected")
    }
  }
}

///|
test "osc/icon report-pwd and mouse-shape basics" {
  let icon = OscParser::new()
  icon.next(b'1')
  icon.next(b';')
  icon.next(b'i')
  icon.next(b'c')
  guard icon.end(Some(0x07)) is Some(ChangeWindowIcon(value)) && value == "ic" else {
    fail("expected OSC 1 icon command")
  }

  let pwd = OscParser::new()
  for byte in b"7;file:///tmp/example" {
    pwd.next(byte)
  }
  guard pwd.end(Some(0x07)) is Some(ReportPwd(value)) &&
    value == "file:///tmp/example" else {
    fail("expected OSC 7 report pwd command")
  }

  let mouse = OscParser::new()
  for byte in b"22;pointer" {
    mouse.next(byte)
  }
  guard mouse.end(Some(0x07)) is Some(MouseShape(value)) && value == "pointer" else {
    fail("expected OSC 22 mouse shape command")
  }
}

///|
test "osc/color reset cursor with incomplete sequence" {
  let parser = OscParser::new()
  parser.next(b'1')
  parser.next(b'1')
  parser.next(b'2')

  let command = parser.end(Some(0x07))
  guard command is Some(ColorOperation(color_command)) else {
    fail("expected OSC 112 color command")
  }
  guard color_command.op == Osc112 else { fail("expected OSC 112 operation") }
  guard color_command.terminator == Bel else { fail("expected BEL terminator") }
  guard color_command.requests == [Reset(Dynamic(Cursor))] else {
    fail("expected cursor reset request")
  }
}

///|
test "osc/color reset cursor accepts trailing semicolon" {
  let parser = OscParser::new()
  for byte in b"112;" {
    parser.next(byte)
  }

  let command = parser.end(Some(0x07))
  guard command is Some(ColorOperation(color_command)) else {
    fail("expected OSC 112 color command")
  }
  guard color_command.requests == [Reset(Dynamic(Cursor))] else {
    fail("expected cursor reset request with trailing semicolon")
  }
}

///|
test "osc/color reset palette with empty body" {
  let parser = OscParser::new()
  parser.next(b'1')
  parser.next(b'0')
  parser.next(b'4')

  let command = parser.end(Some(0x07))
  guard command is Some(ColorOperation(color_command)) else {
    fail("expected OSC 104 color command")
  }
  guard color_command.op == Osc104 else { fail("expected OSC 104 operation") }
  guard color_command.requests == [ResetPalette] else {
    fail("expected reset-palette request")
  }
}

///|
test "osc/color palette set parses rgb payload" {
  let parser = OscParser::new()
  for byte in b"4;1;red" {
    parser.next(byte)
  }

  let command = parser.end(Some(0x1B))
  guard command is Some(ColorOperation(color_command)) else {
    fail("expected OSC 4 color command")
  }
  guard color_command.op == Osc4 else { fail("expected OSC 4 operation") }
  guard color_command.terminator == St else { fail("expected ST terminator") }
  guard color_command.requests ==
    [Set({ target: Palette(1), color: { r: 255, g: 0, b: 0 } })] else {
    fail("expected palette set request")
  }
}

///|
test "osc/parser deinit resets state and start has no command" {
  let parser = OscParser::new()
  guard parser.end(Some(0x07)) == None else {
    fail("expected empty parser to produce no command")
  }

  feed_bytes(parser, b"0;stale")
  parser.deinit()
  guard parser.end(Some(0x07)) == None else {
    fail("expected deinit to restore start state")
  }

  feed_bytes(parser, b"2;fresh")
  guard parser.end(Some(0x07)) is Some(ChangeWindowTitle(title)) &&
    title == "fresh" else {
    fail("expected parser to be reusable after deinit")
  }
}

///|
test "osc/invalid prefix transitions short circuit parser state" {
  for
    bytes in [
      b"0x;ignored", b"2x;ignored", b"4x;ignored", b"5x;ignored", b"7x;ignored",
      b"10x;ignored", b"12x;ignored", b"13x;ignored", b"14x;ignored", b"15x;ignored",
      b"16x;ignored", b"17x;ignored", b"18x;ignored", b"19x;ignored", b"22x;ignored",
      b"104x;ignored", b"110x;ignored", b"111x;ignored", b"112x;ignored", b"113x;ignored",
      b"114x;ignored", b"115x;ignored", b"116x;ignored", b"117x;ignored", b"118x;ignored",
      b"119x;ignored",
    ] {
    let parser = OscParser::new()
    feed_bytes(parser, bytes)
    guard parser.end(Some(0x07)) == None else {
      fail("expected invalid prefix transition to abort OSC parsing")
    }
  }
}

///|
test "osc/color ansi operations handle special targets queries and invalid bodies" {
  expect_color_command(
    b"5;4;red;1;?",
    Some(0x07),
    Osc5,
    [
      Set({ target: Special(Italic), color: { r: 255, g: 0, b: 0 } }),
      Query(Special(Underline)),
    ],
    Bel,
  )

  expect_color_command(
    b"4;260;?",
    Some(0x1B),
    Osc4,
    [Query(Special(Italic))],
    St,
  )

  expect_color_command(
    b"4;1;red;bogus;blue",
    Some(0x07),
    Osc4,
    [Set({ target: Palette(1), color: { r: 255, g: 0, b: 0 } })],
    Bel,
  )

  expect_color_command(b"4;;red", Some(0x07), Osc4, [], Bel)
  expect_color_command(b"5;9;red", Some(0x07), Osc5, [], Bel)
  expect_color_command(b"5;1;not-a-color", Some(0x07), Osc5, [], Bel)
}

///|
test "osc/color reset ansi accepts palette and special targets and skips invalid entries" {
  expect_color_command(
    b"104;1;;260;bogus;999",
    Some(0x07),
    Osc104,
    [Reset(Palette(1)), Reset(Special(Italic))],
    Bel,
  )
}

///|
test "osc/dynamic color get set query and truncation behave per prefix" {
  expect_color_command(
    b"10;?",
    Some(0x07),
    Osc10,
    [Query(Dynamic(Foreground))],
    Bel,
  )
  expect_color_command(
    b"11;red",
    Some(0x07),
    Osc11,
    [Set({ target: Dynamic(Background), color: { r: 255, g: 0, b: 0 } })],
    Bel,
  )
  expect_color_command(
    b"12;?",
    Some(0x07),
    Osc12,
    [Query(Dynamic(Cursor))],
    Bel,
  )
  expect_color_command(
    b"13;red",
    Some(0x07),
    Osc13,
    [Set({ target: Dynamic(PointerForeground), color: { r: 255, g: 0, b: 0 } })],
    Bel,
  )
  expect_color_command(
    b"14;?",
    Some(0x07),
    Osc14,
    [Query(Dynamic(PointerBackground))],
    Bel,
  )
  expect_color_command(
    b"15;red",
    Some(0x07),
    Osc15,
    [
      Set({
        target: Dynamic(TektronixForeground),
        color: { r: 255, g: 0, b: 0 },
      }),
    ],
    Bel,
  )
  expect_color_command(
    b"16;?",
    Some(0x07),
    Osc16,
    [Query(Dynamic(TektronixBackground))],
    Bel,
  )
  expect_color_command(
    b"17;red",
    Some(0x07),
    Osc17,
    [
      Set({
        target: Dynamic(HighlightBackground),
        color: { r: 255, g: 0, b: 0 },
      }),
    ],
    Bel,
  )
  expect_color_command(
    b"18;?",
    Some(0x07),
    Osc18,
    [Query(Dynamic(TektronixCursor))],
    Bel,
  )
  expect_color_command(
    b"19;red;blue",
    Some(0x07),
    Osc19,
    [
      Set({
        target: Dynamic(HighlightForeground),
        color: { r: 255, g: 0, b: 0 },
      }),
    ],
    Bel,
  )
}

///|
test "osc/dynamic color rejects empty and invalid specs" {
  expect_color_command(b"10;", Some(0x07), Osc10, [], Bel)
  expect_color_command(b"11;not-a-color", Some(0x07), Osc11, [], Bel)
}

///|
test "osc/dynamic reset variants accept empty bodies and reject non-empty bodies" {
  expect_color_command(
    b"110;",
    Some(0x07),
    Osc110,
    [Reset(Dynamic(Foreground))],
    Bel,
  )
  expect_color_command(
    b"111;",
    Some(0x07),
    Osc111,
    [Reset(Dynamic(Background))],
    Bel,
  )
  expect_color_command(
    b"112;",
    Some(0x07),
    Osc112,
    [Reset(Dynamic(Cursor))],
    Bel,
  )
  expect_color_command(b"113;ignored", Some(0x07), Osc113, [], Bel)
  expect_color_command(
    b"114;",
    Some(0x07),
    Osc114,
    [Reset(Dynamic(PointerBackground))],
    Bel,
  )
  expect_color_command(
    b"115;",
    Some(0x07),
    Osc115,
    [Reset(Dynamic(TektronixForeground))],
    Bel,
  )
  expect_color_command(
    b"116;",
    Some(0x07),
    Osc116,
    [Reset(Dynamic(TektronixBackground))],
    Bel,
  )
  expect_color_command(
    b"117;",
    Some(0x07),
    Osc117,
    [Reset(Dynamic(HighlightBackground))],
    Bel,
  )
  expect_color_command(
    b"118;",
    Some(0x07),
    Osc118,
    [Reset(Dynamic(TektronixCursor))],
    Bel,
  )
  expect_color_command(
    b"119;",
    Some(0x07),
    Osc119,
    [Reset(Dynamic(HighlightForeground))],
    Bel,
  )
}
