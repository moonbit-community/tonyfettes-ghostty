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
    @rabbita.static_cell(terminal.cell_view(999, 999)),
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

  let styled = @terminal.PageCellState::init(b'X'.to_uint())
  let style = @terminal.CellStyle::new()
  style.apply_attribute(@terminal.SgrAttribute::Bold)
  style.apply_attribute(@terminal.SgrAttribute::Italic)
  style.apply_attribute(@terminal.SgrAttribute::Faint)
  style.apply_attribute(@terminal.SgrAttribute::Invisible)
  style.apply_attribute(@terminal.SgrAttribute::Inverse)
  style.apply_attribute(@terminal.SgrAttribute::Strikethrough)
  style.apply_attribute(@terminal.SgrAttribute::Overline)
  style.apply_attribute(
    @terminal.SgrAttribute::DirectColorFg(@terminal.RGB::new(1, 2, 3)),
  )
  style.apply_attribute(
    @terminal.SgrAttribute::DirectColorBg(@terminal.RGB::new(4, 5, 6)),
  )
  styled.set_style(style)
  let css = terminal.cell_style(0, 0, styled).join(";")
  guard css.contains("font-weight") &&
    css.contains("font-style") &&
    css.contains("opacity") &&
    css.contains("visibility") &&
    css.contains("line-through") &&
    css.contains("overline") else {
    fail("expected rich style css")
  }

  let palette_cell = @terminal.PageCellState::new()
  palette_cell.set_background_palette(1)
  guard terminal
    .cell_style(0, 0, palette_cell)
    .join(";")
    .contains("background-color") else {
    fail("expected palette background")
  }

  let rgb_cell = @terminal.PageCellState::new()
  rgb_cell.set_background_rgb(@terminal.RGB::new(8, 9, 10))
  guard terminal.cell_style(0, 0, rgb_cell).join(";").contains("rgb(8, 9, 10)") else {
    fail("expected rgb background")
  }

  let spacer = @terminal.PageCellState::init(b'Z'.to_uint())
  spacer.set_wide(@terminal.PageCellWide::SpacerHead)
  assert_eq(terminal.cell_text(0, 0, spacer), " ")
  let grapheme = @terminal.PageCellState::new()
  grapheme.set_codepoint(b'e'.to_uint(), true)
  ignore(terminal.cell_text(0, 0, grapheme))
  ignore(terminal.cell_text(999, 999, grapheme))
  assert_eq(codepoints_to_string([0U, b'A'.to_uint()]), " A")
  terminal.deinit()
}

///|
test "ghostty terminal adapter underline style variants" {
  for
    underline in [
      @terminal.SgrUnderline::Double,
      @terminal.SgrUnderline::Curly,
      @terminal.SgrUnderline::Dotted,
      @terminal.SgrUnderline::Dashed,
    ] {
    let style = @terminal.CellStyle::new()
    style.apply_attribute(@terminal.SgrAttribute::Underline(underline))
    guard text_decoration(style) is Some(_) else {
      fail("expected text decoration")
    }
  }
}
