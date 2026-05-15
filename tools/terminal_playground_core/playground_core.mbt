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
priv struct PlaygroundLog {
  mut bell_count : Int
  mut title_change_count : Int
  pty : @buffer.Buffer
}

///|
fn PlaygroundLog::new() -> PlaygroundLog {
  { bell_count: 0, title_change_count: 0, pty: @buffer.new() }
}

///|
fn PlaygroundLog::clear(self : PlaygroundLog) -> Unit {
  self.bell_count = 0
  self.title_change_count = 0
  self.pty.reset()
}

///|
fn PlaygroundLog::write_pty(self : PlaygroundLog, data : Bytes) -> Unit {
  self.pty.write_bytes(data)
}

///|
fn PlaygroundLog::ring(self : PlaygroundLog) -> Unit {
  self.bell_count += 1
}

///|
fn PlaygroundLog::title_changed(self : PlaygroundLog) -> Unit {
  self.title_change_count += 1
}

///|
fn PlaygroundLog::pty_text(self : PlaygroundLog) -> String {
  @utf8.decode_lossy(self.pty.contents()[:])
}

///|
priv struct PlaygroundSession {
  terminal : @terminal.StreamTerminal
  log : PlaygroundLog
}

///|
fn PlaygroundSession::new() -> PlaygroundSession {
  let log = PlaygroundLog::new()
  let terminal = @terminal.StreamTerminal::new(
    write_pty=fn(data) { log.write_pty(data) },
    bell=fn() { log.ring() },
    title_changed=fn() { log.title_changed() },
    xtversion=fn() { "ghostty-moonbit-playground" },
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
  terminal.set_enquiry(fn() { bytes_from_string("ghostty-playground") })
  { terminal, log }
}

///|
fn PlaygroundSession::deinit(self : PlaygroundSession) -> Unit {
  self.terminal.deinit()
}

///|
fn PlaygroundSession::full_reset(self : PlaygroundSession) -> Unit {
  self.terminal.reset()
  self.log.clear()
}

///|
let sessions : Array[PlaygroundSession?] = []

///|
pub fn playground_new(columns : Int, rows : Int) -> Int {
  let session = PlaygroundSession::new()
  ignore(
    session.terminal.resize(
      clamp_columns(columns),
      clamp_rows(rows),
      DefaultCellWidthPx,
      DefaultCellHeightPx,
    ),
  )
  store_session(session)
}

///|
pub fn playground_free(handle : Int) -> Unit {
  match session_index(handle) {
    Some(index) =>
      match sessions.get(index) {
        Some(Some(session)) => {
          session.deinit()
          sessions[index] = None
        }
        _ => ()
      }
    None => ()
  }
}

///|
pub fn playground_reset(handle : Int) -> Unit {
  match session(handle) {
    Some(session) => session.full_reset()
    None => ()
  }
}

///|
pub fn playground_resize(handle : Int, columns : Int, rows : Int) -> Int {
  match session(handle) {
    Some(session) =>
      session.terminal
      .resize(
        clamp_columns(columns),
        clamp_rows(rows),
        DefaultCellWidthPx,
        DefaultCellHeightPx,
      )
      .code()
    None => @terminal.TerminalResultCode::InvalidValue.code()
  }
}

///|
pub fn playground_apply_text(handle : Int, input : String) -> Unit {
  match session(handle) {
    Some(session) => session.terminal.next_slice(bytes_from_string(input))
    None => ()
  }
}

///|
pub fn playground_scroll_delta(handle : Int, delta : Int) -> Unit {
  match session(handle) {
    Some(session) => session.terminal.scroll_viewport_delta(delta)
    None => ()
  }
}

///|
pub fn playground_render_html(handle : Int) -> String {
  with_session_string(handle, fn(session) {
    formatted_terminal(session.terminal, @terminal.Format::Html)
  })
}

///|
pub fn playground_render_plain(handle : Int) -> String {
  with_session_string(handle, fn(session) {
    formatted_terminal(session.terminal, @terminal.Format::Plain)
  })
}

///|
pub fn playground_render_vt(handle : Int) -> String {
  with_session_string(handle, fn(session) {
    formatted_terminal(session.terminal, @terminal.Format::Vt)
  })
}

///|
pub fn playground_state_json(handle : Int) -> String {
  with_session_string(handle, fn(session) {
    let scrollbar = session.terminal.scrollbar()
    let value : Json = {
      "rows": session.terminal.rows().to_int(),
      "columns": session.terminal.columns().to_int(),
      "widthPx": uint_to_int(session.terminal.width_px()),
      "heightPx": uint_to_int(session.terminal.height_px()),
      "cursorX": session.terminal.cursor_x().to_int(),
      "cursorY": session.terminal.cursor_y().to_int(),
      "cursorStyle": cursor_visual_style_json(
        session.terminal.cursor_visual_style(),
      ),
      "cursorVisible": session.terminal.cursor_visible(),
      "cursorPendingWrap": session.terminal.cursor_pending_wrap(),
      "activeScreen": terminal_screen_json(session.terminal.active_screen()),
      "title": json_string_or_null(session.terminal.title()),
      "pwd": json_string_or_null(session.terminal.pwd()),
      "mouseTracking": session.terminal.mouse_tracking(),
      "paletteDirty": session.terminal.palette_dirty(),
      "scrollbackRows": uint_to_int(session.terminal.scrollback_rows()),
      "totalRows": uint_to_int(session.terminal.total_rows()),
      "scrollbar": {
        "total": uint_to_int(scrollbar.total()),
        "len": uint_to_int(scrollbar.len()),
        "offset": uint_to_int(scrollbar.offset()),
      },
      "foreground": json_rgb(session.terminal.foreground_color()),
      "background": json_rgb(session.terminal.background_color()),
      "cursorColor": json_rgb(session.terminal.cursor_color()),
      "defaultForeground": json_rgb(session.terminal.default_foreground_color()),
      "defaultBackground": json_rgb(session.terminal.default_background_color()),
      "defaultCursor": json_rgb(session.terminal.default_cursor_color()),
      "bellCount": session.log.bell_count,
      "titleChangeCount": session.log.title_change_count,
      "ptyLength": session.log.pty.length(),
    }
    value.stringify()
  })
}

///|
pub fn playground_cell_json(handle : Int, row : Int, col : Int) -> String {
  with_session_string(handle, fn(session) {
    if row < 0 || col < 0 {
      return Json::null().stringify()
    }
    let row_u16 = row.to_uint16()
    let col_u16 = col.to_uint16()
    let value : Json = {
      "row": row,
      "column": col,
      "rowState": json_row_state(session.terminal.screen_row_snapshot(row_u16)),
      "cell": json_cell_state(
        session.terminal.screen_cell_snapshot(row_u16, col_u16),
      ),
    }
    value.stringify()
  })
}

///|
pub fn playground_kitty_json(handle : Int) -> String {
  with_session_string(handle, fn(session) {
    let graphics = session.terminal.kitty_graphics()
    let placements : Array[Json] = []
    let iter = graphics.placement_iterator()
    while iter.next() is Some(placement) {
      placements.push(json_kitty_placement(session.terminal, placement))
    }
    let value : Json = {
      "imageStorageLimit": uint_to_int(graphics.image_storage_limit()),
      "supportsFileMedium": graphics.supports_file_medium(),
      "supportsSharedMemoryMedium": graphics.supports_shared_memory_medium(),
      "supportsTemporaryFileMedium": graphics.supports_temporary_file_medium(),
      "placements": placements,
      "count": placements.length(),
    }
    value.stringify()
  })
}

///|
pub fn playground_pty_output(handle : Int) -> String {
  with_session_string(handle, fn(session) { session.log.pty_text() })
}

///|
pub fn playground_clear_pty_output(handle : Int) -> Unit {
  match session(handle) {
    Some(session) => session.log.pty.reset()
    None => ()
  }
}

///|
fn session(handle : Int) -> PlaygroundSession? {
  match session_index(handle) {
    Some(index) =>
      match sessions.get(index) {
        Some(Some(session)) => Some(session)
        _ => None
      }
    None => None
  }
}

///|
fn session_index(handle : Int) -> Int? {
  if handle <= 0 {
    return None
  }
  let index = handle - 1
  if index < 0 || index >= sessions.length() {
    None
  } else {
    Some(index)
  }
}

///|
fn store_session(session : PlaygroundSession) -> Int {
  for index in 0..<sessions.length() {
    if sessions[index] is None {
      sessions[index] = Some(session)
      return index + 1
    }
  }
  sessions.push(Some(session))
  sessions.length()
}

///|
fn clamp_columns(columns : Int) -> UInt16 {
  clamp_int(columns, MinColumns, MaxColumns).to_uint16()
}

///|
fn clamp_rows(rows : Int) -> UInt16 {
  clamp_int(rows, MinRows, MaxRows).to_uint16()
}

///|
fn clamp_int(value : Int, lower : Int, upper : Int) -> Int {
  if value < lower {
    lower
  } else if value > upper {
    upper
  } else {
    value
  }
}

///|
fn with_session_string(
  handle : Int,
  f : (PlaygroundSession) -> String,
) -> String {
  match session(handle) {
    Some(session) => f(session)
    None => invalid_handle_json(handle)
  }
}

///|
fn invalid_handle_json(handle : Int) -> String {
  let value : Json = { "error": "invalid handle", "handle": handle }
  value.stringify()
}

///|
fn formatted_terminal(
  terminal : @terminal.StreamTerminal,
  format : @terminal.Format,
) -> String {
  let formatter = @terminal.Formatter::new_terminal(
    terminal,
    @terminal.FormatterOptions::new(
      format,
      trim=false,
      extra=@terminal.FormatterTerminalExtra::new(
        palette=true,
        screen=@terminal.FormatterScreenExtra::new(
          cursor=true,
          style=true,
          hyperlink=true,
        ),
      ),
    ),
  )
  @utf8.decode_lossy(formatter.format()[:])
}

///|
fn bytes_from_string(value : String) -> Bytes {
  let buffer = @buffer.new(size_hint=value.length())
  buffer.write_string_utf8(value)
  buffer.contents()
}

///|
fn uint_to_int(value : UInt) -> Int {
  value.reinterpret_as_int()
}

///|
fn json_string_or_null(value : String?) -> Json {
  match value {
    Some(text) => Json::string(text)
    None => Json::null()
  }
}

///|
fn json_rgb(value : @terminal.RGB?) -> Json {
  match value {
    Some(rgb) =>
      { "r": rgb.r().to_int(), "g": rgb.g().to_int(), "b": rgb.b().to_int() }
    None => Json::null()
  }
}

///|
fn json_style_color(value : @terminal.StyleColor) -> Json {
  match (value.palette_index(), value.rgb_value()) {
    (_, Some(rgb)) => { "kind": "rgb", "rgb": json_rgb(Some(rgb)) }
    (Some(index), None) => { "kind": "palette", "index": index.to_int() }
    _ => { "kind": "default" }
  }
}

///|
fn cursor_visual_style_json(value : @terminal.CursorVisualStyle) -> Json {
  Json::string(
    match value {
      Block => "block"
      Bar => "bar"
      Underline => "underline"
    },
  )
}

///|
fn terminal_screen_json(value : @terminal.TerminalScreen) -> Json {
  Json::string(
    match value {
      Primary => "primary"
      Alternate => "alternate"
    },
  )
}

///|
fn row_prompt_json(value : @terminal.RowSemanticPrompt) -> Json {
  Json::string(
    match value {
      None => "none"
      Prompt => "prompt"
      PromptContinuation => "prompt_continuation"
    },
  )
}

///|
fn semantic_content_json(value : @terminal.SemanticContent) -> Json {
  Json::string(
    match value {
      Output => "output"
      Input => "input"
      Prompt => "prompt"
    },
  )
}

///|
fn cell_content_tag_json(value : @terminal.PageCellContentTag) -> Json {
  Json::string(
    match value {
      Codepoint => "codepoint"
      CodepointGrapheme => "codepoint_grapheme"
      BackgroundPalette => "background_palette"
      BackgroundRgb => "background_rgb"
    },
  )
}

///|
fn page_cell_wide_json(value : @terminal.PageCellWide) -> Json {
  Json::string(
    match value {
      Narrow => "narrow"
      Wide => "wide"
      SpacerTail => "spacer_tail"
      SpacerHead => "spacer_head"
    },
  )
}

///|
fn sgr_underline_json(value : @terminal.SgrUnderline) -> Json {
  Json::string(
    match value {
      None => "none"
      Single => "single"
      Double => "double"
      Curly => "curly"
      Dotted => "dotted"
      Dashed => "dashed"
    },
  )
}

///|
fn json_row_state(row : @terminal.PageRowState?) -> Json {
  match row {
    Some(row) =>
      {
        "dirty": row.dirty(),
        "grapheme": row.grapheme(),
        "hyperlink": row.hyperlink(),
        "kittyVirtualPlaceholder": row.kitty_virtual_placeholder(),
        "managedMemory": row.managed_memory(),
        "styled": row.styled(),
        "wrap": row.wrap(),
        "wrapContinuation": row.wrap_continuation(),
        "semanticPrompt": row_prompt_json(row.semantic_prompt()),
      }
    None => Json::null()
  }
}

///|
fn json_cell_state(cell : @terminal.PageCellState?) -> Json {
  match cell {
    Some(cell) => {
      let style = cell.style()
      {
        "codepoint": uint_to_int(cell.codepoint()),
        "contentTag": cell_content_tag_json(cell.content_tag()),
        "gridWidth": cell.grid_width(),
        "hasGrapheme": cell.has_grapheme(),
        "hasStyling": cell.has_styling(),
        "hasText": cell.has_text(),
        "isEmpty": cell.is_empty(),
        "isProtected": cell.is_protected(),
        "isZero": cell.is_zero(),
        "wide": page_cell_wide_json(cell.wide()),
        "paletteIndex": json_byte_or_null(cell.palette_index()),
        "backgroundRgb": json_rgb(cell.background_rgb()),
        "semanticContent": semantic_content_json(cell.semantic_content()),
        "hyperlink": json_hyperlink(cell.hyperlink()),
        "style": {
          "bold": style.bold(),
          "faint": style.faint(),
          "italic": style.italic(),
          "blink": style.blink(),
          "inverse": style.inverse(),
          "invisible": style.invisible(),
          "overline": style.overline(),
          "strikethrough": style.strikethrough(),
          "underline": sgr_underline_json(style.underline()),
          "foreground": json_style_color(style.fg_color()),
          "background": json_style_color(style.bg_color()),
          "underlineColor": json_style_color(style.underline_color()),
        },
      }
    }
    None => Json::null()
  }
}

///|
fn json_byte_or_null(value : Byte?) -> Json {
  match value {
    Some(byte) => byte.to_int().to_json()
    None => Json::null()
  }
}

///|
fn json_hyperlink(value : @terminal.CellHyperlink?) -> Json {
  match value {
    Some(link) =>
      {
        "uri": link.uri(),
        "explicitId": json_string_or_null(link.explicit_id()),
        "implicitId": json_int_or_null(link.implicit_id()),
      }
    None => Json::null()
  }
}

///|
fn json_int_or_null(value : Int?) -> Json {
  match value {
    Some(number) => number.to_json()
    None => Json::null()
  }
}

///|
fn json_coordinate(value : @terminal.Coordinate?) -> Json {
  match value {
    Some(coord) => { "x": coord.x().to_int(), "y": uint_to_int(coord.y()) }
    None => Json::null()
  }
}

///|
fn json_selection_rect(
  terminal : @terminal.StreamTerminal,
  value : @terminal.Selection?,
) -> Json {
  match value {
    Some(selection) => {
      let start = terminal.point_from_pin(
        selection.start(),
        @terminal.Tag::Screen,
      )
      let end_ = terminal.point_from_pin(selection.end(), @terminal.Tag::Screen)
      {
        "rectangle": selection.rectangle(),
        "start": json_coordinate(start),
        "end": json_coordinate(end_),
      }
    }
    None => Json::null()
  }
}

///|
fn json_kitty_placement(
  terminal : @terminal.StreamTerminal,
  placement : @terminal.KittyPlacement,
) -> Json {
  let pixel_size = placement.pixel_size()
  let grid_size = placement.grid_size()
  let source_rect = placement.source_rect()
  let image = placement.image()
  {
    "imageId": uint_to_int(placement.image_id()),
    "placementId": uint_to_int(placement.placement_id()),
    "isVirtual": placement.is_virtual(),
    "columns": uint_to_int(placement.columns()),
    "rows": uint_to_int(placement.rows()),
    "xOffset": uint_to_int(placement.x_offset()),
    "yOffset": uint_to_int(placement.y_offset()),
    "z": placement.z(),
    "viewport": json_viewport_position(placement.viewport_position()),
    "rect": json_selection_rect(terminal, placement.rect()),
    "pixelSize": {
      "width": uint_to_int(pixel_size.width()),
      "height": uint_to_int(pixel_size.height()),
    },
    "gridSize": {
      "cols": uint_to_int(grid_size.cols()),
      "rows": uint_to_int(grid_size.rows()),
    },
    "sourceRect": {
      "x": uint_to_int(source_rect.x()),
      "y": uint_to_int(source_rect.y()),
      "width": uint_to_int(source_rect.width()),
      "height": uint_to_int(source_rect.height()),
    },
    "image": {
      "id": uint_to_int(image.id()),
      "number": uint_to_int(image.number()),
      "width": uint_to_int(image.width()),
      "height": uint_to_int(image.height()),
      "format": kitty_image_format_json(image.format()),
      "compression": kitty_image_compression_json(image.compression()),
      "dataBase64": @base64.encode(image.data()[:]),
    },
  }
}

///|
fn json_viewport_position(
  value : @terminal.KittyPlacementViewportPosition?,
) -> Json {
  match value {
    Some(position) => { "row": position.row(), "col": position.col() }
    None => Json::null()
  }
}

///|
fn kitty_image_format_json(value : @terminal.KittyGraphicsFormat) -> Json {
  Json::string(
    match value {
      Rgb => "rgb"
      Rgba => "rgba"
      Png => "png"
    },
  )
}

///|
fn kitty_image_compression_json(
  value : @terminal.KittyGraphicsCompression,
) -> Json {
  Json::string(
    match value {
      None => "none"
      ZlibDeflate => "zlib_deflate"
    },
  )
}
