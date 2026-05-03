///|
const DefaultCellWidthPx : UInt = 10U

///|
const DefaultCellHeightPx : UInt = 20U

///|
const MinColumns : Int = 1

///|
const MaxColumns : Int = 240

///|
const MinRows : Int = 1

///|
const MaxRows : Int = 120

///|
const DefaultBackground : String = "#101418"

///|
const DefaultForeground : String = "#dce4ea"

///|
priv struct TerminalLog {
  mut bell_count : Int
  mut title_change_count : Int
  pty : @buffer.Buffer
}

///|
fn TerminalLog::new() -> TerminalLog {
  { bell_count: 0, title_change_count: 0, pty: @buffer.new() }
}

///|
fn TerminalLog::clear(self : TerminalLog) -> Unit {
  self.bell_count = 0
  self.title_change_count = 0
  self.pty.reset()
}

///|
fn TerminalLog::write_pty(self : TerminalLog, data : Bytes) -> Unit {
  self.pty.write_bytes(data)
}

///|
fn TerminalLog::ring(self : TerminalLog) -> Unit {
  self.bell_count += 1
}

///|
fn TerminalLog::title_changed(self : TerminalLog) -> Unit {
  self.title_change_count += 1
}

///|
fn TerminalLog::pty_text(self : TerminalLog) -> String {
  @utf8.decode_lossy(self.pty.contents()[:])
}

///|
priv struct GhosttyTerminal {
  terminal : @terminal.StreamTerminal
  render : @terminal.RenderState
  log : TerminalLog
  mut background : String
  mut foreground : String
}

///|
fn GhosttyTerminal::new(
  cols? : Int = 80,
  rows? : Int = 24,
  background? : String = DefaultBackground,
  foreground? : String = DefaultForeground,
) -> GhosttyTerminal {
  let log = TerminalLog::new()
  let terminal = @terminal.StreamTerminal::new(
    write_pty=fn(data) { log.write_pty(data) },
    bell=fn() { log.ring() },
    title_changed=fn() { log.title_changed() },
    xtversion=fn() { "ghostty-rabbita-asciinema" },
  )
  terminal.set_size(fn() {
    Some(
      @terminal.Size::new(
        terminal.rows(),
        terminal.columns(),
        DefaultCellWidthPx,
        DefaultCellHeightPx,
      ),
    )
  })
  terminal.set_enquiry(fn() { @utf8.encode("ghostty-rabbita") })
  ignore(
    terminal.resize(
      clamp_columns(cols),
      clamp_rows(rows),
      DefaultCellWidthPx,
      DefaultCellHeightPx,
    ),
  )
  let render = @terminal.RenderState::new()
  render.update(terminal)
  { terminal, render, log, background, foreground }
}

///|
#warnings("-unused_value")
fn GhosttyTerminal::deinit(self : GhosttyTerminal) -> Unit {
  self.terminal.deinit()
}

///|
fn GhosttyTerminal::refresh(self : GhosttyTerminal) -> Unit {
  self.render.update(self.terminal)
}

///|
fn GhosttyTerminal::reset(
  self : GhosttyTerminal,
  cols~ : Int,
  rows~ : Int,
) -> Unit {
  self.terminal.reset()
  self.log.clear()
  ignore(
    self.terminal.resize(
      clamp_columns(cols),
      clamp_rows(rows),
      DefaultCellWidthPx,
      DefaultCellHeightPx,
    ),
  )
  self.refresh()
}

///|
fn GhosttyTerminal::resize(
  self : GhosttyTerminal,
  cols~ : Int,
  rows~ : Int,
) -> Unit {
  ignore(
    self.terminal.resize(
      clamp_columns(cols),
      clamp_rows(rows),
      DefaultCellWidthPx,
      DefaultCellHeightPx,
    ),
  )
  self.refresh()
}

///|
fn GhosttyTerminal::write_text(self : GhosttyTerminal, text : String) -> Unit {
  self.terminal.next_slice(@utf8.encode(text))
  self.refresh()
}

///|
fn GhosttyTerminal::set_theme(
  self : GhosttyTerminal,
  background~ : String,
  foreground~ : String,
) -> Unit {
  self.background = background
  self.foreground = foreground
}

///|
fn GhosttyTerminal::title(self : GhosttyTerminal) -> String? {
  self.terminal.title()
}

///|
fn GhosttyTerminal::bell_count(self : GhosttyTerminal) -> Int {
  self.log.bell_count
}

///|
fn GhosttyTerminal::title_change_count(self : GhosttyTerminal) -> Int {
  self.log.title_change_count
}

///|
fn GhosttyTerminal::pty_text(self : GhosttyTerminal) -> String {
  self.log.pty_text()
}

///|
fn GhosttyTerminal::rows(self : GhosttyTerminal) -> Int {
  self.terminal.rows().to_int()
}

///|
fn GhosttyTerminal::cols(self : GhosttyTerminal) -> Int {
  self.terminal.columns().to_int()
}

///|
fn GhosttyTerminal::cursor_x(self : GhosttyTerminal) -> Int {
  self.terminal.cursor_x().to_int()
}

///|
fn GhosttyTerminal::cursor_y(self : GhosttyTerminal) -> Int {
  self.terminal.cursor_y().to_int()
}

///|
#warnings("-unused_value")
fn GhosttyTerminal::plain_viewport(self : GhosttyTerminal) -> String {
  let out = @buffer.new()
  let rows = self.rows()
  let cols = self.cols()
  for row in 0..<rows {
    if row > 0 {
      out.write_byte(b'\n')
    }
    for col in 0..<cols {
      let cell = self.terminal.screen_cell_snapshot(
        row.to_uint16(),
        col.to_uint16(),
      )
      match cell {
        Some(cell) => out.write_string_utf8(self.cell_text(row, col, cell))
        None => out.write_byte(b' ')
      }
    }
  }
  @utf8.decode_lossy(out.contents()[:])
}

///|
fn GhosttyTerminal::view(
  self : GhosttyTerminal,
  class? : String = "terminal-host",
) -> @html.Html {
  self.refresh()
  let row_nodes : Array[@html.Html] = []
  let rows = self.rows()
  let cols = self.cols()
  for row in 0..<rows {
    let cells : Array[@html.Html] = []
    for col in 0..<cols {
      cells.push(self.cell_view(row, col))
    }
    row_nodes.push(
      @html.div(
        class="terminal-row",
        style=["grid-template-columns: repeat(\{cols}, 1ch)"],
        cells,
      ),
    )
  }
  @html.div(
    class~,
    style=[
      "background: \{self.background}",
      "color: \{self.foreground}",
      "--terminal-cols: \{cols}",
      "--terminal-rows: \{rows}",
    ],
    row_nodes,
  )
}

///|
fn GhosttyTerminal::cell_view(
  self : GhosttyTerminal,
  row : Int,
  col : Int,
) -> @html.Html {
  let cell = self.terminal.screen_cell_snapshot(
    row.to_uint16(),
    col.to_uint16(),
  )
  let (text, style, hyperlink) = match cell {
    Some(cell) =>
      (
        self.cell_text(row, col, cell),
        self.cell_style(row, col, cell),
        cell.hyperlink().map(link => link.uri()),
      )
    None => {
      let empty_style : Array[String] = []
      (" ", empty_style, None)
    }
  }
  let class = if self.is_cursor_cell(row, col) {
    "terminal-cell terminal-cursor"
  } else {
    "terminal-cell"
  }
  let span = @html.span(class~, style~, text)
  match hyperlink {
    Some(uri) => @html.a(class="terminal-link", href=uri, span)
    None => span
  }
}

///|
fn GhosttyTerminal::cell_text(
  self : GhosttyTerminal,
  row : Int,
  col : Int,
  cell : @terminal.PageCellState,
) -> String {
  match cell.wide() {
    @terminal.PageCellWide::SpacerHead | @terminal.PageCellWide::SpacerTail =>
      return " "
    @terminal.PageCellWide::Narrow | @terminal.PageCellWide::Wide => ()
  }
  if !cell.has_text() {
    return " "
  }
  if cell.has_grapheme() {
    let point = @terminal.Point::Viewport(
      @terminal.Coordinate::new(col.to_uint16(), row.reinterpret_as_uint()),
    )
    match self.terminal.grid_ref(point) {
      Some(grid_ref) =>
        match self.terminal.grid_ref_graphemes(grid_ref) {
          Some(codepoints) => return codepoints_to_string(codepoints)
          None => ()
        }
      None => ()
    }
  }
  codepoints_to_string([cell.codepoint()])
}

///|
fn GhosttyTerminal::cell_style(
  self : GhosttyTerminal,
  _row : Int,
  _col : Int,
  cell : @terminal.PageCellState,
) -> Array[String] {
  let styles : Array[String] = []
  let style = cell.style()
  let palette = self.terminal.palette()
  let fg = style_color_css(style.fg_color(), palette)
  let bg = cell_background_css(cell, palette, style)
  let (resolved_fg, resolved_bg) = if style.inverse() {
    (Some(bg.unwrap_or(self.background)), Some(fg.unwrap_or(self.foreground)))
  } else {
    (fg, bg)
  }
  match resolved_fg {
    Some(color) => styles.push("color: \{color}")
    None => ()
  }
  match resolved_bg {
    Some(color) => styles.push("background-color: \{color}")
    None => ()
  }
  if style.bold() {
    styles.push("font-weight: 700")
  }
  if style.italic() {
    styles.push("font-style: italic")
  }
  if style.faint() {
    styles.push("opacity: 0.55")
  }
  if style.invisible() {
    styles.push("visibility: hidden")
  }
  let decoration = text_decoration(style)
  match decoration {
    Some(value) => styles.push(value)
    None => ()
  }
  styles
}

///|
fn GhosttyTerminal::is_cursor_cell(
  self : GhosttyTerminal,
  row : Int,
  col : Int,
) -> Bool {
  self.terminal.cursor_visible() &&
  row == self.terminal.cursor_y().to_int() &&
  col == self.terminal.cursor_x().to_int()
}

///|
fn codepoints_to_string(codepoints : Array[UInt]) -> String {
  let out = @buffer.new()
  for codepoint in codepoints {
    if codepoint == 0U {
      out.write_byte(b' ')
    } else {
      out.write_char_utf8(codepoint.reinterpret_as_int().unsafe_to_char())
    }
  }
  @utf8.decode_lossy(out.contents()[:])
}

///|
fn cell_background_css(
  cell : @terminal.PageCellState,
  palette : Array[@terminal.RGB],
  style : @terminal.CellStyle,
) -> String? {
  match cell.content_tag() {
    @terminal.PageCellContentTag::BackgroundPalette =>
      cell.palette_index().map(index => rgb_css(palette[index.to_int()]))
    @terminal.PageCellContentTag::BackgroundRgb =>
      cell.background_rgb().map(rgb => rgb_css(rgb))
    @terminal.PageCellContentTag::Codepoint
    | @terminal.PageCellContentTag::CodepointGrapheme =>
      style_color_css(style.bg_color(), palette)
  }
}

///|
fn style_color_css(
  color : @terminal.StyleColor,
  palette : Array[@terminal.RGB],
) -> String? {
  match color.rgb_value() {
    Some(rgb) => Some(rgb_css(rgb))
    None =>
      match color.palette_index() {
        Some(index) => Some(rgb_css(palette[index.to_int()]))
        None => None
      }
  }
}

///|
fn rgb_css(rgb : @terminal.RGB) -> String {
  "rgb(\{rgb.r().to_int()}, \{rgb.g().to_int()}, \{rgb.b().to_int()})"
}

///|
fn text_decoration(style : @terminal.CellStyle) -> String? {
  let lines : Array[String] = []
  if style.underline() != @terminal.SgrUnderline::None {
    lines.push("underline")
  }
  if style.strikethrough() {
    lines.push("line-through")
  }
  if style.overline() {
    lines.push("overline")
  }
  if lines.is_empty() {
    None
  } else {
    let decoration_style = match style.underline() {
      @terminal.SgrUnderline::None | @terminal.SgrUnderline::Single => "solid"
      @terminal.SgrUnderline::Double => "double"
      @terminal.SgrUnderline::Curly => "wavy"
      @terminal.SgrUnderline::Dotted => "dotted"
      @terminal.SgrUnderline::Dashed => "dashed"
    }
    let line_value = lines.join(" ")
    Some(
      "text-decoration-line: \{line_value}; text-decoration-style: \{decoration_style}",
    )
  }
}

///|
fn clamp_columns(cols : Int) -> UInt16 {
  cols.clamp(min=MinColumns, max=MaxColumns).to_uint16()
}

///|
fn clamp_rows(rows : Int) -> UInt16 {
  rows.clamp(min=MinRows, max=MaxRows).to_uint16()
}
