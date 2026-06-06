///|
pub(all) enum Format {
  Plain
  Vt
  Html
} derive(Eq, Debug)

///|
struct FormatterScreenExtra {
  cursor : Bool
  style : Bool
  hyperlink : Bool
  protection : Bool
  kitty_keyboard : Bool
  charsets : Bool
} derive(Eq, Debug)

///|
pub fn FormatterScreenExtra::new(
  cursor? : Bool = false,
  style? : Bool = false,
  hyperlink? : Bool = false,
  protection? : Bool = false,
  kitty_keyboard? : Bool = false,
  charsets? : Bool = false,
) -> FormatterScreenExtra {
  { cursor, style, hyperlink, protection, kitty_keyboard, charsets }
}

///|
pub fn FormatterScreenExtra::none() -> FormatterScreenExtra {
  FormatterScreenExtra::new()
}

///|
pub fn FormatterScreenExtra::styles() -> FormatterScreenExtra {
  FormatterScreenExtra::new(style=true, hyperlink=true)
}

///|
pub fn FormatterScreenExtra::all() -> FormatterScreenExtra {
  FormatterScreenExtra::new(
    cursor=true,
    style=true,
    hyperlink=true,
    protection=true,
    kitty_keyboard=true,
    charsets=true,
  )
}

///|
struct FormatterTerminalExtra {
  palette : Bool
  modes : Bool
  scrolling_region : Bool
  tabstops : Bool
  pwd : Bool
  keyboard : Bool
  screen : FormatterScreenExtra
} derive(Eq, Debug)

///|
pub fn FormatterTerminalExtra::new(
  palette? : Bool = false,
  modes? : Bool = false,
  scrolling_region? : Bool = false,
  tabstops? : Bool = false,
  pwd? : Bool = false,
  keyboard? : Bool = false,
  screen? : FormatterScreenExtra = FormatterScreenExtra::none(),
) -> FormatterTerminalExtra {
  { palette, modes, scrolling_region, tabstops, pwd, keyboard, screen }
}

///|
pub fn FormatterTerminalExtra::none() -> FormatterTerminalExtra {
  FormatterTerminalExtra::new()
}

///|
pub fn FormatterTerminalExtra::styles() -> FormatterTerminalExtra {
  FormatterTerminalExtra::new(
    palette=true,
    screen=FormatterScreenExtra::styles(),
  )
}

///|
pub fn FormatterTerminalExtra::all() -> FormatterTerminalExtra {
  FormatterTerminalExtra::new(
    palette=true,
    modes=true,
    scrolling_region=true,
    tabstops=true,
    pwd=true,
    keyboard=true,
    screen=FormatterScreenExtra::all(),
  )
}

///|
struct FormatterOptions {
  emit : Format
  unwrap : Bool
  trim : Bool
  selection : Selection?
  extra : FormatterTerminalExtra
}

///|
pub fn FormatterOptions::new(
  emit : Format,
  unwrap? : Bool = false,
  trim? : Bool = true,
  selection? : Selection? = None,
  extra? : FormatterTerminalExtra = FormatterTerminalExtra::styles(),
) -> FormatterOptions {
  { emit, unwrap, trim, selection, extra }
}

///|
struct Formatter {
  terminal : StreamTerminal
  opts : FormatterOptions
}

///|
pub fn Formatter::new_terminal(
  terminal : StreamTerminal,
  opts : FormatterOptions,
) -> Formatter {
  { terminal, opts }
}

///|
pub fn Formatter::format(self : Formatter) -> Bytes {
  let state = self.terminal.bridge()
  let total_rows = state.scrollback.total_rows(state.grid.rows)
  if total_rows == 0U {
    return b""
  }

  match formatter_selection_bounds(self, state, total_rows) {
    Some(bounds) => {
      let buffer = Buffer()
      formatter_write_prefix(self, state, buffer)
      formatter_write_content(self, state, bounds, buffer)
      formatter_write_suffix(self, state, buffer)
      buffer.contents()
    }
    None => b""
  }
}

///|
/// Format the current render viewport as framebuffer-style VT bytes.
///
/// Each row starts with an absolute cursor position. The output never relies on
/// CR/LF for layout, so the host terminal's pending-wrap state cannot shift the
/// following rows.
pub fn RenderState::format_vt_framebuffer(self : RenderState) -> Bytes {
  let buffer = Buffer()
  let columns = self.columns().to_int()
  let rows = self.row_iterator()
  while rows.next() {
    match rows.y() {
      Some(y) => formatter_write_vt_cup(buffer, (y + 1).to_uint64(), 1UL)
      None => ()
    }
    match rows.cells() {
      Some(cells) =>
        formatter_write_render_state_frame_row(cells, columns, buffer)
      None => ()
    }
  }
  buffer.contents()
}

///|
fn formatter_write_render_state_frame_row(
  cells : RenderRowCells,
  columns : Int,
  buffer : @buffer.Buffer,
) -> Unit {
  let output = FormatterOutputState::new()
  let last = formatter_render_state_last_cell(cells, columns)
  if last >= 0 {
    let mut blank_cells = 0
    let mut x = 0
    while x <= last {
      if !cells.select(x.to_uint16()) {
        x += 1
        continue
      }

      match cells.cell() {
        None => ()
        Some(cell) => {
          match cell.wide() {
            SpacerHead | SpacerTail => {
              x += 1
              continue
            }
            Narrow | Wide => ()
          }

          if formatter_history_cell_is_blank(cell) {
            blank_cells += 1
            x += 1
            continue
          }

          if blank_cells > 0 {
            formatter_write_spaces(buffer, blank_cells)
            blank_cells = 0
          }

          output.sync_vt_style(formatter_cell_style(cell), buffer)
          formatter_write_cell_text(Vt, cell, buffer)
        }
      }
      x += 1
    }
  }
  output.close(Vt, buffer)
  buffer.write_bytes(VtEraseToEndOfLine)
}

///|
fn formatter_render_state_last_cell(
  cells : RenderRowCells,
  columns : Int,
) -> Int {
  let mut last = -1
  let mut x = 0
  while x < columns {
    if cells.select(x.to_uint16()) {
      match cells.cell() {
        Some(cell) => if !formatter_history_cell_is_blank(cell) { last = x }
        None => ()
      }
    }
    x += 1
  }
  last
}

///|
priv struct FormatterSelectionBounds {
  start : Coordinate
  end_ : Coordinate
  rectangle : Bool
}

///|
priv struct FormatterRowBounds {
  start_x : Int
  end_x : Int
}

///|
priv struct FormatterOutputState {
  mut vt_style : CellStyle
  mut html_open : Bool
  mut html_style : CellStyle
  mut html_hyperlink : String?
}

///|
fn FormatterOutputState::new() -> FormatterOutputState {
  {
    vt_style: CellStyle::new(),
    html_open: false,
    html_style: CellStyle::new(),
    html_hyperlink: None,
  }
}

///|
const HtmlWrapperOpen : Bytes = b"<div style=\"font-family: monospace; white-space: pre;\">"

///|
const HtmlWrapperClose : Bytes = b"</div>"

///|
const HtmlRunOpenPrefix : Bytes = b"<div style=\"display: inline;"

///|
const HtmlHrefOpen : Bytes = b"<a href=\""

///|
const HtmlHrefClose : Bytes = b"\">"

///|
const HtmlAnchorClose : Bytes = b"</a>"

///|
const HtmlStyleClose : Bytes = b"</div>"

///|
const VtStyleReset : Bytes = b"\x1B[0m"

///|
const VtEraseToEndOfLine : Bytes = b"\x1B[K"

///|
const NewlinePlain : Bytes = b"\n"

///|
const NewlineVt : Bytes = b"\r\n"

///|
const NewlineHtml : Bytes = b"\n"

///|
fn formatter_selection_bounds(
  formatter : Formatter,
  state : StreamTerminalBridgeState,
  total_rows : UInt,
) -> FormatterSelectionBounds? {
  let cols = state.grid.cols
  if cols == 0 {
    return None
  }

  match formatter.opts.selection {
    None =>
      Some({
        start: Coordinate::new(0, 0U),
        end_: Coordinate::new(cols - 1, total_rows - 1U),
        rectangle: false,
      })
    Some(selection) => {
      let start = match state.point_from_pin(selection.start(), Screen) {
        Some(value) => value
        None => return None
      }
      let end_ = match state.point_from_pin(selection.end(), Screen) {
        Some(value) => value
        None => return None
      }
      if selection.rectangle() {
        Some({
          start: Coordinate::new(
            min_cell_count(start.x(), end_.x()),
            min_uint(start.y(), end_.y()),
          ),
          end_: Coordinate::new(
            max_cell_count(start.x(), end_.x()),
            formatter_max_uint(start.y(), end_.y()),
          ),
          rectangle: true,
        })
      } else if formatter_coord_before(end_, start) {
        Some({ start: end_, end_: start, rectangle: false })
      } else {
        Some({ start, end_, rectangle: false })
      }
    }
  }
}

///|
fn formatter_write_prefix(
  formatter : Formatter,
  state : StreamTerminalBridgeState,
  buffer : @buffer.Buffer,
) -> Unit {
  if formatter.opts.extra.palette {
    formatter_write_palette(formatter.opts.emit, state.palette(), buffer)
  }

  if formatter.opts.emit == Html {
    buffer.write_bytes(HtmlWrapperOpen)
  }
}

///|
fn formatter_write_suffix(
  formatter : Formatter,
  state : StreamTerminalBridgeState,
  buffer : @buffer.Buffer,
) -> Unit {
  if formatter.opts.emit == Vt {
    formatter_write_terminal_extras(formatter, state, buffer)
  }

  if formatter.opts.emit == Html {
    buffer.write_bytes(HtmlWrapperClose)
  }
}

///|
fn formatter_write_content(
  formatter : Formatter,
  state : StreamTerminalBridgeState,
  bounds : FormatterSelectionBounds,
  buffer : @buffer.Buffer,
) -> Unit {
  let output = FormatterOutputState::new()
  let mut blank_rows = 0
  let mut blank_cells = 0
  let mut y = bounds.start.y().reinterpret_as_int()
  let end_y = bounds.end_.y().reinterpret_as_int()
  while y <= end_y {
    match state.scrollback.screen_row(state.grid, y.to_uint16()) {
      None => y += 1
      Some(row) =>
        match formatter_row_bounds(state, bounds, y) {
          None => y += 1
          Some(row_bounds) => {
            if formatter_row_is_blank(state, y, row_bounds) {
              blank_rows += 1
              y += 1
              continue
            }

            if blank_rows > 0 {
              output.close(formatter.opts.emit, buffer)
              formatter_write_newlines(formatter.opts.emit, buffer, blank_rows)
              blank_rows = 0
            }

            if !row.wrap() || !formatter.opts.unwrap {
              blank_rows += 1
            }
            if !row.wrap_continuation() || !formatter.opts.unwrap {
              blank_cells = 0
            }

            let mut x = row_bounds.start_x
            while x <= row_bounds.end_x {
              match
                state.scrollback.screen_cell(
                  state.grid,
                  y.to_uint16(),
                  x.to_uint16(),
                ) {
                None => x += 1
                Some(cell) => {
                  match cell.wide() {
                    SpacerHead | SpacerTail => {
                      x += 1
                      continue
                    }
                    Narrow | Wide => ()
                  }

                  if formatter_cell_is_blank(formatter, cell) {
                    blank_cells += 1
                    x += 1
                    continue
                  }

                  if blank_cells > 0 {
                    formatter_write_spaces(buffer, blank_cells)
                    blank_cells = 0
                  }

                  let style = formatter_cell_style(cell)
                  let hyperlink = if formatter.opts.emit == Html {
                    match cell.hyperlink() {
                      Some(link) => Some(link.uri())
                      None => None
                    }
                  } else {
                    None
                  }

                  match formatter.opts.emit {
                    Plain => ()
                    Vt => output.sync_vt_style(style, buffer)
                    Html => output.sync_html_run(style, hyperlink, buffer)
                  }

                  formatter_write_cell_text(formatter.opts.emit, cell, buffer)
                  x += 1
                }
              }
            }

            y += 1
          }
        }
    }
  }

  output.close(formatter.opts.emit, buffer)
}

///|
fn formatter_row_bounds(
  state : StreamTerminalBridgeState,
  bounds : FormatterSelectionBounds,
  row : Int,
) -> FormatterRowBounds? {
  let cols = state.grid.cols.to_int()
  if cols <= 0 {
    return None
  }

  let mut start_x = if bounds.rectangle ||
    row == bounds.start.y().reinterpret_as_int() {
    bounds.start.x().to_int()
  } else {
    0
  }
  let mut end_x = if bounds.rectangle ||
    row == bounds.end_.y().reinterpret_as_int() {
    bounds.end_.x().to_int()
  } else {
    cols - 1
  }

  if start_x < 0 {
    start_x = 0
  }
  if end_x >= cols {
    end_x = cols - 1
  }
  if start_x > end_x {
    return None
  }

  if start_x > 0 {
    match
      state.scrollback.screen_cell(
        state.grid,
        row.to_uint16(),
        start_x.to_uint16(),
      ) {
      Some(cell) =>
        match cell.wide() {
          SpacerTail => start_x -= 1
          SpacerHead => return None
          Narrow | Wide => ()
        }
      None => ()
    }
  }

  Some({ start_x, end_x })
}

///|
fn formatter_row_is_blank(
  state : StreamTerminalBridgeState,
  row : Int,
  bounds : FormatterRowBounds,
) -> Bool {
  let mut x = bounds.start_x
  while x <= bounds.end_x {
    match
      state.scrollback.screen_cell(state.grid, row.to_uint16(), x.to_uint16()) {
      Some(cell) => if cell.has_text() { return false }
      None => ()
    }
    x += 1
  }
  true
}

///|
fn formatter_cell_is_blank(formatter : Formatter, cell : PageCellState) -> Bool {
  if formatter.opts.emit != Plain && (!cell.is_empty() || cell.has_styling()) {
    return false
  }
  if !cell.has_text() {
    return true
  }
  // A space carrying combining marks is a real grapheme, not blank padding.
  formatter.opts.trim &&
  cell.codepoint() == b' '.to_uint() &&
  !cell.has_grapheme()
}

///|
fn formatter_history_cell_is_blank(cell : PageCellState) -> Bool {
  if !cell.is_empty() || cell.has_styling() {
    return false
  }
  if !cell.has_text() {
    return true
  }
  // A space carrying combining marks is a real grapheme, not blank padding.
  cell.codepoint() == b' '.to_uint() && !cell.has_grapheme()
}

///|
fn formatter_cell_style(cell : PageCellState) -> CellStyle {
  match cell.content() {
    Codepoint(_) | CodepointGrapheme(_, _) => cell.style()
    BackgroundPalette(index) => {
      let style = CellStyle::new()
      style.set_bg_color(StyleColor::palette(index))
      style
    }
    BackgroundRgb(rgb) => {
      let style = CellStyle::new()
      style.set_bg_color(StyleColor::rgb(rgb))
      style
    }
  }
}

///|
fn formatter_write_cell_text(
  emit : Format,
  cell : PageCellState,
  buffer : @buffer.Buffer,
) -> Unit {
  if !cell.has_text() {
    buffer.write_byte(b' ')
    return
  }

  formatter_write_codepoint(emit, buffer, cell.codepoint())
  // Emit combining marks so graphemes (é, 👍🏽, ZWJ sequences) survive
  // copy/format and VT-framebuffer serialization.
  for cp in cell.grapheme_codepoints() {
    formatter_write_codepoint(emit, buffer, cp)
  }
}

///|
fn formatter_write_codepoint(
  emit : Format,
  buffer : @buffer.Buffer,
  codepoint : UInt,
) -> Unit {
  match emit {
    Plain | Vt =>
      buffer.write_char_utf8(codepoint.reinterpret_as_int().unsafe_to_char())
    Html =>
      if codepoint == b'<'.to_uint() {
        buffer.write_bytes(b"&lt;")
      } else if codepoint == b'>'.to_uint() {
        buffer.write_bytes(b"&gt;")
      } else if codepoint == b'&'.to_uint() {
        buffer.write_bytes(b"&amp;")
      } else if codepoint == b'"'.to_uint() {
        buffer.write_bytes(b"&quot;")
      } else if codepoint == b'\''.to_uint() {
        buffer.write_bytes(b"&#39;")
      } else if codepoint < 0x80U {
        buffer.write_byte(codepoint.to_byte())
      } else {
        buffer.write_bytes(b"&#")
        @ascii.write_uint_ascii(buffer, codepoint.to_uint64())
        buffer.write_byte(b';')
      }
  }
}

///|
fn formatter_write_spaces(buffer : @buffer.Buffer, count : Int) -> Unit {
  let mut remaining = count
  while remaining > 0 {
    buffer.write_byte(b' ')
    remaining -= 1
  }
}

///|
fn formatter_write_newlines(
  emit : Format,
  buffer : @buffer.Buffer,
  count : Int,
) -> Unit {
  let sequence = match emit {
    Plain => NewlinePlain
    Vt => NewlineVt
    Html => NewlineHtml
  }

  let mut remaining = count
  while remaining > 0 {
    buffer.write_bytes(sequence)
    remaining -= 1
  }
}

///|
fn formatter_write_palette(
  emit : Format,
  palette : Array[@color.RGB],
  buffer : @buffer.Buffer,
) -> Unit {
  match emit {
    Plain => ()
    Vt => {
      let mut i = 0
      while i < palette.length() {
        let rgb = palette[i]
        buffer.write_bytes(b"\x1B]4;")
        @ascii.write_uint_ascii(buffer, i.to_uint64())
        buffer.write_bytes(b";rgb:")
        write_hex_byte(buffer, rgb.r())
        buffer.write_byte(b'/')
        write_hex_byte(buffer, rgb.g())
        buffer.write_byte(b'/')
        write_hex_byte(buffer, rgb.b())
        buffer.write_bytes(b"\x1B\\")
        i += 1
      }
    }
    Html => {
      buffer.write_bytes(b"<style>:root{")
      let mut i = 0
      while i < palette.length() {
        let rgb = palette[i]
        buffer.write_bytes(b"--vt-palette-")
        @ascii.write_uint_ascii(buffer, i.to_uint64())
        buffer.write_bytes(b": #")
        write_hex_byte(buffer, rgb.r())
        write_hex_byte(buffer, rgb.g())
        write_hex_byte(buffer, rgb.b())
        buffer.write_byte(b';')
        i += 1
      }
      buffer.write_bytes(b"}</style>")
    }
  }
}

///|
fn formatter_write_terminal_extras(
  formatter : Formatter,
  state : StreamTerminalBridgeState,
  buffer : @buffer.Buffer,
) -> Unit {
  if formatter.opts.extra.modes {
    let defaults = ModePacked::default()
    for mode in formatter_all_modes() {
      let current = state.modes.get(mode)
      let default_ = defaults.get(mode)
      if current != default_ {
        let tag = mode.tag()
        buffer.write_bytes(b"\x1B[")
        if !tag.ansi() {
          buffer.write_byte(b'?')
        }
        @ascii.write_uint_ascii(buffer, tag.value().to_uint64())
        buffer.write_byte(if current { b'h' } else { b'l' })
      }
    }
  }

  if formatter.opts.extra.scrolling_region {
    if state.cursor.top_margin() != 0 ||
      state.cursor.bottom_margin() != state.grid.rows - 1 {
      buffer.write_bytes(b"\x1B[")
      @ascii.write_uint_ascii(
        buffer,
        (state.cursor.top_margin() + 1).to_uint64(),
      )
      buffer.write_byte(b';')
      @ascii.write_uint_ascii(
        buffer,
        (state.cursor.bottom_margin() + 1).to_uint64(),
      )
      buffer.write_byte(b'r')
    }
    if state.cursor.left_margin() != 0 ||
      state.cursor.right_margin() != state.grid.cols - 1 {
      buffer.write_bytes(b"\x1B[")
      @ascii.write_uint_ascii(
        buffer,
        (state.cursor.left_margin() + 1).to_uint64(),
      )
      buffer.write_byte(b';')
      @ascii.write_uint_ascii(
        buffer,
        (state.cursor.right_margin() + 1).to_uint64(),
      )
      buffer.write_byte(b's')
    }
  }

  if formatter.opts.extra.tabstops {
    buffer.write_bytes(b"\x1B[3g")
    let mut col = 0
    while col < state.grid.cols.to_int() {
      if state.tabstops.get(col.to_uint16()) {
        buffer.write_bytes(b"\x1B[")
        @ascii.write_uint_ascii(buffer, (col + 1).to_uint64())
        buffer.write_bytes(b"G\x1BH")
      }
      col += 1
    }
  }

  if formatter.opts.extra.keyboard && state.input_flags.modify_other_keys_2() {
    buffer.write_bytes(b"\x1B[>4;2m")
  }

  if formatter.opts.extra.pwd {
    match state.metadata.pwd() {
      Some(pwd) =>
        if pwd != "" {
          buffer.write_bytes(b"\x1B]7;")
          buffer.write_string_utf8(pwd)
          buffer.write_bytes(b"\x1B\\")
        }
      None => ()
    }
  }

  formatter_write_screen_extras(formatter.opts.extra.screen, state, buffer)
}

///|
fn formatter_write_screen_extras(
  extra : FormatterScreenExtra,
  state : StreamTerminalBridgeState,
  buffer : @buffer.Buffer,
) -> Unit {
  if extra.style && !state.current_style.is_default() {
    formatter_write_vt_style_open(buffer, state.current_style_snapshot())
  }

  if extra.hyperlink {
    match state.hyperlink.uri() {
      Some(uri) => {
        buffer.write_bytes(b"\x1B]8;")
        match state.hyperlink.explicit_id() {
          Some(id) => {
            buffer.write_bytes(b"id=")
            buffer.write_string_utf8(id)
            buffer.write_byte(b';')
          }
          None => buffer.write_byte(b';')
        }
        buffer.write_string_utf8(uri)
        buffer.write_bytes(b"\x1B\\")
      }
      None => ()
    }
  }

  if extra.protection && state.protected_state.cursor_protected() {
    buffer.write_bytes(b"\x1B[1\"q")
  }

  if extra.kitty_keyboard && state.kitty_keyboard.current().0 != 0 {
    buffer.write_bytes(b"\x1B[=")
    @ascii.write_uint_ascii(
      buffer,
      state.kitty_keyboard.current().0.to_uint64(),
    )
    buffer.write_bytes(b";1u")
  }

  if extra.charsets {
    for slot in [@charsets.Slots::G0, G1, G2, G3] {
      let charset = state.charset.charset(slot)
      if charset != Utf8 {
        buffer.write_byte(b'\x1B')
        buffer.write_byte(formatter_charset_designator(slot))
        buffer.write_byte(formatter_charset_final(charset))
      }
    }

    if state.charset.gl() != G0 {
      buffer.write_bytes(
        match state.charset.gl() {
          G0 => b""
          G1 => b"\x0E"
          G2 => b"\x1Bn"
          G3 => b"\x1Bo"
        },
      )
    }

    if state.charset.gr() != G2 {
      buffer.write_bytes(
        match state.charset.gr() {
          G0 => b""
          G1 => b"\x1B~"
          G2 => b""
          G3 => b"\x1B|"
        },
      )
    }
  }

  if extra.cursor {
    buffer.write_bytes(b"\x1B[")
    @ascii.write_uint_ascii(buffer, (state.cursor.y() + 1).to_uint64())
    buffer.write_byte(b';')
    @ascii.write_uint_ascii(buffer, (state.cursor.x() + 1).to_uint64())
    buffer.write_byte(b'H')
  }
}

///|
fn formatter_write_vt_cup(
  buffer : @buffer.Buffer,
  row : UInt64,
  column : UInt64,
) -> Unit {
  buffer.write_bytes(b"\x1B[")
  @ascii.write_uint_ascii(buffer, row)
  buffer.write_byte(b';')
  @ascii.write_uint_ascii(buffer, column)
  buffer.write_byte(b'H')
}

///|
fn FormatterOutputState::sync_vt_style(
  self : FormatterOutputState,
  next_style : CellStyle,
  buffer : @buffer.Buffer,
) -> Unit {
  if self.vt_style == next_style {
    return
  }

  if next_style.is_default() {
    if !self.vt_style.is_default() {
      buffer.write_bytes(VtStyleReset)
    }
  } else {
    formatter_write_vt_style_open(buffer, next_style)
  }

  self.vt_style = next_style.clone()
}

///|
fn FormatterOutputState::sync_html_run(
  self : FormatterOutputState,
  next_style : CellStyle,
  next_hyperlink : String?,
  buffer : @buffer.Buffer,
) -> Unit {
  if self.html_open &&
    self.html_style == next_style &&
    self.html_hyperlink == next_hyperlink {
    return
  }

  if self.html_open {
    formatter_close_html_run(buffer, self.html_style, self.html_hyperlink)
    self.html_open = false
    self.html_style = CellStyle::new()
    self.html_hyperlink = None
  }

  if next_style.is_default() && next_hyperlink == None {
    return
  }

  formatter_open_html_run(buffer, next_style, next_hyperlink)
  self.html_open = true
  self.html_style = next_style.clone()
  self.html_hyperlink = next_hyperlink
}

///|
fn FormatterOutputState::close(
  self : FormatterOutputState,
  emit : Format,
  buffer : @buffer.Buffer,
) -> Unit {
  match emit {
    Plain => ()
    Vt =>
      if !self.vt_style.is_default() {
        buffer.write_bytes(VtStyleReset)
        self.vt_style = CellStyle::new()
      }
    Html =>
      if self.html_open {
        formatter_close_html_run(buffer, self.html_style, self.html_hyperlink)
        self.html_open = false
        self.html_style = CellStyle::new()
        self.html_hyperlink = None
      }
  }
}

///|
fn formatter_write_vt_style_open(
  buffer : @buffer.Buffer,
  style : CellStyle,
) -> Unit {
  buffer.write_bytes(VtStyleReset)
  if style.bold() {
    buffer.write_bytes(b"\x1B[1m")
  }
  if style.faint() {
    buffer.write_bytes(b"\x1B[2m")
  }
  if style.italic() {
    buffer.write_bytes(b"\x1B[3m")
  }
  if style.blink() {
    buffer.write_bytes(b"\x1B[5m")
  }
  if style.inverse() {
    buffer.write_bytes(b"\x1B[7m")
  }
  if style.invisible() {
    buffer.write_bytes(b"\x1B[8m")
  }
  if style.strikethrough() {
    buffer.write_bytes(b"\x1B[9m")
  }
  if style.overline() {
    buffer.write_bytes(b"\x1B[53m")
  }

  match style.underline() {
    None => ()
    Single => buffer.write_bytes(b"\x1B[4m")
    Double => buffer.write_bytes(b"\x1B[4:2m")
    Curly => buffer.write_bytes(b"\x1B[4:3m")
    Dotted => buffer.write_bytes(b"\x1B[4:4m")
    Dashed => buffer.write_bytes(b"\x1B[4:5m")
  }

  formatter_write_vt_style_color(buffer, 38U, style.fg_color())
  formatter_write_vt_style_color(buffer, 48U, style.bg_color())
  formatter_write_vt_style_color(buffer, 58U, style.underline_color())
}

///|
fn formatter_write_vt_style_color(
  buffer : @buffer.Buffer,
  prefix : UInt,
  color : StyleColor,
) -> Unit {
  if color.palette_index() is Some(index) {
    buffer.write_bytes(b"\x1B[")
    @ascii.write_uint_ascii(buffer, prefix.to_uint64())
    buffer.write_bytes(b";5;")
    @ascii.write_uint_ascii(buffer, index.to_uint64())
    buffer.write_byte(b'm')
  } else if color.rgb_value() is Some(rgb) {
    buffer.write_bytes(b"\x1B[")
    @ascii.write_uint_ascii(buffer, prefix.to_uint64())
    buffer.write_bytes(b";2;")
    @ascii.write_uint_ascii(buffer, rgb.r().to_uint64())
    buffer.write_byte(b';')
    @ascii.write_uint_ascii(buffer, rgb.g().to_uint64())
    buffer.write_byte(b';')
    @ascii.write_uint_ascii(buffer, rgb.b().to_uint64())
    buffer.write_byte(b'm')
  }
}

///|
fn formatter_open_html_run(
  buffer : @buffer.Buffer,
  style : CellStyle,
  hyperlink : String?,
) -> Unit {
  match hyperlink {
    Some(uri) => {
      buffer.write_bytes(HtmlHrefOpen)
      formatter_write_html_attribute(buffer, uri)
      buffer.write_bytes(HtmlHrefClose)
    }
    None => ()
  }

  if !style.is_default() {
    buffer.write_bytes(HtmlRunOpenPrefix)
    formatter_write_html_style(buffer, style)
    buffer.write_bytes(HtmlHrefClose)
  }
}

///|
fn formatter_close_html_run(
  buffer : @buffer.Buffer,
  style : CellStyle,
  hyperlink : String?,
) -> Unit {
  if !style.is_default() {
    buffer.write_bytes(HtmlStyleClose)
  }
  match hyperlink {
    Some(_) => buffer.write_bytes(HtmlAnchorClose)
    None => ()
  }
}

///|
fn formatter_write_html_style(
  buffer : @buffer.Buffer,
  style : CellStyle,
) -> Unit {
  formatter_write_html_color(buffer, "color", style.fg_color())
  formatter_write_html_color(buffer, "background-color", style.bg_color())
  formatter_write_html_color(
    buffer,
    "text-decoration-color",
    style.underline_color(),
  )

  let has_line = style.underline() != None ||
    style.strikethrough() ||
    style.overline() ||
    style.blink()
  if has_line {
    buffer.write_bytes(b"text-decoration-line:")
    if style.underline() != None {
      buffer.write_bytes(b" underline")
    }
    if style.strikethrough() {
      buffer.write_bytes(b" line-through")
    }
    if style.overline() {
      buffer.write_bytes(b" overline")
    }
    if style.blink() {
      buffer.write_bytes(b" blink")
    }
    buffer.write_byte(b';')
  }

  match style.underline() {
    None => ()
    Single => buffer.write_bytes(b"text-decoration-style: solid;")
    Double => buffer.write_bytes(b"text-decoration-style: double;")
    Curly => buffer.write_bytes(b"text-decoration-style: wavy;")
    Dotted => buffer.write_bytes(b"text-decoration-style: dotted;")
    Dashed => buffer.write_bytes(b"text-decoration-style: dashed;")
  }

  if style.bold() {
    buffer.write_bytes(b"font-weight: bold;")
  }
  if style.italic() {
    buffer.write_bytes(b"font-style: italic;")
  }
  if style.faint() {
    buffer.write_bytes(b"opacity: 0.5;")
  }
  if style.invisible() {
    buffer.write_bytes(b"visibility: hidden;")
  }
  if style.inverse() {
    buffer.write_bytes(b"filter: invert(100%);")
  }
}

///|
fn formatter_write_html_color(
  buffer : @buffer.Buffer,
  property : String,
  color : StyleColor,
) -> Unit {
  if color.palette_index() is Some(index) {
    buffer.write_string_utf8(property)
    buffer.write_bytes(b": var(--vt-palette-")
    @ascii.write_uint_ascii(buffer, index.to_uint64())
    buffer.write_bytes(b");")
  } else if color.rgb_value() is Some(rgb) {
    buffer.write_string_utf8(property)
    buffer.write_bytes(b": rgb(")
    @ascii.write_uint_ascii(buffer, rgb.r().to_uint64())
    buffer.write_bytes(b", ")
    @ascii.write_uint_ascii(buffer, rgb.g().to_uint64())
    buffer.write_bytes(b", ")
    @ascii.write_uint_ascii(buffer, rgb.b().to_uint64())
    buffer.write_bytes(b");")
  }
}

///|
fn formatter_write_html_attribute(
  buffer : @buffer.Buffer,
  value : String,
) -> Unit {
  for char in value {
    let codepoint = char.to_int().reinterpret_as_uint()
    formatter_write_codepoint(Html, buffer, codepoint)
  }
}

///|
fn formatter_charset_designator(slot : @charsets.Slots) -> Byte {
  match slot {
    G0 => b'('
    G1 => b')'
    G2 => b'*'
    G3 => b'+'
  }
}

///|
fn formatter_charset_final(charset : @charsets.Charset) -> Byte {
  match charset {
    Ascii => b'B'
    British => b'A'
    DecSpecial => b'0'
    Utf8 => b'B'
  }
}

///|
fn formatter_coord_before(lhs : Coordinate, rhs : Coordinate) -> Bool {
  lhs.y() < rhs.y() || (lhs.y() == rhs.y() && lhs.x() < rhs.x())
}

///|
fn min_cell_count(lhs : CellCountInt, rhs : CellCountInt) -> CellCountInt {
  if lhs < rhs {
    lhs
  } else {
    rhs
  }
}

///|
fn max_cell_count(lhs : CellCountInt, rhs : CellCountInt) -> CellCountInt {
  if lhs > rhs {
    lhs
  } else {
    rhs
  }
}

///|
fn min_uint(lhs : UInt, rhs : UInt) -> UInt {
  if lhs < rhs {
    lhs
  } else {
    rhs
  }
}

///|
fn formatter_max_uint(lhs : UInt, rhs : UInt) -> UInt {
  if lhs > rhs {
    lhs
  } else {
    rhs
  }
}

///|
fn formatter_all_modes() -> Array[Mode] {
  [
    DisableKeyboard,
    Insert,
    SendReceiveMode,
    Linefeed,
    CursorKeys,
    Mode132Column,
    SlowScroll,
    ReverseColors,
    Origin,
    Wraparound,
    Autorepeat,
    MouseEventX10,
    CursorBlinking,
    CursorVisible,
    EnableMode3,
    ReverseWrap,
    AltScreenLegacy,
    KeypadKeys,
    BackarrowKeyMode,
    EnableLeftAndRightMargin,
    MouseEventNormal,
    MouseEventButton,
    MouseEventAny,
    FocusEvent,
    MouseFormatUtf8,
    MouseFormatSgr,
    MouseAlternateScroll,
    MouseFormatUrxvt,
    MouseFormatSgrPixels,
    IgnoreKeypadWithNumlock,
    AltEscPrefix,
    AltSendsEscape,
    ReverseWrapExtended,
    AltScreen,
    SaveCursor,
    AltScreenSaveCursorClearEnter,
    BracketedPaste,
    SynchronizedOutput,
    GraphemeCluster,
    ReportColorScheme,
    InBandSizeReports,
  ]
}

///|
fn write_hex_byte(buffer : @buffer.Buffer, value : Byte) -> Unit {
  let high = (value >> 4).to_int()
  let low = (value & 0xF).to_int()
  buffer.write_byte(@ascii.hex_digit_upper(high))
  buffer.write_byte(@ascii.hex_digit_upper(low))
}
