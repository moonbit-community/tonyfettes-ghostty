///|
fn feed_osc_bytes(parser : @osc.OscParser, bytes : Bytes) -> Unit {
  for byte in bytes {
    parser.next(byte)
  }
}

///|
test "osc parser/parses title payload and resets after end" {
  let parser = @osc.OscParser::new()
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
  let parser = @osc.OscParser::new()
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
  let parser = @osc.OscParser::new()
  feed_osc_bytes(parser, b"4;1;rgb:0102/0304/0506")

  guard parser.end(Some(0x07)) is Some(ColorOperation(command)) else {
    fail("expected osc color operation command")
  }
  guard command.op() == Osc4 else { fail("expected osc4 color op") }
  guard command.requests() ==
    [Set(@osc.ColoredTarget::new(Palette(1), @color.RGB::new(1, 3, 5)))] else {
    fail("expected color request payload from public command enum")
  }
  guard command.terminator() == Bel else {
    fail("expected bel terminator to be preserved")
  }
}

///|
test "osc parser/retained color command survives parser reuse" {
  let parser = @osc.OscParser::new()
  feed_osc_bytes(parser, b"4;1;red;2;?;3;blue")
  let retained = parser.end(Some(0x07))
  guard retained is Some(ColorOperation(command)) else {
    fail("expected retained OSC color command")
  }
  let requests = command.requests()

  feed_osc_bytes(parser, b"10;?")
  @debug.assert_eq(
    parser.end(Some(0x1B)),
    Some(
      ColorOperation(
        @osc.ColorCommand::new(Osc10, [Query(Dynamic(Foreground))], St),
      ),
    ),
  )
  feed_osc_bytes(parser, b"4;9;green")
  parser.reset()
  parser.deinit()

  let expected : Array[@osc.ColorRequest] = [
    Set(@osc.ColoredTarget::new(Palette(1), @color.RGB::new(255, 0, 0))),
    Query(Palette(2)),
    Set(@osc.ColoredTarget::new(Palette(3), @color.RGB::new(0, 0, 255))),
  ]
  @debug.assert_eq(requests, expected)
  @debug.assert_eq(
    retained,
    Some(ColorOperation(@osc.ColorCommand::new(Osc4, expected, Bel))),
  )
}

///|
test "osc color command preserves shared request array ownership" {
  let requests : Array[@osc.ColorRequest] = [Query(Palette(1))]
  let command = @osc.ColorCommand::new(Osc4, requests, Bel)
  let wrapped : @osc.Command = ColorOperation(command)
  requests.push(Reset(Palette(2)))
  command.requests().push(ResetPalette)
  @debug.assert_eq(requests, [
    Query(Palette(1)),
    Reset(Palette(2)),
    ResetPalette,
  ])
  @debug.assert_eq(
    wrapped,
    ColorOperation(@osc.ColorCommand::new(Osc4, requests, Bel)),
  )
}
