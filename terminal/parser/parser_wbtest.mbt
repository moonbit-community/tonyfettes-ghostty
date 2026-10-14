///|
fn expect_no_actions(actions : ActionList) -> Unit raise {
  guard actions.exit() is None &&
    actions.transition() is None &&
    actions.entry() is None else {
    fail("expected no parser actions")
  }
}

///|
fn expect_action_none(action : Action?, message : String) -> Unit raise {
  guard action is None else { fail(message) }
}

///|
test "parser/ground print and execute smoke" {
  let parser = Parser::new()

  let print_actions = parser.next(b'a')
  expect_action_none(print_actions.exit(), "unexpected print exit action")
  guard print_actions.transition() is Some(Print(value)) &&
    value == b'a'.to_uint() else {
    fail("expected print action")
  }
  expect_action_none(print_actions.entry(), "unexpected print entry action")
  guard parser.state == Ground else {
    fail("expected ground state after print")
  }

  let execute_actions = parser.next(0x19)
  expect_action_none(execute_actions.exit(), "unexpected execute exit action")
  guard execute_actions.transition() is Some(Execute(value)) && value == 0x19 else {
    fail("expected execute action")
  }
  expect_action_none(execute_actions.entry(), "unexpected execute entry action")
}

///|
test "parser/deinit delegates to embedded osc parser" {
  let parser = Parser::new()
  for byte in b"\x1b]0;abc" {
    ignore(parser.next(byte))
  }
  parser.deinit()

  let actions = parser.next(0x07)
  expect_action_none(
    actions.exit(),
    "expected parser deinit to reset embedded osc parser",
  )
}

///|
test "parser/esc dispatch with intermediate" {
  let parser = Parser::new()
  expect_no_actions(parser.next(0x1B))
  expect_no_actions(parser.next(b'('))

  let actions = parser.next(b'B')
  expect_action_none(actions.exit(), "unexpected ESC exit action")
  guard actions.transition() is Some(EscDispatch(dispatch)) else {
    fail("expected ESC dispatch")
  }
  guard dispatch.final_byte == b'B' && dispatch.intermediates == [b'('] else {
    fail("unexpected ESC dispatch payload")
  }
  expect_action_none(actions.entry(), "unexpected ESC entry action")
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
  guard actions.transition() is Some(EscDispatch(dispatch)) else {
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
  guard actions.transition() is Some(CsiDispatch(dispatch)) else {
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
  guard actions.transition() is Some(CsiDispatch(dispatch)) else {
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
  guard actions.transition() is Some(CsiDispatch(dispatch)) else {
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
  guard actions.exit() is None &&
    actions.transition() is None &&
    actions.entry() is None else {
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
  guard actions.transition() is Some(CsiDispatch(dispatch)) else {
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
  guard bel_actions.exit() is Some(OscDispatch(ChangeWindowTitle(title))) &&
    title == "abc" else {
    fail("expected OSC BEL dispatch in exit slot")
  }
  guard bel_actions.transition() is None && bel_actions.entry() is None else {
    fail("unexpected BEL OSC trailing actions")
  }

  let st_parser = Parser::new()
  for byte in b"\x1b]0;xyz" {
    expect_no_actions(st_parser.next(byte))
  }
  let esc_actions = st_parser.next(0x1B)
  guard esc_actions.exit() is Some(OscDispatch(ChangeWindowTitle(title))) &&
    title == "xyz" else {
    fail("expected OSC ST dispatch on ESC exit")
  }
  guard esc_actions.transition() is None && esc_actions.entry() is None else {
    fail("unexpected OSC ST ESC-slot actions")
  }
  let slash_actions = st_parser.next(b'\\')
  guard slash_actions.transition() is Some(EscDispatch(dispatch)) &&
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
  guard actions.exit() is Some(OscDispatch(ColorOperation(command))) else {
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
  guard actions.exit() is Some(OscDispatch(ClipboardContents(contents))) else {
    fail("expected OSC clipboard dispatch in exit slot")
  }
  guard contents.kind() == b'c' && contents.data() == "?" else {
    fail("expected clipboard payload")
  }
  guard actions.transition() is None && actions.entry() is None else {
    fail("unexpected OSC clipboard trailing actions")
  }
}

///|

///|
test "parser/osc9 desktop notification report-pwd and semantic prompt dispatch" {
  let notification_parser = Parser::new()
  for byte in b"\x1b]9;hello world" {
    expect_no_actions(notification_parser.next(byte))
  }
  let notification_actions = notification_parser.next(0x07)
  guard notification_actions.exit()
    is Some(OscDispatch(ShowDesktopNotification(notification))) &&
    notification.title() == "" &&
    notification.body() == "hello world" else {
    fail("expected OSC 9 desktop notification dispatch in exit slot")
  }
  guard notification_actions.transition() is None &&
    notification_actions.entry() is None else {
    fail("unexpected OSC 9 desktop notification trailing actions")
  }

  let pwd_parser = Parser::new()
  for byte in b"\x1b]9;9;file:///tmp" {
    expect_no_actions(pwd_parser.next(byte))
  }
  let pwd_actions = pwd_parser.next(0x07)
  guard pwd_actions.exit() is Some(OscDispatch(ReportPwd(value))) &&
    value == "file:///tmp" else {
    fail("expected OSC 9 cwd compatibility report-pwd dispatch")
  }

  let prompt_parser = Parser::new()
  for byte in b"\x1b]9;12;abc" {
    expect_no_actions(prompt_parser.next(byte))
  }
  let prompt_actions = prompt_parser.next(0x07)
  guard prompt_actions.exit() is Some(OscDispatch(SemanticPrompt(prompt))) &&
    prompt.action() == FreshLineNewPrompt else {
    fail("expected OSC 9 semantic prompt compatibility dispatch")
  }
}

///|
test "parser/osc777 and osc1337 dispatch" {
  let rxvt_parser = Parser::new()
  for byte in b"\x1b]777;notify;Title;Body" {
    expect_no_actions(rxvt_parser.next(byte))
  }
  let rxvt_actions = rxvt_parser.next(0x07)
  guard rxvt_actions.exit()
    is Some(OscDispatch(ShowDesktopNotification(notification))) &&
    notification.title() == "Title" &&
    notification.body() == "Body" else {
    fail("expected OSC 777 desktop notification dispatch")
  }

  let copy_parser = Parser::new()
  for byte in b"\x1b]1337;Copy=:YWJjMTIz" {
    expect_no_actions(copy_parser.next(byte))
  }
  let copy_actions = copy_parser.next(0x07)
  guard copy_actions.exit() is Some(OscDispatch(ClipboardContents(contents))) &&
    contents.kind() == b'c' &&
    contents.data() == "YWJjMTIz" else {
    fail("expected OSC 1337 clipboard bridge dispatch")
  }

  let current_dir_parser = Parser::new()
  for byte in b"\x1b]1337;CurrentDir=file:///tmp" {
    expect_no_actions(current_dir_parser.next(byte))
  }
  let current_dir_actions = current_dir_parser.next(0x07)
  guard current_dir_actions.exit() is Some(OscDispatch(ReportPwd(value))) &&
    value == "file:///tmp" else {
    fail("expected OSC 1337 current-dir dispatch")
  }
}

///|
test "parser/osc5522 kitty clipboard dispatch" {
  let parser = Parser::new()
  for byte in b"\x1b]5522;type=read:status=OK;Qk9CUg==" {
    expect_no_actions(parser.next(byte))
  }
  let actions = parser.next(0x07)
  guard actions.exit() is Some(OscDispatch(KittyClipboardProtocol(command))) else {
    fail("expected OSC 5522 dispatch in exit slot")
  }
  guard command.metadata() == "type=read:status=OK" else {
    fail("expected OSC 5522 metadata")
  }
  guard command.payload() == Some("Qk9CUg==") else {
    fail("expected OSC 5522 payload")
  }
  guard command.status() == Some(KittyClipboardOk) &&
    command.operation() == Some(KittyClipboardRead) else {
    fail("expected OSC 5522 typed options")
  }
  guard actions.transition() is None && actions.entry() is None else {
    fail("unexpected OSC 5522 trailing actions")
  }
}

///|
test "parser/osc3008 and osc66 dispatch" {
  let context_parser = Parser::new()
  for byte in b"\x1b]3008;start=myctx;type=shell;user=root" {
    expect_no_actions(context_parser.next(byte))
  }
  let context_actions = context_parser.next(0x07)
  guard context_actions.exit() is Some(OscDispatch(ContextSignal(command))) &&
    command.action() == ContextSignalStart &&
    command.id() == "myctx" &&
    command.context_type() == Some(ContextSignalShell) &&
    command.user() == Some("root") else {
    fail("expected OSC 3008 dispatch in exit slot")
  }
  guard context_actions.transition() is None && context_actions.entry() is None else {
    fail("unexpected OSC 3008 trailing actions")
  }

  let text_parser = Parser::new()
  for byte in b"\x1b]66;s=2:w=7:n=13:d=15:v=1:h=2;long" {
    expect_no_actions(text_parser.next(byte))
  }
  let text_actions = text_parser.next(0x07)
  guard text_actions.exit() is Some(OscDispatch(KittyTextSizing(command))) &&
    command.scale() == 2 &&
    command.width() == 7 &&
    command.numerator() == 13 &&
    command.denominator() == 15 &&
    command.valign() == KittyTextSizingVBottom &&
    command.halign() == KittyTextSizingHCenter &&
    command.text() == "long" else {
    fail("expected OSC 66 dispatch in exit slot")
  }
  guard text_actions.transition() is None && text_actions.entry() is None else {
    fail("unexpected OSC 66 trailing actions")
  }
}

///|
test "parser/osc hyperlink dispatch" {
  let start_parser = Parser::new()
  for byte in b"\x1b]8;id=foo;http://example.com" {
    expect_no_actions(start_parser.next(byte))
  }
  let start_actions = start_parser.next(0x07)
  guard start_actions.exit() is Some(OscDispatch(HyperlinkStart(link))) &&
    link.id() == Some("foo") &&
    link.uri() == "http://example.com" else {
    fail("expected OSC hyperlink start dispatch in exit slot")
  }
  guard start_actions.transition() is None && start_actions.entry() is None else {
    fail("unexpected hyperlink start trailing actions")
  }

  let end_parser = Parser::new()
  for byte in b"\x1b]8;;" {
    expect_no_actions(end_parser.next(byte))
  }
  let end_actions = end_parser.next(0x07)
  guard end_actions.exit() is Some(OscDispatch(HyperlinkEnd)) else {
    fail("expected OSC hyperlink end dispatch in exit slot")
  }
  guard end_actions.transition() is None && end_actions.entry() is None else {
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
  guard actions.exit() is Some(OscDispatch(SemanticPrompt(prompt))) else {
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
  guard actions.transition() is None && actions.entry() is None else {
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
  guard actions.transition() is Some(CsiDispatch(dispatch)) else {
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
  guard hook_actions.entry() is Some(DcsHook(hook)) else {
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
  guard put_actions.transition() is Some(DcsPut(value)) && value == b'a' else {
    fail("expected DCS put action")
  }

  let unhook_actions = parser.next(0x1B)
  guard unhook_actions.exit() is Some(DcsUnhook) else {
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
  guard hook_actions.entry() is Some(DcsHook(hook)) && hook.params == [1000] else {
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
  guard start_actions.entry() is Some(ApcStart) else {
    fail("expected APC start on entry")
  }
  guard parser.state == SosPmApcString else {
    fail("expected APC string state")
  }

  let put_actions = parser.next(b'a')
  guard put_actions.transition() is Some(ApcPut(value)) && value == b'a' else {
    fail("expected APC put action")
  }

  let end_actions = parser.next(0x9C)
  guard end_actions.exit() is Some(ApcEnd) else {
    fail("expected APC end on exit")
  }
  guard parser.state == Ground else { fail("expected ground after APC end") }
}

///|
test "parser/stream adapter matches generic dispatch and recovery" {
  let inputs : Array[Bytes] = [
    b"\x1b[m\x1b[0m", b"\x1b[1;2:3::4;m\x1b[5;6H", b"\x1b[:1m\x1b[1:2H\x1b[3m", b"\x1b[65535;65536;999999999999999999999999m\x1b[0m",
    b"\x1b[?2026$p\x1b[1 2m\x1b[>1m\x1b[0m", b"\x1b[1:2$\x1b\x1b[3m\x1b[0m", b"\x1b]0;title\x07\x1b]2;other\x1b\\\x1b[0m",
    b"\x1bP1;2+qabc\x1b\\\x1b[0m", b"\x1b_apc\x1b\\\x1b[0m", b"\x1b[1:2\x18\x9b3m\x1b[0m",
    b"\x1b[1:2\x1a\x1b[3m\x1b[0m",
  ]
  for count in [23, 24, 25] {
    for trailing in [false, true] {
      let buf = Buffer()
      buf.write_bytes(b"\x1b[")
      for index in 0..<count {
        buf.write_byte(b'1')
        if index + 1 < count || trailing {
          buf.write_byte(b';')
        }
      }
      buf.write_bytes(b"999:;m\x1b[31m")
      inputs.push(buf.contents())
    }
  }
  // Exercise the expanded fallback's empty, nonempty, and overflow DCS
  // hook branches, plus OSC termination without a valid command.
  for count in [0, 23, 24, 25] {
    let buf = Buffer()
    buf.write_bytes(b"\x1bP")
    for index in 0..<count {
      if index > 0 {
        buf.write_byte(b';')
      }
      buf.write_byte(b'1')
    }
    buf.write_bytes(b"qbody\x1b\\\x1b[0m")
    inputs.push(buf.contents())
  }
  inputs.push(b"\x1b]not-a-command\x07\x1b[0m")
  inputs.push(b"\x1b]0;\x1b\\\x1b[0m")
  let long_digits = Buffer()
  long_digits.write_bytes(b"\x1b[")
  for _ in 0..<300 {
    long_digits.write_byte(b'9')
  }
  long_digits.write_bytes(b"m\x1b[0m")
  inputs.push(long_digits.contents())
  // Reach each state by real input so embedded OSC state and CSI/DCS
  // accumulators are valid, then exercise every possible following byte.
  let seeds : Array[(ParserState, Bytes)] = [
    (Ground, b""),
    (Escape, b"\x1b"),
    (EscapeIntermediate, b"\x1b("),
    (CsiEntry, b"\x1b["),
    (CsiIntermediate, b"\x1b[1$"),
    (CsiParam, b"\x1b[1;2"),
    (CsiIgnore, b"\x1b[:"),
    (DcsEntry, b"\x1bP"),
    (DcsParam, b"\x1bP1;2"),
    (DcsIntermediate, b"\x1bP1;2+"),
    (DcsPassthrough, b"\x1bP1;2+qbody"),
    (DcsIgnore, b"\x1bP:"),
    (OscString, b"\x1b]0;active title"),
    (SosPmApcString, b"\x1b_apc body"),
  ]
  for (expected_state, prefix) in seeds {
    let probe = Parser::new()
    for byte in prefix {
      ignore(probe.next(byte))
    }
    assert_eq(probe.state.ordinal(), expected_state.ordinal())
    for value in 0..<256 {
      let buf = Buffer()
      buf.write_bytes(prefix)
      buf.write_byte(value.to_byte())
      buf.write_bytes(b"2m\x1b[0m")
      inputs.push(buf.contents())
    }
  }
  for input in inputs {
    let snapshots : Array[Array[String]] = []
    for fast in [false, true] {
      let parser = Parser::new()
      let events : Array[String] = []
      for byte in input {
        let was_csi_param = parser.state is CsiParam
        let actions = if fast {
          parser.next_stream(byte)
        } else {
          parser.next(byte)
        }
        // Materialize text immediately: never retain borrowed dispatch views
        // across another parser step, even for the comparison oracle.
        for action in [actions.exit(), actions.transition(), actions.entry()] {
          let event = match action {
            None => "none"
            Some(Print(c)) => "print:\{c}"
            Some(Execute(c)) =>
              if was_csi_param && c >= 0x10 && c <= 0x1F {
                "none"
              } else {
                "execute:\{c}"
              }
            Some(CsiDispatch(csi)) =>
              "csi:\{Repr(csi.intermediates.to_owned())}:\{Repr(csi.params.to_owned())}:\{Repr(csi.params_sep)}:\{csi.final_byte}"
            Some(EscDispatch(esc)) =>
              "esc:\{Repr(esc.intermediates.to_owned())}:\{esc.final_byte}"
            Some(OscDispatch(command)) => "osc:\{Repr(command)}"
            Some(DcsHook(dcs)) =>
              "dcs:\{Repr(dcs.intermediates.to_owned())}:\{Repr(dcs.params.to_owned())}:\{dcs.final_byte}"
            Some(DcsPut(c)) => "dcs-put:\{c}"
            Some(DcsUnhook) => "dcs-unhook"
            Some(ApcStart) => "apc-start"
            Some(ApcPut(c)) => "apc-put:\{c}"
            Some(ApcEnd) => "apc-end"
          }
          events.push(event)
        }
        events.push("state:\{parser.state.ordinal()}")
      }
      snapshots.push(events)
    }
    assert_eq(snapshots[0], snapshots[1])
  }
}

///|
test "parser/stream adapter limits controls and escape clearing" {
  for count in [23, 24, 25] {
    let parser = Parser::new()
    for byte in b"\x1b[" {
      expect_no_actions(parser.next_stream(byte))
    }
    for index in 0..<count {
      if index > 0 {
        expect_no_actions(parser.next_stream(b';'))
      }
      expect_no_actions(parser.next_stream(b'1'))
    }
    let actions = parser.next_stream(b'm')
    if count <= MaxParams {
      guard actions.transition() is Some(CsiDispatch(csi)) else {
        fail("expected dispatch at parameter capacity")
      }
      assert_eq(csi.params.length(), count)
    } else {
      expect_no_actions(actions)
    }
  }
  for control in 0..<32 {
    if control == 0x1B {
      continue
    }
    let parser = Parser::new()
    for byte in b"\x1b[1" {
      expect_no_actions(parser.next_stream(byte))
    }
    let actions = parser.next_stream(control.to_byte())
    if control <= 0x0F {
      guard actions.transition() is Some(Execute(c)) else {
        fail("expected executed low C0")
      }
      assert_eq(c.to_int(), control)
    } else {
      expect_no_actions(actions)
    }
    assert_eq(parser.is_ground(), control == 0x18 || control == 0x1A)
  }
  let parser = Parser::new()
  for byte in b"\x1b[?12:34$\x1b" {
    ignore(parser.next_stream(byte))
  }
  expect_no_actions(parser.next_stream(b'['))
  assert_eq(parser.params.length(), 0)
  assert_eq(parser.intermediates.length(), 0)
  assert_eq(parser.params_sep.count(), 0)
  assert_eq(parser.param_acc, 0)
  assert_eq(parser.param_acc_idx, 0)
  for byte in b"65536" {
    expect_no_actions(parser.next_stream(byte))
  }
  let result = parser.next_stream(b'm')
  guard result.transition() is Some(CsiDispatch(csi)) else {
    fail("expected saturated CSI")
  }
  assert_eq(csi.params.to_owned(), [65535])
}
