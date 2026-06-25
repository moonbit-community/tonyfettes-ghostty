// Black-box pipeline test: drives raw bytes through the parser and asserts on
// the decoded OSC semantic payload. It lives outside parser_wbtest because it
// needs the osc and color packages (via test-only imports) rather than parser
// internals.

///|
fn expect_no_actions(actions : ActionList) -> Unit raise {
  guard actions.exit() is None &&
    actions.transition() is None &&
    actions.entry() is None else {
    fail("expected no parser actions")
  }
}

///|
test "parser/osc kitty color dispatch" {
  let parser = Parser::new()
  for byte in b"\x1b]21;foreground=?;255=#010203" {
    expect_no_actions(parser.next(byte))
  }
  let actions = parser.next(0x07)
  guard actions.exit() is Some(OscDispatch(KittyColorProtocol(command))) else {
    fail("expected OSC kitty color dispatch in exit slot")
  }
  guard command.requests() ==
    [
      KittyQuery(KittySpecial(KittyForeground)),
      KittySet(
        @osc.KittyColorSet::new(KittyPalette(255), @color.RGB::new(1, 2, 3)),
      ),
    ] else {
    fail("expected kitty color payload")
  }
  guard command.terminator() == Bel else {
    fail("expected kitty color BEL terminator")
  }
  guard actions.transition() is None && actions.entry() is None else {
    fail("unexpected OSC kitty color trailing actions")
  }
}
