///|
fn bytes_contains(haystack : Bytes, needle : Bytes) -> Bool {
  if needle.length() == 0 {
    return true
  }
  if needle.length() > haystack.length() {
    return false
  }

  let mut start = 0
  let last = haystack.length() - needle.length()
  while start <= last {
    let mut matched = true
    let mut idx = 0
    while idx < needle.length() {
      if haystack[start + idx] != needle[idx] {
        matched = false
        break
      }
      idx += 1
    }
    if matched {
      return true
    }
    start += 1
  }

  false
}

///|
fn plain_formatter(terminal : StreamTerminal) -> Formatter {
  Formatter::new_terminal(
    terminal,
    FormatterOptions::new(Format::Plain, extra=FormatterTerminalExtra::none()),
  )
}

///|
test "formatter/plain formats content and reflects terminal changes" {
  let terminal = StreamTerminal::new()
  let formatter = plain_formatter(terminal)

  terminal.next_slice(b"Hello")
  guard formatter.format() == b"Hello" else {
    fail("expected plain formatter to emit current content")
  }

  terminal.next_slice(b"\r\nWorld")
  guard formatter.format() == b"Hello\nWorld" else {
    fail("expected formatter to observe later terminal writes")
  }

  terminal.deinit()
}

///|
test "formatter/plain owned bytes keep exact formatted length" {
  let terminal = StreamTerminal::new()
  let formatter = plain_formatter(terminal)

  terminal.next_slice(b"Hello")
  let output = formatter.format()
  guard output == b"Hello" && output.length() == 5 else {
    fail("expected owned formatter output to preserve exact size")
  }

  terminal.deinit()
}

///|
test "formatter/plain selection restricts output" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(b"Hello World")

  let selection = terminal
    .selection(
      Point::Active(Coordinate::new(6, 0U)),
      Point::Active(Coordinate::new(10, 0U)),
      false,
    )
    .unwrap()
  let formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(selection),
      extra=FormatterTerminalExtra::none(),
    ),
  )

  guard formatter.format() == b"World" else {
    fail("expected formatter selection to stay inclusive")
  }

  terminal.deinit()
}

///|
test "formatter/plain tracked selection follows active row into scrollback" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(3, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before tracked selection test")
  }
  terminal.next_slice(b"abc\r\ndef")
  let selection = terminal
    .selection(
      Point::Active(Coordinate::new(0, 0U)),
      Point::Active(Coordinate::new(2, 0U)),
      false,
    )
    .unwrap()

  terminal.next_slice(b"\r\nghi")
  let formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(selection),
      extra=FormatterTerminalExtra::none(),
    ),
  )

  guard formatter.format() == b"abc" else {
    fail("expected tracked selection to keep pointing at scrolled row")
  }

  terminal.untrack_selection(selection)
  terminal.deinit()
}

///|
test "formatter/plain styles constructor stays text-only and blank selection is empty" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(b"abc")

  let styled_plain = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(Format::Plain, extra=FormatterTerminalExtra::styles()),
  )
  guard styled_plain.format() == b"abc" else {
    fail("expected plain formatter to ignore style-only extras")
  }

  terminal.mode_set(Mode::AltScreenLegacy, true)

  let stale_formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(
        terminal
        .selection(
          Point::Active(Coordinate::new(0, 0U)),
          Point::Active(Coordinate::new(0, 0U)),
          false,
        )
        .unwrap(),
      ),
      extra=FormatterTerminalExtra::none(),
    ),
  )
  guard stale_formatter.format() == b"" else {
    fail("expected blank active-screen selection to format as empty")
  }

  terminal.deinit()
}

///|
test "formatter/plain stale pin selection formats empty" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(b"abc")
  let selection = terminal
    .selection(
      Point::Active(Coordinate::new(0, 0U)),
      Point::Active(Coordinate::new(2, 0U)),
      false,
    )
    .unwrap()
  terminal.reset()

  let formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(selection),
      extra=FormatterTerminalExtra::none(),
    ),
  )
  guard formatter.format() == b"" else {
    fail("expected stale pin selection to format as empty")
  }

  terminal.deinit()
}

///|
test "formatter/plain orders reversed and rectangle selections" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(4, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before selection ordering test")
  }
  terminal.next_slice(b"abcd\r\nwxyz")

  let reversed = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(
        terminal
        .selection(
          Point::Active(Coordinate::new(1, 0U)),
          Point::Active(Coordinate::new(0, 0U)),
          false,
        )
        .unwrap(),
      ),
      extra=FormatterTerminalExtra::none(),
    ),
  )
  guard reversed.format() == b"ab" else {
    fail("expected reversed linear selection to normalize order")
  }

  let rectangle = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(
        terminal
        .selection(
          Point::Active(Coordinate::new(2, 1U)),
          Point::Active(Coordinate::new(1, 0U)),
          true,
        )
        .unwrap(),
      ),
      extra=FormatterTerminalExtra::none(),
    ),
  )
  guard rectangle.format() == b"bc\nxy" else {
    fail("expected rectangle selection to normalize both axes")
  }

  terminal.deinit()
}

///|
test "formatter/plain preserves interior spaces and wide-cell boundaries" {
  let spaced = StreamTerminal::new()
  spaced.next_slice(b"a b")
  guard plain_formatter(spaced).format() == b"a b" else {
    fail("expected interior spaces to stay preserved")
  }
  spaced.deinit()

  let wide_tail = StreamTerminal::new()
  guard wide_tail.resize(2, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before wide-tail selection test")
  }
  wide_tail.next_slice(@utf8.encode("你"))
  let tail_formatter = Formatter::new_terminal(
    wide_tail,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(
        wide_tail
        .selection(
          Point::Active(Coordinate::new(1, 0U)),
          Point::Active(Coordinate::new(1, 0U)),
          false,
        )
        .unwrap(),
      ),
      extra=FormatterTerminalExtra::none(),
    ),
  )
  guard tail_formatter.format() == @utf8.encode("你") else {
    fail("expected wide-tail selection to include the full codepoint")
  }
  wide_tail.deinit()

  let wide_head = StreamTerminal::new()
  guard wide_head.resize(1, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before spacer-head selection test")
  }
  wide_head.next_slice(@utf8.encode("你"))
  let head_formatter = Formatter::new_terminal(
    wide_head,
    FormatterOptions::new(
      Format::Plain,
      selection=Some(
        wide_head
        .selection(
          Point::Active(Coordinate::new(0, 1U)),
          Point::Active(Coordinate::new(0, 1U)),
          false,
        )
        .unwrap(),
      ),
      extra=FormatterTerminalExtra::none(),
    ),
  )
  guard head_formatter.format() == b"" else {
    fail("expected spacer-head selection to stay empty")
  }
  wide_head.deinit()
}

///|
test "formatter/vt emits terminal and screen extras" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(4, 3, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before vt formatter test")
  }

  terminal.set_pwd("file:///tmp")
  terminal.mode_set(Mode::BracketedPaste, true)
  terminal.next_slice(b"\x1B[>4;2m")
  terminal.next_slice(b"\x1B[>3u")
  terminal.next_slice(b"\x1B)A\x0E")
  terminal.next_slice(b"\x1B[?69h\x1B[2;3r\x1B[2;4s")
  terminal.next_slice(b"\x1B[1\"q")
  terminal.next_slice(b"\x1B]8;id=foo;https://example.com\x1B\\")
  terminal.next_slice(b"\x1B[1mA")

  let formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(Format::Vt, extra=FormatterTerminalExtra::all()),
  )
  let output = formatter.format()

  guard bytes_contains(output, b"\x1B]4;0;rgb:") &&
    bytes_contains(output, b"\x1B[?2004h") &&
    bytes_contains(output, b"\x1B[2;3r") &&
    bytes_contains(output, b"\x1B[2;4s") &&
    bytes_contains(output, b"\x1B[3g") &&
    bytes_contains(output, b"\x1B[>4;2m") &&
    bytes_contains(output, b"\x1B]7;file:///tmp\x1B\\") &&
    bytes_contains(output, b"\x1B]8;id=foo;https://example.com\x1B\\") &&
    bytes_contains(output, b"\x1B[1\"q") &&
    bytes_contains(output, b"\x1B[=3;1u") &&
    bytes_contains(output, b"\x1B)A") &&
    bytes_contains(output, b"\x0E") &&
    bytes_contains(output, b"\x1B[1;2H") &&
    bytes_contains(output, b"A") else {
    fail("expected vt formatter extras to preserve current terminal state")
  }

  terminal.deinit()
}

///|
test "formatter/vt emits style transitions background cells and implicit screen state" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(2, 2, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before vt style test")
  }

  terminal.next_slice(
    b"\x1B[1;2;3;4:5;5;7;8;9;53;38;2;1;2;3;48;5;4;58;2;4;5;6mZ\x1B[0mQ",
  )
  let vt_formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(Format::Vt, extra=FormatterTerminalExtra::none()),
  )
  let vt_output = vt_formatter.format()
  guard bytes_contains(vt_output, b"\x1B[2m") &&
    bytes_contains(vt_output, b"\x1B[3m") &&
    bytes_contains(vt_output, b"\x1B[4:5m") &&
    bytes_contains(vt_output, b"\x1B[5m") &&
    bytes_contains(vt_output, b"\x1B[7m") &&
    bytes_contains(vt_output, b"\x1B[8m") &&
    bytes_contains(vt_output, b"\x1B[9m") &&
    bytes_contains(vt_output, b"\x1B[53m") &&
    bytes_contains(vt_output, b"\x1B[38;2;1;2;3m") &&
    bytes_contains(vt_output, b"\x1B[48;5;4m") &&
    bytes_contains(vt_output, b"\x1B[58;2;4;5;6m") &&
    bytes_contains(vt_output, b"Q") else {
    fail("expected vt formatter to re-emit rich cell styling")
  }

  let background = StreamTerminal::new()
  guard background.resize(2, 1, 0U, 0U) == TerminalResultCode::Success else {
    fail("expected resize before background-cell test")
  }
  background.next_slice(b"\x1B[48;2;7;8;9m\x1B[X\x1B[CX")
  let html_formatter = Formatter::new_terminal(
    background,
    FormatterOptions::new(Format::Html, extra=FormatterTerminalExtra::none()),
  )
  let html_output = html_formatter.format()
  guard bytes_contains(html_output, b"background-color: rgb(7, 8, 9);") &&
    bytes_contains(html_output, b"X") else {
    fail("expected html formatter to preserve background-only cells")
  }

  background.deinit()
  terminal.deinit()
}

///|
test "formatter/vt emits implicit hyperlink and alternate charset invocations" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(
    b"\x1B*0\x1B+B\x1Bn\x1B|\x1B]8;;https://example.com\x1B\\x",
  )

  let formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Vt,
      extra=FormatterTerminalExtra::new(
        screen=FormatterScreenExtra::new(hyperlink=true, charsets=true),
      ),
    ),
  )
  let output = formatter.format()

  guard bytes_contains(output, b"\x1B*0") &&
    bytes_contains(output, b"\x1B+B") &&
    bytes_contains(output, b"\x1Bn") &&
    bytes_contains(output, b"\x1B|") &&
    bytes_contains(output, b"\x1B]8;;https://example.com\x1B\\") else {
    fail(
      "expected vt formatter to preserve implicit hyperlink and charset state",
    )
  }

  terminal.deinit()
}

///|
test "formatter/html escapes text styles and hyperlinks" {
  let terminal = StreamTerminal::new()
  terminal.next_slice(b"plain\x1B[31m<tag>&\"'text")
  terminal.next_slice(
    b"\x1B[0m\x1B]8;;https://example.com?a=1&b=2\x1B\\link\x1B]8;;\x1B\\",
  )
  terminal.next_slice(@utf8.encode("é"))

  let formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Format::Html,
      extra=FormatterTerminalExtra::new(palette=true),
    ),
  )
  let output = formatter.format()

  guard bytes_contains(output, b"<style>:root{") &&
    bytes_contains(output, b"var(--vt-palette-1)") &&
    bytes_contains(output, b"plain") &&
    bytes_contains(output, b"&lt;tag&gt;&amp;&quot;&#39;text") &&
    bytes_contains(
      output, b"<a href=\"https://example.com?a=1&amp;b=2\">link</a>",
    ) &&
    bytes_contains(output, b"&#233;") else {
    fail("expected html formatter to escape text and hyperlink attributes")
  }

  terminal.deinit()
}
