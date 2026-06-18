///|
fn wb_bytes_contains(haystack : Bytes, needle : Bytes) -> Bool {
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
    FormatterOptions::new(Plain, extra=FormatterTerminalExtra::none()),
  )
}

///|
test "formatter helpers/cover guard branches and ordering helpers" {
  let terminal = StreamTerminal::new()
  let formatter = plain_formatter(terminal)
  let state = terminal.bridge()
  let single_cell_bounds : FormatterSelectionBounds = {
    start: Coordinate::new(0, 0U),
    end_: Coordinate::new(0, 0U),
    rectangle: false,
  }

  state.grid = { rows: 24, cols: 0, descs: [], cells: [], cell_pool: [] }
  guard formatter_selection_bounds(formatter, state, 1U) is None else {
    fail("expected zero-column guard to reject formatting")
  }
  guard formatter_row_bounds(state, single_cell_bounds, 0) is None else {
    fail("expected zero-column row bounds to reject formatting")
  }

  state.grid = ScreenGridState::new(24, 80)

  guard min_cell_count(1, 2) == 1 &&
    min_cell_count(2, 1) == 1 &&
    max_cell_count(2, 1) == 2 &&
    max_cell_count(1, 2) == 2 &&
    min_uint(1U, 2U) == 1U &&
    formatter_max_uint(1U, 2U) == 2U else {
    fail("expected helper min/max ordering")
  }
  guard formatter_charset_final(Utf8) == b'B' &&
    formatter_charset_designator(G0) == b'(' else {
    fail("expected charset helper defaults")
  }

  terminal.deinit()
}

///|
test "formatter helpers/cover row bounds and sparse content paths" {
  let terminal = StreamTerminal::new()
  let formatter = plain_formatter(terminal)
  let state = terminal.bridge()

  let descending_bounds : FormatterSelectionBounds = {
    start: Coordinate::new(2, 0U),
    end_: Coordinate::new(1, 0U),
    rectangle: false,
  }
  guard formatter_row_bounds(state, descending_bounds, 0) is None else {
    fail("expected descending row bounds to stay empty")
  }
  let descending_buffer = Buffer()
  formatter_write_content(
    formatter, state, descending_bounds, descending_buffer,
  )
  guard descending_buffer.contents() == b"" else {
    fail("expected descending bounds content write to stay empty")
  }

  let clamped_bounds : FormatterSelectionBounds = {
    start: Coordinate::new(0, 0U),
    end_: Coordinate::new(99, 0U),
    rectangle: false,
  }
  match formatter_row_bounds(state, clamped_bounds, 0) {
    Some(bounds) =>
      if bounds.start_x != 0 || bounds.end_x != 79 {
        fail("expected oversized selection to clamp to visible width")
      }
    None => fail("expected oversized selection to clamp to visible width")
  }
  state.grid = ScreenGridState::new(2, 2)
  state.scrollback = PageList::new(2, 2, 0)
  state.grid.cells[1][1] = state.grid.cells[1][1].with_wide(SpacerHead)
  let spacer_head_bounds : FormatterSelectionBounds = {
    start: Coordinate::new(1, 1U),
    end_: Coordinate::new(1, 1U),
    rectangle: false,
  }
  guard formatter_row_bounds(state, spacer_head_bounds, 1) is None else {
    fail("expected spacer-head row bounds to be skipped")
  }

  let sparse = StreamTerminal::new()
  guard sparse.resize(1, 1, 0U, 0U) == Success else {
    fail("expected resize before sparse helper test")
  }
  let sparse_state = sparse.bridge()
  let missing_row_bounds : FormatterSelectionBounds = {
    start: Coordinate::new(0, 9U),
    end_: Coordinate::new(0, 9U),
    rectangle: false,
  }
  let missing_buffer = Buffer()
  formatter_write_content(
    formatter, sparse_state, missing_row_bounds, missing_buffer,
  )
  guard formatter_row_is_blank(sparse_state, 9, { start_x: 0, end_x: 0 }) else {
    fail("expected blank-row helper to treat missing rows as blank")
  }
  sparse_state.grid = ScreenGridState::new(1, 2)
  sparse_state.scrollback = PageList::new(1, 2, 0)
  let missing_row_cell_probe : FormatterSelectionBounds = {
    start: Coordinate::new(1, 9U),
    end_: Coordinate::new(1, 9U),
    rectangle: false,
  }
  match formatter_row_bounds(sparse_state, missing_row_cell_probe, 9) {
    Some(bounds) =>
      if bounds.start_x != 1 || bounds.end_x != 1 {
        fail("expected missing-row probe to preserve clamped bounds")
      }
    None => fail("expected missing-row probe to hit missing-cell guard")
  }

  sparse.deinit()
  terminal.deinit()
}

///|
test "formatter helpers/cover style and palette encoders" {
  let mut style = @style.CellStyle::new()
  style = style.apply_attribute(Bold)
  style = style.apply_attribute(Faint)
  style = style.apply_attribute(Italic)
  style = style.apply_attribute(Blink)
  style = style.apply_attribute(Inverse)
  style = style.apply_attribute(Invisible)
  style = style.apply_attribute(Strikethrough)
  style = style.apply_attribute(Overline)
  style = style.apply_attribute(Underline(Single))
  style = style.apply_attribute(DirectColorFg(@color.RGB::new(1, 2, 3)))
  style = style.apply_attribute(Color256Bg(4))
  style = style.apply_attribute(UnderlineColor(@color.RGB::new(5, 6, 7)))

  let vt = Buffer()
  formatter_write_vt_style_open(vt, style)
  let vt_bytes = vt.contents()
  guard wb_bytes_contains(vt_bytes, b"\x1B[1m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[2m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[3m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[5m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[7m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[8m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[9m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[53m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[4m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[38;2;1;2;3m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[48;5;4m") &&
    wb_bytes_contains(vt_bytes, b"\x1B[58;2;5;6;7m") else {
    fail("expected VT helper to encode all style branches")
  }

  let html = Buffer()
  formatter_write_html_style(html, style)
  let html_bytes = html.contents()
  guard wb_bytes_contains(
      html_bytes, b"text-decoration-line: underline line-through overline blink;",
    ) &&
    wb_bytes_contains(html_bytes, b"text-decoration-style: solid;") &&
    wb_bytes_contains(html_bytes, b"font-weight: bold;") &&
    wb_bytes_contains(html_bytes, b"font-style: italic;") &&
    wb_bytes_contains(html_bytes, b"opacity: 0.5;") &&
    wb_bytes_contains(html_bytes, b"visibility: hidden;") &&
    wb_bytes_contains(html_bytes, b"filter: invert(100%);") else {
    fail("expected HTML helper to encode style properties")
  }

  let palette_cell = PageCellState::new(
    style=@style.CellStyle::new().with_bg_color(@style.StyleColor::palette(7)),
  )
  let palette_style = palette_cell.style()
  guard palette_style.bg_color().palette_index() == Some(7) else {
    fail("expected background-palette cell helper")
  }

  let plain_palette = Buffer()
  formatter_write_palette(Plain, @color.default_palette(), plain_palette)
  guard plain_palette.contents() == b"" else {
    fail("expected plain palette helper to stay silent")
  }

  let vt_newline = Buffer()
  formatter_write_newlines(Vt, vt_newline, 1)
  guard vt_newline.contents() == b"\r\n" else {
    fail("expected VT newline helper")
  }
  let html_newline = Buffer()
  formatter_write_newlines(Html, html_newline, 2)
  guard html_newline.contents() == b"\n\n" else {
    fail("expected HTML newline helper")
  }

  let mut double_style = @style.CellStyle::new()
  double_style = double_style.apply_attribute(Underline(Double))
  let vt_double = Buffer()
  formatter_write_vt_style_open(vt_double, double_style)
  guard wb_bytes_contains(vt_double.contents(), b"\x1B[4:2m") else {
    fail("expected VT helper to encode double underline")
  }
  let html_double = Buffer()
  formatter_write_html_style(html_double, double_style)
  guard wb_bytes_contains(
    html_double.contents(),
    b"text-decoration-style: double;",
  ) else {
    fail("expected HTML helper to encode double underline")
  }

  let mut curly_style = @style.CellStyle::new()
  curly_style = curly_style.apply_attribute(Underline(Curly))
  let vt_curly = Buffer()
  formatter_write_vt_style_open(vt_curly, curly_style)
  guard wb_bytes_contains(vt_curly.contents(), b"\x1B[4:3m") else {
    fail("expected VT helper to encode curly underline")
  }
  let html_curly = Buffer()
  formatter_write_html_style(html_curly, curly_style)
  guard wb_bytes_contains(
    html_curly.contents(),
    b"text-decoration-style: wavy;",
  ) else {
    fail("expected HTML helper to encode curly underline")
  }

  let mut dotted_style = @style.CellStyle::new()
  dotted_style = dotted_style.apply_attribute(Underline(Dotted))
  let vt_dotted = Buffer()
  formatter_write_vt_style_open(vt_dotted, dotted_style)
  guard wb_bytes_contains(vt_dotted.contents(), b"\x1B[4:4m") else {
    fail("expected VT helper to encode dotted underline")
  }
  let html_dotted = Buffer()
  formatter_write_html_style(html_dotted, dotted_style)
  guard wb_bytes_contains(
    html_dotted.contents(),
    b"text-decoration-style: dotted;",
  ) else {
    fail("expected HTML helper to encode dotted underline")
  }

  let mut dashed_style = @style.CellStyle::new()
  dashed_style = dashed_style.apply_attribute(Underline(Dashed))
  let html_dashed = Buffer()
  formatter_write_html_style(html_dashed, dashed_style)
  guard wb_bytes_contains(
    html_dashed.contents(),
    b"text-decoration-style: dashed;",
  ) else {
    fail("expected HTML helper to encode dashed underline")
  }
}

///|
test "formatter helpers/cover terminal extra fallbacks and no-op branches" {
  let terminal = StreamTerminal::new()
  guard terminal.resize(10, 3, 0U, 0U) == Success else {
    fail("expected resize before extra helper test")
  }
  let state = terminal.bridge()
  state.cursor.top_margin = 0
  state.cursor.bottom_margin = 1
  state.cursor.left_margin = 0
  state.cursor.right_margin = 8
  state.input_flags.modify_other_keys_2 = true
  state.tabstops.reset(8)
  state.charset.configure(G0, Ascii)
  state.charset.invoke(Gl, G3, false)
  state.charset.invoke(Gr, G1, false)

  let formatter = Formatter::new_terminal(
    terminal,
    FormatterOptions::new(
      Vt,
      extra=FormatterTerminalExtra::new(
        modes=true,
        scrolling_region=true,
        tabstops=true,
        pwd=true,
        keyboard=true,
        screen=FormatterScreenExtra::new(hyperlink=true, charsets=true),
      ),
    ),
  )
  let buffer = Buffer()
  formatter_write_terminal_extras(formatter, state, buffer)
  let bytes = buffer.contents()

  guard wb_bytes_contains(bytes, b"\x1B[1;2r") &&
    wb_bytes_contains(bytes, b"\x1B[1;9s") &&
    wb_bytes_contains(bytes, b"\x1B[3g") &&
    wb_bytes_contains(bytes, b"\x1B[9G\x1BH") &&
    wb_bytes_contains(bytes, b"\x1B[>4;2m") &&
    wb_bytes_contains(bytes, b"\x1B(B") &&
    wb_bytes_contains(bytes, b"\x1Bo") &&
    wb_bytes_contains(bytes, b"\x1B~") &&
    wb_bytes_contains(bytes, b"\x1B[?1l") == false else {
    fail("expected terminal extra helper to stay on explicit branches only")
  }

  let screen_buffer = Buffer()
  formatter_write_screen_extras(
    FormatterScreenExtra::new(hyperlink=true),
    state,
    screen_buffer,
  )
  guard screen_buffer.contents() == b"" else {
    fail("expected hyperlink-none screen extras to stay silent")
  }

  state.charset.invoke(Gr, G0, false)
  let gr_zero_buffer = Buffer()
  formatter_write_screen_extras(
    FormatterScreenExtra::new(charsets=true),
    state,
    gr_zero_buffer,
  )
  guard wb_bytes_contains(gr_zero_buffer.contents(), b"\x1B(B") &&
    wb_bytes_contains(gr_zero_buffer.contents(), b"\x1Bo") &&
    !wb_bytes_contains(gr_zero_buffer.contents(), b"\x1B~") else {
    fail("expected GR G0 charset branch to stay silent")
  }

  terminal.deinit()
}

///|
test "formatter helpers/cover explicit empty format guard" {
  let terminal = StreamTerminal::new()
  let state = terminal.bridge()
  state.grid = { rows: 0, cols: 0, descs: [], cells: [], cell_pool: [] }
  state.scrollback = PageList::new(0, 0, 0)
  let formatter = plain_formatter(terminal)
  guard formatter.format() == b"" else {
    fail("expected zero-row formatter guard")
  }
  terminal.deinit()
}
