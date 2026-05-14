///|
pub(all) enum RenderDirty {
  False
  Partial
  Full
} derive(Eq)

///|
struct RenderState {
  mut initialized : Bool
  mut rows : CellCountInt
  mut columns : CellCountInt
  mut dirty : RenderDirty
  mut screen : TerminalScreen
  mut viewport_origin : Coordinate?
  mut background : RGB
  mut foreground : RGB
  mut cursor_color : RGB?
  mut palette : Array[RGB]
  mut cursor_visual_style : CursorVisualStyle
  mut cursor_visible : Bool
  mut cursor_blinking : Bool
  mut cursor_password_input : Bool
  mut cursor_viewport : Coordinate?
  mut cursor_viewport_wide_tail : Bool
  mut row_states : Array[PageRowState]
  mut row_cells : Array[Array[PageCellState]]
}

///|
pub fn RenderState::new() -> RenderState {
  {
    initialized: false,
    rows: 0,
    columns: 0,
    dirty: RenderDirty::False,
    screen: TerminalScreen::Primary,
    viewport_origin: None,
    background: default_render_background(),
    foreground: default_render_foreground(),
    cursor_color: None,
    palette: clone_render_palette(default_palette()),
    cursor_visual_style: CursorVisualStyle::Block,
    cursor_visible: true,
    cursor_blinking: false,
    cursor_password_input: false,
    cursor_viewport: None,
    cursor_viewport_wide_tail: false,
    row_states: [],
    row_cells: [],
  }
}

///|
pub fn RenderState::rows(self : RenderState) -> CellCountInt {
  self.rows
}

///|
pub fn RenderState::columns(self : RenderState) -> CellCountInt {
  self.columns
}

///|
pub fn RenderState::dirty(self : RenderState) -> RenderDirty {
  self.dirty
}

///|
pub fn RenderState::set_dirty(self : RenderState, dirty : RenderDirty) -> Unit {
  self.dirty = dirty
}

///|
pub fn RenderState::background_color(self : RenderState) -> RGB {
  self.background
}

///|
pub fn RenderState::foreground_color(self : RenderState) -> RGB {
  self.foreground
}

///|
pub fn RenderState::cursor_color(self : RenderState) -> RGB? {
  self.cursor_color
}

///|
pub fn RenderState::palette(self : RenderState) -> Array[RGB] {
  clone_render_palette(self.palette)
}

///|
pub fn RenderState::cursor_visual_style(
  self : RenderState,
) -> CursorVisualStyle {
  self.cursor_visual_style
}

///|
pub fn RenderState::cursor_visible(self : RenderState) -> Bool {
  self.cursor_visible
}

///|
pub fn RenderState::cursor_blinking(self : RenderState) -> Bool {
  self.cursor_blinking
}

///|
pub fn RenderState::cursor_password_input(self : RenderState) -> Bool {
  self.cursor_password_input
}

///|
pub fn RenderState::cursor_viewport(self : RenderState) -> Coordinate? {
  self.cursor_viewport
}

///|
pub fn RenderState::cursor_viewport_wide_tail(self : RenderState) -> Bool {
  self.cursor_viewport_wide_tail
}

///|
pub fn RenderState::update(
  self : RenderState,
  terminal : StreamTerminal,
) -> Unit {
  let rows = terminal.rows()
  let columns = terminal.columns()
  let screen = terminal.active_screen()
  let viewport_origin = resolve_viewport_origin(terminal, rows, columns)
  let reverse_colors = terminal.mode_get(Mode::ReverseColors)
  let background = resolved_render_background(terminal, reverse_colors)
  let foreground = resolved_render_foreground(terminal, reverse_colors)
  let cursor_color = terminal.cursor_color()
  let palette = terminal.palette()
  let cursor_visual_style = terminal.cursor_visual_style()
  let cursor_visible = terminal.cursor_visible()
  let cursor_blinking = terminal.mode_get(Mode::CursorBlinking)
  let cursor_password_input = false
  let (cursor_viewport, cursor_viewport_wide_tail) = resolve_cursor_viewport(
    terminal,
  )

  let full_dirty = !self.initialized ||
    self.rows != rows ||
    self.columns != columns ||
    self.screen != screen ||
    self.viewport_origin != viewport_origin ||
    self.background != background ||
    self.foreground != foreground ||
    !render_palette_equals(self.palette, palette) ||
    !render_row_storage_matches(self, rows, columns)

  let cursor_dirty = self.cursor_color != cursor_color ||
    self.cursor_visual_style != cursor_visual_style ||
    self.cursor_visible != cursor_visible ||
    self.cursor_blinking != cursor_blinking ||
    self.cursor_password_input != cursor_password_input ||
    self.cursor_viewport != cursor_viewport ||
    self.cursor_viewport_wide_tail != cursor_viewport_wide_tail

  let any_row_dirty = if full_dirty {
    self.snapshot_all_rows(terminal, rows, columns)
    self.row_states.length() > 0
  } else {
    self.update_changed_rows(terminal, rows, columns)
  }

  if full_dirty {
    self.dirty = RenderDirty::Full
  } else if (any_row_dirty || cursor_dirty) && self.dirty == RenderDirty::False {
    self.dirty = RenderDirty::Partial
  }

  self.initialized = true
  self.rows = rows
  self.columns = columns
  self.screen = screen
  self.viewport_origin = viewport_origin
  self.background = background
  self.foreground = foreground
  self.cursor_color = cursor_color
  self.palette = clone_render_palette(palette)
  self.cursor_visual_style = cursor_visual_style
  self.cursor_visible = cursor_visible
  self.cursor_blinking = cursor_blinking
  self.cursor_password_input = cursor_password_input
  self.cursor_viewport = cursor_viewport
  self.cursor_viewport_wide_tail = cursor_viewport_wide_tail
}

///|
fn RenderState::snapshot_all_rows(
  self : RenderState,
  terminal : StreamTerminal,
  rows : CellCountInt,
  columns : CellCountInt,
) -> Unit {
  let row_states : Array[PageRowState] = []
  let row_cells : Array[Array[PageCellState]] = []
  let mut row_idx = 0
  while row_idx < rows.to_int() {
    let snapshot = snapshot_render_row(terminal, row_idx.to_uint16())
    snapshot.set_dirty(true)
    row_states.push(snapshot)
    row_cells.push(
      snapshot_render_cells(terminal, row_idx.to_uint16(), columns),
    )
    row_idx += 1
  }
  self.row_states = row_states
  self.row_cells = row_cells
}

///|
fn RenderState::update_changed_rows(
  self : RenderState,
  terminal : StreamTerminal,
  rows : CellCountInt,
  columns : CellCountInt,
) -> Bool {
  let mut any_row_dirty = false
  let mut row_idx = 0
  while row_idx < rows.to_int() {
    let snapshot = snapshot_render_row(terminal, row_idx.to_uint16())
    let cells = snapshot_render_cells(terminal, row_idx.to_uint16(), columns)
    if !render_row_snapshot_equals(self.row_states[row_idx], snapshot) ||
      !render_row_cells_equal(self.row_cells[row_idx], cells) {
      snapshot.set_dirty(true)
      self.row_states[row_idx] = snapshot
      self.row_cells[row_idx] = cells
      any_row_dirty = true
    }
    row_idx += 1
  }
  any_row_dirty
}

///|
fn resolve_viewport_origin(
  terminal : StreamTerminal,
  rows : CellCountInt,
  columns : CellCountInt,
) -> Coordinate? {
  if rows == 0 || columns == 0 {
    None
  } else {
    terminal
    .bridge()
    .point_from_point(Point::Viewport(Coordinate::new(0, 0U)), Tag::Screen)
  }
}

///|
fn resolved_render_background(
  terminal : StreamTerminal,
  reverse_colors : Bool,
) -> RGB {
  let background = resolve_terminal_background(terminal)
  let foreground = resolve_terminal_foreground(terminal)
  if reverse_colors {
    foreground
  } else {
    background
  }
}

///|
fn resolved_render_foreground(
  terminal : StreamTerminal,
  reverse_colors : Bool,
) -> RGB {
  let background = resolve_terminal_background(terminal)
  let foreground = resolve_terminal_foreground(terminal)
  if reverse_colors {
    background
  } else {
    foreground
  }
}

///|
fn resolve_cursor_viewport(terminal : StreamTerminal) -> (Coordinate?, Bool) {
  let cursor_point = Point::Active(
    Coordinate::new(terminal.cursor_x(), terminal.cursor_y().to_uint()),
  )
  let state = terminal.bridge()
  match state.point_from_point(cursor_point, Tag::Viewport) {
    Some(viewport) => {
      let wide_tail = match state.cell_at_point(cursor_point) {
        Some(cell) => cell.wide() == PageCellWide::SpacerTail
        None => false
      }
      (Some(viewport), wide_tail)
    }
    None => (None, false)
  }
}

///|
fn render_row_storage_matches(
  state : RenderState,
  rows : CellCountInt,
  columns : CellCountInt,
) -> Bool {
  if state.row_states.length() != rows.to_int() ||
    state.row_cells.length() != rows.to_int() {
    return false
  }

  let mut row_idx = 0
  while row_idx < state.row_cells.length() {
    if state.row_cells[row_idx].length() != columns.to_int() {
      return false
    }
    row_idx += 1
  }
  true
}

///|
fn snapshot_render_row(
  terminal : StreamTerminal,
  row : CellCountInt,
) -> PageRowState {
  match terminal.screen_row_snapshot(row) {
    Some(snapshot) => snapshot
    None => PageRowState::new()
  }
}

///|
fn snapshot_render_cells(
  terminal : StreamTerminal,
  row : CellCountInt,
  columns : CellCountInt,
) -> Array[PageCellState] {
  let result : Array[PageCellState] = []
  let mut col_idx = 0
  while col_idx < columns.to_int() {
    let col = col_idx.to_uint16()
    result.push(
      match terminal.screen_cell_snapshot(row, col) {
        Some(snapshot) => snapshot
        None => PageCellState::new()
      },
    )
    col_idx += 1
  }
  result
}

///|
fn render_row_snapshot_equals(
  left : PageRowState,
  right : PageRowState,
) -> Bool {
  left.wrap == right.wrap &&
  left.wrap_continuation == right.wrap_continuation &&
  left.grapheme == right.grapheme &&
  left.styled == right.styled &&
  left.hyperlink == right.hyperlink &&
  left.semantic_prompt == right.semantic_prompt &&
  left.kitty_virtual_placeholder == right.kitty_virtual_placeholder
}

///|
fn render_row_cells_equal(
  left : Array[PageCellState],
  right : Array[PageCellState],
) -> Bool {
  if left.length() != right.length() {
    return false
  }

  let mut index = 0
  while index < left.length() {
    if left[index] != right[index] {
      return false
    }
    index += 1
  }
  true
}

///|
fn render_row_at(state : RenderState, row_idx : Int) -> PageRowState? {
  if row_idx < 0 || row_idx >= state.row_states.length() {
    None
  } else {
    Some(copy_scrollback_row(state.row_states[row_idx]))
  }
}

///|
fn render_row_dirty_at(state : RenderState, row_idx : Int) -> Bool? {
  if row_idx < 0 || row_idx >= state.row_states.length() {
    None
  } else {
    Some(state.row_states[row_idx].dirty())
  }
}

///|
fn render_set_row_dirty_at(
  state : RenderState,
  row_idx : Int,
  value : Bool,
) -> Bool {
  if row_idx < 0 || row_idx >= state.row_states.length() {
    false
  } else {
    state.row_states[row_idx].set_dirty(value)
    true
  }
}

///|
fn render_cell_at(
  state : RenderState,
  row_idx : Int,
  col_idx : Int,
) -> PageCellState? {
  if row_idx < 0 || row_idx >= state.row_cells.length() {
    return None
  }
  if col_idx < 0 || col_idx >= state.row_cells[row_idx].length() {
    return None
  }
  Some(copy_scrollback_cell(state.row_cells[row_idx][col_idx]))
}

///|
fn render_cell_background_color_at(
  state : RenderState,
  row_idx : Int,
  col_idx : Int,
) -> RGB? {
  match render_cell_at(state, row_idx, col_idx) {
    Some(cell) => render_cell_background_color(cell, state.palette)
    None => None
  }
}

///|
fn render_cell_foreground_color_at(
  state : RenderState,
  row_idx : Int,
  col_idx : Int,
) -> RGB? {
  match render_cell_at(state, row_idx, col_idx) {
    Some(cell) => render_cell_foreground_color(cell, state.palette)
    None => None
  }
}

///|
fn render_cell_background_color(
  cell : PageCellState,
  palette : Array[RGB],
) -> RGB? {
  match cell.content_tag {
    PageCellContentTag::BackgroundPalette =>
      Some(palette[cell.palette_index.to_int()])
    PageCellContentTag::BackgroundRgb => Some(cell.bg_rgb)
    PageCellContentTag::Codepoint | PageCellContentTag::CodepointGrapheme =>
      style_color_to_rgb(cell.style.bg_color, palette)
  }
}

///|
fn render_cell_foreground_color(
  cell : PageCellState,
  palette : Array[RGB],
) -> RGB? {
  style_color_to_rgb(cell.style.fg_color, palette)
}

///|
fn style_color_to_rgb(color : StyleColor, palette : Array[RGB]) -> RGB? {
  match color {
    None => None
    Palette(index) => Some(palette[index.to_int()])
    Rgb(rgb) => Some(rgb)
  }
}

///|
fn clone_render_palette(source : Array[RGB]) -> Array[RGB] {
  let result : Array[RGB] = []
  for color in source {
    result.push(color)
  }
  result
}

///|
fn render_palette_equals(left : Array[RGB], right : Array[RGB]) -> Bool {
  if left.length() != right.length() {
    return false
  }

  let mut index = 0
  while index < left.length() {
    if left[index] != right[index] {
      return false
    }
    index += 1
  }
  true
}

///|
fn resolve_terminal_background(terminal : StreamTerminal) -> RGB {
  match terminal.background_color() {
    Some(color) => color
    None =>
      match terminal.default_background_color() {
        Some(color) => color
        None => default_render_background()
      }
  }
}

///|
fn resolve_terminal_foreground(terminal : StreamTerminal) -> RGB {
  match terminal.foreground_color() {
    Some(color) => color
    None =>
      match terminal.default_foreground_color() {
        Some(color) => color
        None => default_render_foreground()
      }
  }
}

///|
fn default_render_background() -> RGB {
  RGB::new(0, 0, 0)
}

///|
fn default_render_foreground() -> RGB {
  RGB::new(0xFF, 0xFF, 0xFF)
}
