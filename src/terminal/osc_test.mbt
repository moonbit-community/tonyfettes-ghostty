///|
fn feed_osc_bytes(parser : OscParser, bytes : Bytes) -> Unit {
  for byte in bytes {
    parser.next(byte)
  }
}

///|
test "osc parser/parses title payload and resets after end" {
  let parser = OscParser::new()
  feed_osc_bytes(parser, b"0;hello")

  guard parser.end(Some(0x07)) == Some(ChangeWindowTitle("hello")) else {
    fail("expected title command from public osc parser")
  }
  guard parser.end(Some(0x07)) == None else {
    fail("expected osc parser end to reset internal state")
  }
}

///|
test "osc parser/reset clears partially collected data" {
  let parser = OscParser::new()
  feed_osc_bytes(parser, b"0;partial")
  parser.reset()
  feed_osc_bytes(parser, b"8;;https://ghostty.org")

  guard parser.end(Some(0x1B)) is Some(HyperlinkStart(link)) &&
    link.uri() == "https://ghostty.org" &&
    link.id() == None else {
    fail("expected reset osc parser to discard previous command state")
  }
}

///|
test "osc parser/exposes color operation payload through command enum" {
  let parser = OscParser::new()
  feed_osc_bytes(parser, b"4;1;rgb:0102/0304/0506")

  guard parser.end(Some(0x07)) is Some(ColorOperation(command)) else {
    fail("expected osc color operation command")
  }
  guard command.op() == Osc4 else { fail("expected osc4 color op") }
  guard command.requests() ==
    [Set(ColoredTarget::new(Palette(1), RGB::new(1, 3, 5)))] else {
    fail("expected color request payload from public command enum")
  }
  guard command.terminator() == Bel else {
    fail("expected bel terminator to be preserved")
  }
}
