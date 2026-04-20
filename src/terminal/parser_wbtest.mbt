///|
fn expect_no_actions(actions : ActionList) -> Unit raise {
  guard actions[0] == None && actions[1] == None && actions[2] == None else {
    fail("expected no parser actions")
  }
}

///|
test "parser/ground print and execute smoke" {
  let parser = Parser::new()

  let print_actions = parser.next(b'a')
  guard print_actions[0] == None else { fail("unexpected print exit action") }
  guard print_actions[1] is Some(Print(value)) && value == b'a'.to_uint() else {
    fail("expected print action")
  }
  guard print_actions[2] == None else { fail("unexpected print entry action") }
  guard parser.state == Ground else {
    fail("expected ground state after print")
  }

  let execute_actions = parser.next(0x19)
  guard execute_actions[0] == None else {
    fail("unexpected execute exit action")
  }
  guard execute_actions[1] is Some(Execute(value)) && value == 0x19 else {
    fail("expected execute action")
  }
  guard execute_actions[2] == None else {
    fail("unexpected execute entry action")
  }
}

///|
test "parser/deinit delegates to embedded osc parser" {
  let parser = Parser::new()
  for byte in b"\x1b]0;abc" {
    ignore(parser.next(byte))
  }
  parser.deinit()

  let actions = parser.next(0x07)
  guard actions[0] == None else {
    fail("expected parser deinit to reset embedded osc parser")
  }
}

///|
test "parser/esc dispatch with intermediate" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  expect_no_actions(parser.next(b'('))

  let actions = parser.next(b'B')
  guard actions[0] == None else { fail("unexpected ESC exit action") }
  guard actions[1] is Some(EscDispatch(dispatch)) else {
    fail("expected ESC dispatch")
  }
  guard dispatch.final_byte == b'B' && dispatch.intermediates == [b'('] else {
    fail("unexpected ESC dispatch payload")
  }
  guard actions[2] == None else { fail("unexpected ESC entry action") }
  guard parser.state == Ground else { fail("expected ground state") }
}

///|
test "parser/esc intermediate overflow keeps first four bytes" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  for byte in [b'(', b')', b'*', b'+', b'-'] {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(b'B')
  guard actions[1] is Some(EscDispatch(dispatch)) else {
    fail("expected ESC dispatch")
  }
  guard dispatch.intermediates == [b'(', b')', b'*', b'+'] else {
    fail("expected intermediate overflow to drop extra bytes")
  }
}

///|
test "parser/csi dispatch with params" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  expect_no_actions(parser.next(b'['))
  expect_no_actions(parser.next(b'1'))
  expect_no_actions(parser.next(b';'))
  expect_no_actions(parser.next(b'4'))

  let actions = parser.next(b'H')
  guard actions[1] is Some(CsiDispatch(dispatch)) else {
    fail("expected CSI dispatch")
  }
  guard dispatch.final_byte == b'H' else { fail("unexpected CSI final") }
  guard dispatch.params == [1, 4] else { fail("unexpected CSI params") }
}

///|
test "parser/csi colon handling and blank subparams" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  for byte in b"[58:2::240:143:104" {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(b'm')
  guard actions[1] is Some(CsiDispatch(dispatch)) else {
    fail("expected CSI SGR dispatch")
  }
  guard dispatch.final_byte == b'm' else { fail("unexpected SGR final") }
  guard dispatch.params == [58, 2, 0, 240, 143, 104] else {
    fail("unexpected SGR params")
  }
  for index in 0..<5 {
    guard dispatch.params_sep.is_set(index) else {
      fail("expected colon separator bit at \{index}")
    }
  }
  guard !dispatch.params_sep.is_set(5) else {
    fail("unexpected separator after final SGR param")
  }
}

///|
test "parser/csi mixed separators stay valid for sgr" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  for byte in b"[1;58:2:255:128:64" {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(b'm')
  guard actions[1] is Some(CsiDispatch(dispatch)) else {
    fail("expected mixed-separator SGR dispatch")
  }
  guard dispatch.params == [1, 58, 2, 255, 128, 64] else {
    fail("unexpected mixed-separator SGR params")
  }
  guard !dispatch.params_sep.is_set(0) else {
    fail("unexpected separator bit after semicolon boundary")
  }
  for index in 1..<5 {
    guard dispatch.params_sep.is_set(index) else {
      fail("expected colon separator bit at \{index}")
    }
  }
}

///|
test "parser/csi colon for non-m final suppresses dispatch" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  for byte in b"[38:2" {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(b'h')
  guard actions[0] == None && actions[1] == None && actions[2] == None else {
    fail("expected colon-separated non-SGR CSI to be dropped")
  }
  guard parser.state == Ground else { fail("expected ground state") }
}

///|
test "parser/csi dispatch with intermediates" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  for byte in b"[?2026$" {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(b'p')
  guard actions[1] is Some(CsiDispatch(dispatch)) else {
    fail("expected CSI dispatch with intermediates")
  }
  guard dispatch.final_byte == b'p' else { fail("unexpected final") }
  guard dispatch.intermediates == [b'?', b'$'] else {
    fail("unexpected intermediates")
  }
  guard dispatch.params == [2026] else { fail("unexpected params") }
}

///|
test "parser/osc dispatch on bel and st ordering" {
  let bel_parser = Parser::new()
  for byte in b"\x1b]0;abc" {
    expect_no_actions(bel_parser.next(byte))
  }
  let bel_actions = bel_parser.next(0x07)
  guard bel_actions[0] is Some(OscDispatch(ChangeWindowTitle(title))) &&
    title == "abc" else {
    fail("expected OSC BEL dispatch in exit slot")
  }
  guard bel_actions[1] == None && bel_actions[2] == None else {
    fail("unexpected BEL OSC trailing actions")
  }

  let st_parser = Parser::new()
  for byte in b"\x1b]0;xyz" {
    expect_no_actions(st_parser.next(byte))
  }
  let esc_actions = st_parser.next(0x1B)
  guard esc_actions[0] is Some(OscDispatch(ChangeWindowTitle(title))) &&
    title == "xyz" else {
    fail("expected OSC ST dispatch on ESC exit")
  }
  guard esc_actions[1] == None && esc_actions[2] == None else {
    fail("unexpected OSC ST ESC-slot actions")
  }
  let slash_actions = st_parser.next(b'\\')
  guard slash_actions[1] is Some(EscDispatch(dispatch)) &&
    dispatch.final_byte == b'\\' else {
    fail("expected trailing ESC dispatch for ST terminator")
  }
}

///|
test "parser/osc embedded minimal color operation" {
  let parser = Parser::new()
  for byte in b"\x1b]112" {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(0x07)
  guard actions[0] is Some(OscDispatch(ColorOperation(command))) else {
    fail("expected OSC color dispatch")
  }
  guard command.op() == Osc112 else { fail("unexpected OSC color operation") }
  guard command.requests() == [Reset(Dynamic(Cursor))] else {
    fail("unexpected OSC color requests")
  }
}

///|
test "parser/osc clipboard dispatch" {
  let parser = Parser::new()
  for byte in b"\x1b]52;;?" {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(0x07)
  guard actions[0] is Some(OscDispatch(ClipboardContents(contents))) else {
    fail("expected OSC clipboard dispatch in exit slot")
  }
  guard contents.kind() == b'c' && contents.data() == "?" else {
    fail("expected clipboard payload")
  }
  guard actions[1] == None && actions[2] == None else {
    fail("unexpected OSC clipboard trailing actions")
  }
}

///|
test "parser/osc kitty color dispatch" {
  let parser = Parser::new()
  for byte in b"\x1b]21;foreground=?;255=#010203" {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(0x07)
  guard actions[0] is Some(OscDispatch(KittyColorProtocol(command))) else {
    fail("expected OSC kitty color dispatch in exit slot")
  }
  guard command.requests() ==
    [
      KittyQuery(KittySpecial(KittyForeground)),
      KittySet(KittyColorSet::new(KittyPalette(255), RGB::new(1, 2, 3))),
    ] else {
    fail("expected kitty color payload")
  }
  guard command.terminator() == Bel else {
    fail("expected kitty color BEL terminator")
  }
  guard actions[1] == None && actions[2] == None else {
    fail("unexpected OSC kitty color trailing actions")
  }
}

///|
test "parser/osc hyperlink dispatch" {
  let start_parser = Parser::new()
  for byte in b"\x1b]8;id=foo;http://example.com" {
    expect_no_actions(start_parser.next(byte))
  }
  let start_actions = start_parser.next(0x07)
  guard start_actions[0] is Some(OscDispatch(HyperlinkStart(link))) &&
    link.id() == Some("foo") &&
    link.uri() == "http://example.com" else {
    fail("expected OSC hyperlink start dispatch in exit slot")
  }
  guard start_actions[1] == None && start_actions[2] == None else {
    fail("unexpected hyperlink start trailing actions")
  }

  let end_parser = Parser::new()
  for byte in b"\x1b]8;;" {
    expect_no_actions(end_parser.next(byte))
  }
  let end_actions = end_parser.next(0x07)
  guard end_actions[0] == Some(OscDispatch(HyperlinkEnd)) else {
    fail("expected OSC hyperlink end dispatch in exit slot")
  }
  guard end_actions[1] == None && end_actions[2] == None else {
    fail("unexpected hyperlink end trailing actions")
  }
}

///|
test "parser/osc semantic prompt dispatch" {
  let parser = Parser::new()
  for byte in b"\x1b]133;A;aid=foo;cl=m;redraw=1" {
    expect_no_actions(parser.next(byte))
  }

  let actions = parser.next(0x07)
  guard actions[0] is Some(OscDispatch(SemanticPrompt(prompt))) else {
    fail("expected OSC semantic prompt dispatch in exit slot")
  }
  guard prompt.action() == FreshLineNewPrompt else {
    fail("expected semantic prompt action")
  }
  guard prompt.aid() == Some("foo") else {
    fail("expected semantic prompt aid")
  }
  guard prompt.cl() == Some(Multiple) else {
    fail("expected semantic prompt cl option")
  }
  guard prompt.redraw() == Some(Enabled) else {
    fail("expected semantic prompt redraw option")
  }
  guard actions[1] == None && actions[2] == None else {
    fail("unexpected semantic prompt trailing actions")
  }
}

///|
test "parser/csi too many params drops dispatch" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  expect_no_actions(parser.next(b'['))
  for _ in 0..<100 {
    expect_no_actions(parser.next(b'1'))
    expect_no_actions(parser.next(b';'))
  }
  expect_no_actions(parser.next(b'1'))

  let actions = parser.next(b'C')
  expect_no_actions(actions)
  guard parser.state == Ground else { fail("expected ground after overflow") }
}

///|
test "parser/csi param digits saturate and stop counting" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  expect_no_actions(parser.next(b'['))
  for _ in 0..<(MaxParamDigits + 1) {
    expect_no_actions(parser.next(b'9'))
  }

  let actions = parser.next(b'm')
  guard actions[1] is Some(CsiDispatch(dispatch)) else {
    fail("expected CSI dispatch after long numeric run")
  }
  guard dispatch.params == [MaxParamValue] else {
    fail("expected saturated CSI param value")
  }
}

///|
test "parser/dcs hook put unhook and params" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  expect_no_actions(parser.next(b'P'))
  expect_no_actions(parser.next(b'+'))

  let hook_actions = parser.next(b'q')
  guard hook_actions[2] is Some(DcsHook(hook)) else {
    fail("expected DCS hook on entry")
  }
  guard hook.final_byte == b'q' &&
    hook.intermediates == [b'+'] &&
    hook.params == [] else {
    fail("unexpected DCS hook payload")
  }
  guard parser.state == DcsPassthrough else {
    fail("expected DCS passthrough state")
  }

  let put_actions = parser.next(b'a')
  guard put_actions[1] is Some(DcsPut(value)) && value == b'a' else {
    fail("expected DCS put action")
  }

  let unhook_actions = parser.next(0x1B)
  guard unhook_actions[0] == Some(DcsUnhook) else {
    fail("expected DCS unhook on exit")
  }
}

///|
test "parser/dcs params and overflow regression" {
  let param_parser = Parser::new()
  expect_no_actions(param_parser.next(0x1B))
  for byte in b"P1000" {
    expect_no_actions(param_parser.next(byte))
  }
  let hook_actions = param_parser.next(b'p')
  guard hook_actions[2] is Some(DcsHook(hook)) && hook.params == [1000] else {
    fail("expected DCS params to finalize on hook")
  }

  let overflow_parser = Parser::new()
  expect_no_actions(overflow_parser.next(0x1B))
  expect_no_actions(overflow_parser.next(b'P'))
  expect_no_actions(overflow_parser.next(b'6'))
  for _ in 0..<MaxParams {
    expect_no_actions(overflow_parser.next(b';'))
  }
  expect_no_actions(overflow_parser.next(b'7'))
  expect_no_actions(overflow_parser.next(b'p'))
}

///|
test "parser/apc start put and end ordering" {
  let parser = Parser::new()
  let start_actions = parser.next(0x9F)
  guard start_actions[2] == Some(ApcStart) else {
    fail("expected APC start on entry")
  }
  guard parser.state == SosPmApcString else {
    fail("expected APC string state")
  }

  let put_actions = parser.next(b'a')
  guard put_actions[1] is Some(ApcPut(value)) && value == b'a' else {
    fail("expected APC put action")
  }

  let end_actions = parser.next(0x9C)
  guard end_actions[0] == Some(ApcEnd) else { fail("expected APC end on exit") }
  guard parser.state == Ground else { fail("expected ground after APC end") }
}
