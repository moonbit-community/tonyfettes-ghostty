///|
test "ghostty terminal adapter writes output into viewport" {
  let terminal = GhosttyTerminal::new(cols=12, rows=3)
  terminal.write_text("hello")
  let plain = terminal.plain_viewport()
  guard plain.has_prefix("hello") else {
    fail("expected written output in viewport")
  }
  terminal.deinit()
}

///|
test "ghostty terminal adapter resizes and resets" {
  let terminal = GhosttyTerminal::new(cols=5, rows=2)
  assert_eq(terminal.cols(), 5)
  assert_eq(terminal.rows(), 2)
  terminal.write_text("abcdef")
  terminal.resize(cols=8, rows=4)
  assert_eq(terminal.cols(), 8)
  assert_eq(terminal.rows(), 4)
  terminal.reset(cols=3, rows=2)
  assert_eq(terminal.cols(), 3)
  assert_eq(terminal.rows(), 2)
  guard terminal.plain_viewport().has_prefix("   ") else {
    fail("expected reset blank viewport")
  }
  terminal.deinit()
}

///|
test "ghostty terminal adapter captures title bell and pty replies" {
  let terminal = GhosttyTerminal::new(cols=20, rows=4)
  terminal.write_text("\u{7}\u{1B}]0;Demo title\u{7}\u{5}\u{1B}[18t\u{1B}[>q")
  assert_eq(terminal.bell_count(), 1)
  assert_eq(terminal.title_change_count(), 1)
  guard terminal.title() == Some("Demo title") else {
    fail("expected OSC title")
  }
  guard !terminal.pty_text().is_empty() else { fail("expected enquiry reply") }
  guard terminal.pty_text().contains("ghostty-rabbita-asciinema") else {
    fail("expected xtversion reply")
  }
  assert_eq(terminal.cursor_x(), 0)
  assert_eq(terminal.cursor_y(), 0)
  terminal.deinit()
}

///|
#warnings("-alert_unstable")
test "ghostty terminal adapter renders styled html" {
  let terminal = GhosttyTerminal::new(cols=12, rows=3)
  terminal.write_text("\u{1B}[31;4mR\u{1B}[0m")
  let html = @rabbita.render_to_string(@rabbita.static_cell(terminal.view()))
  guard html.contains("terminal-cell") else { fail("expected terminal cells") }
  guard html.contains("text-decoration-line") else {
    fail("expected underline style")
  }
  terminal.deinit()
}

///|
#warnings("-alert_unstable")
test "ghostty terminal adapter renders hyperlinks and fallback cells" {
  let terminal = GhosttyTerminal::new(cols=20, rows=3)
  terminal.write_text(
    "\u{1B}]8;;https://example.com\u{1B}\\link\u{1B}]8;;\u{1B}\\",
  )
  let html = @rabbita.render_to_string(@rabbita.static_cell(terminal.view()))
  guard html.contains("https://example.com") else {
    fail("expected hyperlink href")
  }
  let fallback = @rabbita.render_to_string(
    @rabbita.static_cell(terminal.cell_view(999, 999, @color.default_palette())),
  )
  guard fallback.contains("terminal-cell") else {
    fail("expected fallback cell")
  }
  terminal.deinit()
}

///|
test "ghostty terminal adapter direct cell style branches" {
  let terminal = GhosttyTerminal::new(cols=4, rows=2)
  terminal.set_theme(background="#000000", foreground="#ffffff")

  // The cell stores only a `StyleId`; `cell_style` resolves the full style by
  // position through the terminal's shared table. So drive the styles through the
  // VT stream and read them back by column, rather than constructing styled cells.
  //
  // Column 0: every rich attribute at once (bold 1, faint 2, italic 3, inverse 7,
  // invisible 8, strikethrough 9, overline 53).
  terminal.write_text("\u{1B}[1;2;3;7;8;9;53mX\u{1B}[0m")
  let css = terminal.cell_style(0, 0, @color.default_palette()).join(";")
  guard css.contains("font-weight") &&
    css.contains("font-style") &&
    css.contains("opacity") &&
    css.contains("visibility") &&
    css.contains("line-through") &&
    css.contains("overline") else {
    fail("expected rich style css")
  }

  // Column 1: a 256-color palette background (SGR 48;5;1).
  terminal.write_text("\u{1B}[48;5;1mY\u{1B}[0m")
  guard terminal
    .cell_style(0, 1, @color.default_palette())
    .join(";")
    .contains("background-color") else {
    fail("expected palette background")
  }

  // Column 2: a direct-color (rgb) background (SGR 48;2;8;9;10).
  terminal.write_text("\u{1B}[48;2;8;9;10mZ\u{1B}[0m")
  guard terminal
    .cell_style(0, 2, @color.default_palette())
    .join(";")
    .contains("rgb(8, 9, 10)") else {
    fail("expected rgb background")
  }

  let spacer = @terminal.PageCellState::new(
    codepoint=b'Z'.to_uint(),
    wide=SpacerHead,
  )
  assert_eq(terminal.cell_text(0, 0, spacer), " ")
  let grapheme = @terminal.PageCellState::new(
    codepoint=b'e'.to_uint(),
    grapheme=true,
  )
  ignore(terminal.cell_text(0, 0, grapheme))
  ignore(terminal.cell_text(999, 999, grapheme))
  assert_eq(codepoints_to_string([0U, b'A'.to_uint()]), " A")
  terminal.deinit()
}

///|
test "ghostty terminal adapter underline style variants" {
  for underline in [@sgr.SgrUnderline::Double, Curly, Dotted, Dashed] {
    let mut style = @style.CellStyle::new()
    style = style.apply_attribute(Underline(underline))
    guard text_decoration(style) is Some(_) else {
      fail("expected text decoration")
    }
  }
}
