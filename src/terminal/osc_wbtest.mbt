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
  guard command.op() == op else { fail("unexpected OSC color operation") }
  guard command.requests() == requests else {
    fail("unexpected OSC color requests")
  }
  guard command.terminator() == expected_terminator else {
    fail("unexpected OSC terminator")
  }
}

///|
fn expect_semantic_prompt(
  bytes : Bytes,
  terminator : Byte?,
) -> SemanticPrompt raise {
  let parser = OscParser::new()
  feed_bytes(parser, bytes)
  guard parser.end(terminator) is Some(SemanticPrompt(prompt)) else {
    fail("expected OSC semantic prompt command")
  }
  prompt
}

///|
fn expect_clipboard_contents(
  bytes : Bytes,
  terminator : Byte?,
) -> ClipboardContents raise {
  let parser = OscParser::new()
  feed_bytes(parser, bytes)
  guard parser.end(terminator) is Some(ClipboardContents(contents)) else {
    fail("expected OSC clipboard command")
  }
  contents
}

///|
fn expect_kitty_color_protocol(
  bytes : Bytes,
  terminator : Byte?,
) -> KittyColorOsc raise {
  let parser = OscParser::new()
  feed_bytes(parser, bytes)
  guard parser.end(terminator) is Some(KittyColorProtocol(command)) else {
    fail("expected OSC kitty color command")
  }
  command
}

///|
test "osc/color payload constructors and accessors" {
  let target = ColoredTarget::new(Palette(3), RGB::new(1, 2, 3))
  guard target.target() == Palette(3) else {
    fail("expected colored target palette")
  }
  guard target.color() == RGB::new(1, 2, 3) else {
    fail("expected colored target rgb")
  }

  let command = ColorCommand::new(Osc4, [Set(target)], Bel)
  guard command.op() == Osc4 else { fail("expected color command op") }
  guard command.requests() == [Set(target)] else {
    fail("expected color command requests")
  }
  guard command.terminator() == Bel else {
    fail("expected color command terminator")
  }
}

///|
test "osc/kitty color constructors and accessors" {
  let set = KittyColorSet::new(KittySpecial(KittyForeground), RGB::new(1, 2, 3))
  guard set.key() == KittySpecial(KittyForeground) else {
    fail("expected kitty color key")
  }
  guard set.color() == RGB::new(1, 2, 3) else {
    fail("expected kitty color value")
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
  for bytes in [b"0", b"1", b"2", b"7", b"8", b"21", b"22", b"6"] {
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
test "osc/invalid states stay invalid and reject bad numeric branches" {
  let invalid = OscParser::new()
  invalid.next(b'6')
  invalid.next(b'0')
  match invalid.end(Some(0x07)) {
    None => ()
    _ => fail("expected invalid parser to remain rejected after extra input")
  }

  let prefix1 = OscParser::new()
  prefix1.next(b'1')
  prefix1.next(b'x')
  match prefix1.end(Some(0x07)) {
    None => ()
    _ => fail("expected invalid OSC 1x prefix to be rejected")
  }

  let prefix11 = OscParser::new()
  prefix11.next(b'1')
  prefix11.next(b'1')
  prefix11.next(b'x')
  match prefix11.end(Some(0x07)) {
    None => ()
    _ => fail("expected invalid OSC 11x prefix to be rejected")
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
test "osc/hyperlink basics and id handling" {
  let basic = OscParser::new()
  feed_bytes(basic, b"8;;http://example.com")
  guard basic.end(Some(0x1B)) is Some(HyperlinkStart(link)) else {
    fail("expected OSC 8 hyperlink start command")
  }
  guard link.uri() == "http://example.com" else {
    fail("expected OSC 8 hyperlink uri")
  }
  guard link.id() == None else {
    fail("expected OSC 8 hyperlink id to be absent")
  }

  let with_id = OscParser::new()
  feed_bytes(with_id, b"8;id=foo;http://example.com")
  guard with_id.end(Some(0x1B)) is Some(HyperlinkStart(link)) else {
    fail("expected OSC 8 hyperlink with id")
  }
  guard link.uri() == "http://example.com" else {
    fail("expected hyperlink uri with id")
  }
  guard link.id() == Some("foo") else { fail("expected hyperlink id") }

  let empty_id = OscParser::new()
  feed_bytes(empty_id, b"8;id=;http://example.com")
  guard empty_id.end(Some(0x1B)) is Some(HyperlinkStart(link)) else {
    fail("expected OSC 8 hyperlink with empty id to parse")
  }
  guard link.id() == None else {
    fail("expected empty hyperlink id to be ignored")
  }
}

///|
test "osc/hyperlink malformed options and end handling" {
  let incomplete_key = OscParser::new()
  feed_bytes(incomplete_key, b"8;id;http://example.com")
  guard incomplete_key.end(Some(0x1B)) is Some(HyperlinkStart(link)) &&
    link.id() == None &&
    link.uri() == "http://example.com" else {
    fail("expected incomplete hyperlink key to be ignored")
  }

  let empty_key = OscParser::new()
  feed_bytes(empty_key, b"8;=value:id=foo;http://example.com")
  guard empty_key.end(Some(0x1B)) is Some(HyperlinkStart(link)) &&
    link.id() == Some("foo") &&
    link.uri() == "http://example.com" else {
    fail("expected empty hyperlink key to be ignored")
  }

  let end_link = OscParser::new()
  feed_bytes(end_link, b"8;;")
  guard end_link.end(Some(0x1B)) == Some(HyperlinkEnd) else {
    fail("expected OSC 8 hyperlink end command")
  }

  let invalid = OscParser::new()
  feed_bytes(invalid, b"8;id=foo;")
  guard invalid.end(Some(0x1B)) == None else {
    fail("expected empty hyperlink uri with id to be rejected")
  }

  let no_separator = OscParser::new()
  feed_bytes(no_separator, b"8;id=foo")
  guard no_separator.end(Some(0x1B)) == None else {
    fail("expected hyperlink payload without second semicolon to be rejected")
  }
}

///|
test "osc/clipboard contents basics" {
  let set_contents = expect_clipboard_contents(b"52;s;?", Some(0x07))
  guard set_contents.kind() == b's' else { fail("expected clipboard kind") }
  guard set_contents.data() == "?" else { fail("expected clipboard data") }

  let default_kind = expect_clipboard_contents(b"52;;?", Some(0x07))
  guard default_kind.kind() == b'c' else {
    fail("expected default clipboard kind")
  }
  guard default_kind.data() == "?" else {
    fail("expected default-kind clipboard data")
  }

  let clear_contents = expect_clipboard_contents(b"52;;", Some(0x07))
  guard clear_contents.kind() == b'c' else {
    fail("expected clear clipboard kind")
  }
  guard clear_contents.data() == "" else {
    fail("expected clear clipboard payload")
  }

  let primary = expect_clipboard_contents(b"52;p;abc", Some(0x1B))
  guard primary.kind() == b'p' && primary.data() == "abc" else {
    fail("expected clipboard payload with ST terminator")
  }
}

///|
test "osc/clipboard invalid forms are rejected" {
  let invalid : Array[Bytes] = [
    b"52", b"52;", b"52;s", b"52sa", b"52;ab", b"52x;?",
  ]
  for bytes in invalid {
    let parser = OscParser::new()
    feed_bytes(parser, bytes)
    guard parser.end(Some(0x07)) == None else {
      fail("expected invalid OSC 52 form to be rejected")
    }
  }
}

///|
test "osc/kitty color protocol parses query set reset and trim rules" {
  let command = expect_kitty_color_protocol(
    b"21;foreground=?;background=rgb:f0/f8/ff;cursor=aliceblue;cursor_text;visual_bell=;selection_foreground=#xxxyyzz;selection_background=?;selection_background=#aabbcc;2=?;3=rgbi:1.0/1.0/1.0",
    Some(0x1B),
  )
  guard command.requests() ==
    [
      KittyQuery(KittySpecial(KittyForeground)),
      KittySet(
        KittyColorSet::new(
          KittySpecial(KittyBackground),
          RGB::new(0xF0, 0xF8, 0xFF),
        ),
      ),
      KittySet(
        KittyColorSet::new(
          KittySpecial(KittyCursor),
          RGB::new(0xF0, 0xF8, 0xFF),
        ),
      ),
      KittyReset(KittySpecial(KittyCursorText)),
      KittyReset(KittySpecial(KittyVisualBell)),
      KittyQuery(KittySpecial(KittySelectionBackground)),
      KittySet(
        KittyColorSet::new(
          KittySpecial(KittySelectionBackground),
          RGB::new(0xAA, 0xBB, 0xCC),
        ),
      ),
      KittyQuery(KittyPalette(2)),
      KittySet(KittyColorSet::new(KittyPalette(3), RGB::new(0xFF, 0xFF, 0xFF))),
    ] else {
    fail("unexpected kitty color requests")
  }
  guard command.terminator() == St else {
    fail("expected kitty color terminator")
  }
}

///|
test "osc/kitty color protocol accepts empty body and spaced values" {
  let empty = expect_kitty_color_protocol(b"21;", Some(0x07))
  guard empty.requests() == [] else {
    fail("expected empty kitty color request list")
  }
  guard empty.terminator() == Bel else { fail("expected BEL terminator") }

  let spaced = expect_kitty_color_protocol(
    b"21;second_transparent_background= ? ;255= #010203 ;badkey=?;999=?",
    Some(0x07),
  )
  guard spaced.requests() ==
    [
      KittyQuery(KittySpecial(KittySecondTransparentBackground)),
      KittySet(KittyColorSet::new(KittyPalette(255), RGB::new(1, 2, 3))),
    ] else {
    fail("expected trimmed kitty color requests")
  }
}

///|
test "osc/kitty color protocol rejects malformed prefixes" {
  let missing_separator = OscParser::new()
  for byte in b"21" {
    missing_separator.next(byte)
  }
  guard missing_separator.end(Some(0x07)) == None else {
    fail("expected incomplete OSC 21 prefix to be rejected")
  }

  let invalid_prefix = OscParser::new()
  for byte in b"21x;foreground=?" {
    invalid_prefix.next(byte)
  }
  guard invalid_prefix.end(Some(0x07)) == None else {
    fail("expected invalid OSC 21 prefix to be rejected")
  }
}

///|
test "osc/kitty color protocol request limit is enforced" {
  let buffer : Array[Byte] = []
  for _ in 0..<KittyColorRequestLimit {
    buffer.push(b'0')
    buffer.push(b'=')
    buffer.push(b'?')
    buffer.push(b';')
  }
  guard parse_kitty_color_command(buffer, Some(0x07)) == None else {
    fail("expected oversized OSC 21 request list to be rejected")
  }
}

///|
test "osc/semantic prompt actions and option accessors" {
  let fresh_line = expect_semantic_prompt(b"133;L", Some(0x07))
  guard fresh_line.action() == FreshLine else {
    fail("expected fresh-line action")
  }

  let end_input = expect_semantic_prompt(b"133;C", Some(0x07))
  guard end_input.action() == EndInputStartOutput else {
    fail("expected end-input-start-output action")
  }
  guard end_input.aid() == None && end_input.cl() == None else {
    fail("expected no end-input options")
  }
  guard end_input.prompt_kind() == None &&
    end_input.redraw() == None &&
    end_input.special_key() == None &&
    end_input.click_events() == None else {
    fail("expected absent semantic prompt options")
  }

  let fresh_prompt = expect_semantic_prompt(
    b"133;A;aid=a=b;cl=m;redraw=1;special_key=0;click_events=1",
    Some(0x07),
  )
  guard fresh_prompt.action() == FreshLineNewPrompt else {
    fail("expected fresh-line-new-prompt action")
  }
  guard fresh_prompt.aid() == Some("a=b") else {
    fail("expected semantic prompt aid")
  }
  guard fresh_prompt.cl() == Some(Multiple) else {
    fail("expected semantic prompt cl option")
  }
  guard fresh_prompt.redraw() == Some(Enabled) else {
    fail("expected semantic prompt redraw option")
  }
  guard fresh_prompt.special_key() == Some(false) else {
    fail("expected semantic prompt special_key option")
  }
  guard fresh_prompt.click_events() == Some(true) else {
    fail("expected semantic prompt click_events option")
  }

  let click_vertical = expect_semantic_prompt(b"133;A;cl=v", Some(0x07))
  guard click_vertical.cl() == Some(ConservativeVertical) else {
    fail("expected conservative-vertical cl option")
  }

  let click_smart = expect_semantic_prompt(b"133;A;cl=w", Some(0x07))
  guard click_smart.cl() == Some(SmartVertical) else {
    fail("expected smart-vertical cl option")
  }

  let click_invalid_single = expect_semantic_prompt(b"133;A;cl=x", Some(0x07))
  guard click_invalid_single.cl() == None else {
    fail("expected invalid single-char cl option to be ignored")
  }

  let prompt_start = expect_semantic_prompt(b"133;P;k=s", Some(0x07))
  guard prompt_start.action() == PromptStart else {
    fail("expected prompt-start action")
  }
  guard prompt_start.prompt_kind() == Some(Secondary) else {
    fail("expected prompt kind option")
  }

  let prompt_initial = expect_semantic_prompt(b"133;P;k=i", Some(0x07))
  guard prompt_initial.prompt_kind() == Some(Initial) else {
    fail("expected initial prompt kind option")
  }

  let prompt_right = expect_semantic_prompt(b"133;P;k=r", Some(0x07))
  guard prompt_right.prompt_kind() == Some(Right) else {
    fail("expected right prompt kind option")
  }

  let prompt_continuation = expect_semantic_prompt(b"133;P;k=c", Some(0x07))
  guard prompt_continuation.prompt_kind() == Some(Continuation) else {
    fail("expected continuation prompt kind option")
  }

  let prompt_invalid = expect_semantic_prompt(b"133;P;k=x", Some(0x07))
  guard prompt_invalid.prompt_kind() == None else {
    fail("expected invalid prompt kind to be ignored")
  }

  let prompt_long = expect_semantic_prompt(b"133;P;k=ii", Some(0x07))
  guard prompt_long.prompt_kind() == None else {
    fail("expected multi-char prompt kind to be ignored")
  }

  let new_command = expect_semantic_prompt(b"133;N;aid=foo;cl=line", Some(0x07))
  guard new_command.action() == NewCommand else {
    fail("expected new-command action")
  }
  guard new_command.aid() == Some("foo") && new_command.cl() == Some(Line) else {
    fail("expected new-command options")
  }

  let end_prompt = expect_semantic_prompt(b"133;B;aid=bar", Some(0x07))
  guard end_prompt.action() == EndPromptStartInput &&
    end_prompt.aid() == Some("bar") else {
    fail("expected end-prompt options")
  }

  let terminate_eol = expect_semantic_prompt(b"133;I;aid=baz", Some(0x07))
  guard terminate_eol.action() == EndPromptStartInputTerminateEol &&
    terminate_eol.aid() == Some("baz") else {
    fail("expected terminate-eol options")
  }

  let end_command = expect_semantic_prompt(
    b"133;D;12;aid=foo;err=oops",
    Some(0x07),
  )
  guard end_command.action() == EndCommand else {
    fail("expected end-command action")
  }
  guard end_command.exit_code() == Some(12) else {
    fail("expected semantic prompt exit code")
  }
  guard end_command.aid() == Some("foo") && end_command.err() == Some("oops") else {
    fail("expected end-command options")
  }

  let end_command_none = expect_semantic_prompt(b"133;D", Some(0x07))
  guard end_command_none.exit_code() == None else {
    fail("expected absent exit code")
  }

  let end_command_plain = expect_semantic_prompt(b"133;D;42", Some(0x07))
  guard end_command_plain.exit_code() == Some(42) else {
    fail("expected plain exit code")
  }
}

///|
test "osc/semantic prompt decoding and malformed options" {
  let printf_q = expect_semantic_prompt(
    b"133;C;cmdline=echo\\ bobr\\nkurwa",
    Some(0x07),
  )
  guard printf_q.cmdline() == Some("echo\\ bobr\\nkurwa") else {
    fail("expected raw cmdline option")
  }
  let printf_q_result : Result[String?, SemanticPromptDecodeError] = try? printf_q.decoded_command_line()
  guard printf_q_result is Ok(Some(decoded)) && decoded == "echo bobr\nkurwa" else {
    fail("expected decoded printf-q command line")
  }

  let quoted = expect_semantic_prompt(
    b"133;C;cmdline=$'echo bobr kurwa'",
    Some(0x07),
  )
  let quoted_result : Result[String?, SemanticPromptDecodeError] = try? quoted.decoded_command_line()
  guard quoted_result is Ok(Some(decoded)) && decoded == "echo bobr kurwa" else {
    fail("expected decoded quoted command line")
  }

  let single_quoted = expect_semantic_prompt(
    b"133;C;cmdline='echo bobr kurwa'",
    Some(0x07),
  )
  let single_quoted_result : Result[String?, SemanticPromptDecodeError] = try? single_quoted.decoded_command_line()
  guard single_quoted_result is Ok(Some(decoded)) &&
    decoded == "echo bobr kurwa" else {
    fail("expected decoded single-quoted command line")
  }

  let escape_variants = expect_semantic_prompt(
    b"133;C;cmdline=one\\etwo\\rthree\\tfour\\vfive",
    Some(0x07),
  )
  let escape_variants_result : Result[String?, SemanticPromptDecodeError] = try? escape_variants.decoded_command_line()
  let expected_escape_variants = @utf8.decode_lossy(
    b"one\x1Btwo\rthree\tfour\x0Bfive",
  )
  guard escape_variants_result is Ok(Some(decoded)) &&
    decoded == expected_escape_variants else {
    fail("expected decoded escape variants")
  }

  let url = expect_semantic_prompt(
    b"133;C;cmdline_url=echo%20bobr%3Bkurwa",
    Some(0x07),
  )
  guard url.cmdline_url() == Some("echo%20bobr%3Bkurwa") else {
    fail("expected raw cmdline_url option")
  }
  let url_result : Result[String?, SemanticPromptDecodeError] = try? url.decoded_command_line()
  guard url_result is Ok(Some(decoded)) && decoded == "echo bobr;kurwa" else {
    fail("expected decoded url command line")
  }

  let lowercase_hex = expect_semantic_prompt(
    b"133;C;cmdline_url=echo%3bkurwa",
    Some(0x07),
  )
  let lowercase_hex_result : Result[String?, SemanticPromptDecodeError] = try? lowercase_hex.decoded_command_line()
  guard lowercase_hex_result is Ok(Some(decoded)) && decoded == "echo;kurwa" else {
    fail("expected decoded lowercase-hex command line")
  }

  let redraw_last = expect_semantic_prompt(b"133;A;redraw=last", Some(0x07))
  guard redraw_last.redraw() == Some(Last) else {
    fail("expected redraw=last option")
  }

  let redraw_disabled = expect_semantic_prompt(b"133;A;redraw=0", Some(0x07))
  guard redraw_disabled.redraw() == Some(Disabled) else {
    fail("expected redraw=0 option")
  }

  let redraw_invalid_long = expect_semantic_prompt(
    b"133;A;redraw=lasts",
    Some(0x07),
  )
  guard redraw_invalid_long.redraw() == None else {
    fail("expected invalid redraw option to be ignored")
  }

  let special_key_invalid = expect_semantic_prompt(
    b"133;A;special_key=x",
    Some(0x07),
  )
  guard special_key_invalid.special_key() == None else {
    fail("expected invalid special_key option to be ignored")
  }

  let invalid_printf_q = expect_semantic_prompt(
    b"133;C;cmdline='echo bobr kurwa",
    Some(0x07),
  )
  let invalid_printf_q_result : Result[String?, SemanticPromptDecodeError] = try? invalid_printf_q.decoded_command_line()
  guard invalid_printf_q_result is Err(DecodeError) else {
    fail("expected malformed printf-q command line to fail")
  }

  let invalid_printf_q_escape = expect_semantic_prompt(
    b"133;C;cmdline=echo\\",
    Some(0x07),
  )
  let invalid_printf_q_escape_result : Result[
    String?,
    SemanticPromptDecodeError,
  ] = try? invalid_printf_q_escape.decoded_command_line()
  guard invalid_printf_q_escape_result is Err(DecodeError) else {
    fail("expected trailing backslash decode failure")
  }

  let invalid_printf_q_escape_kind = expect_semantic_prompt(
    b"133;C;cmdline=echo\\d",
    Some(0x07),
  )
  let invalid_printf_q_escape_kind_result : Result[
    String?,
    SemanticPromptDecodeError,
  ] = try? invalid_printf_q_escape_kind.decoded_command_line()
  guard invalid_printf_q_escape_kind_result is Err(DecodeError) else {
    fail("expected unsupported printf-q escape decode failure")
  }

  let invalid_printf_q_dollar = expect_semantic_prompt(
    b"133;C;cmdline=$'echo bobr kurwa",
    Some(0x07),
  )
  let invalid_printf_q_dollar_result : Result[
    String?,
    SemanticPromptDecodeError,
  ] = try? invalid_printf_q_dollar.decoded_command_line()
  guard invalid_printf_q_dollar_result is Err(DecodeError) else {
    fail("expected malformed dollar-quoted decode failure")
  }

  let invalid_url = expect_semantic_prompt(
    b"133;C;cmdline_url=echo%2",
    Some(0x07),
  )
  let invalid_url_result : Result[String?, SemanticPromptDecodeError] = try? invalid_url.decoded_command_line()
  guard invalid_url_result is Err(DecodeError) else {
    fail("expected malformed url command line to fail")
  }

  let invalid_url_hex = expect_semantic_prompt(
    b"133;C;cmdline_url=echo%G0",
    Some(0x07),
  )
  let invalid_url_hex_result : Result[String?, SemanticPromptDecodeError] = try? invalid_url_hex.decoded_command_line()
  guard invalid_url_hex_result is Err(DecodeError) else {
    fail("expected invalid hex url command line to fail")
  }

  let invalid_url_low_hex = expect_semantic_prompt(
    b"133;C;cmdline_url=echo%2G",
    Some(0x07),
  )
  let invalid_url_low_hex_result : Result[String?, SemanticPromptDecodeError] = try? invalid_url_low_hex.decoded_command_line()
  guard invalid_url_low_hex_result is Err(DecodeError) else {
    fail("expected invalid low-nibble hex url command line to fail")
  }

  let invalid_options = expect_semantic_prompt(
    b"133;A;cl=invalid;redraw=x;click_events=yes;barekey;aid=",
    Some(0x07),
  )
  guard invalid_options.cl() == None else {
    fail("expected invalid cl option to be ignored")
  }
  guard invalid_options.redraw() == None else {
    fail("expected invalid redraw option to be ignored")
  }
  guard invalid_options.click_events() == None else {
    fail("expected invalid click_events option to be ignored")
  }
  guard invalid_options.aid() == Some("") else {
    fail("expected empty aid to be preserved")
  }
}

///|
test "osc/semantic prompt invalid forms are rejected" {
  let invalid : Array[Bytes] = [
    b"133", b"133;", b"133x", b"133;Lx", b"133;L;aid=foo", b"133;Aextra", b"133;Bextra",
    b"133;Cextra", b"133;Dextra", b"133;Iextra", b"133;Nextra", b"133;Pextra", b"133;Z",
  ]
  for bytes in invalid {
    let parser = OscParser::new()
    feed_bytes(parser, bytes)
    guard parser.end(Some(0x07)) == None else {
      fail("expected invalid OSC 133 form to be rejected")
    }
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
  guard color_command.op() == Osc112 else { fail("expected OSC 112 operation") }
  guard color_command.terminator() == Bel else {
    fail("expected BEL terminator")
  }
  guard color_command.requests() == [Reset(Dynamic(Cursor))] else {
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
  guard color_command.requests() == [Reset(Dynamic(Cursor))] else {
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
  guard color_command.op() == Osc104 else { fail("expected OSC 104 operation") }
  guard color_command.requests() == [ResetPalette] else {
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
  guard color_command.op() == Osc4 else { fail("expected OSC 4 operation") }
  guard color_command.terminator() == St else { fail("expected ST terminator") }
  guard color_command.requests() ==
    [Set(ColoredTarget::new(Palette(1), RGB::new(255, 0, 0)))] else {
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
      b"8x;ignored", b"10x;ignored", b"12x;ignored", b"13x;ignored", b"14x;ignored",
      b"15x;ignored", b"16x;ignored", b"17x;ignored", b"18x;ignored", b"19x;ignored",
      b"22x;ignored", b"104x;ignored", b"110x;ignored", b"111x;ignored", b"112x;ignored",
      b"113x;ignored", b"114x;ignored", b"115x;ignored", b"116x;ignored", b"117x;ignored",
      b"118x;ignored", b"119x;ignored",
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
test "osc/private color helpers cover unsupported prefixes and edge targets" {
  guard parse_color_command(Prefix0, [], Some(0x07)) == Invalid else {
    fail("expected non-color parse helper to yield invalid command")
  }
  guard color_operation_from_state(Prefix0) == None else {
    fail("expected non-color prefix to map to no operation")
  }
  guard ansi_target_from_index(Osc4, -1) == None else {
    fail("expected negative palette index to be rejected")
  }
  guard special_from_int(0) == Some(Bold) else {
    fail("expected special index 0 to map to bold")
  }
  guard special_from_int(2) == Some(Blink) else {
    fail("expected special index 2 to map to blink")
  }
  guard special_from_int(3) == Some(Reverse) else {
    fail("expected special index 3 to map to reverse")
  }
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
