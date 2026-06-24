///|
pub(all) enum RenderDirty {
  False
  Partial
  Full
} derive(Eq)

///|
struct RenderState {
  mut initialized : Bool
  mut rows : @size.CellCountInt
  mut columns : @size.CellCountInt
  mut dirty : RenderDirty
  mut screen : TerminalScreen
  mut viewport_origin : Coordinate?
  mut background : @color.RGB
  mut foreground : @color.RGB
  mut cursor_color : @color.RGB?
  mut palette : Array[@color.RGB]
  mut cursor_visual_style : CursorVisualStyle
  mut cursor_visible : Bool
  mut cursor_blinking : Bool
  mut cursor_password_input : Bool
  mut cursor_viewport : Coordinate?
  mut cursor_viewport_wide_tail : Bool
  mut row_states : Array[@page.PageRowState]
  mut row_cells : Array[FixedArray[@page.PageCellState]]
  // Per-row hyperlink ids, parallel to `row_cells`, captured each snapshot so the
  // damage diff notices a hyperlink-only change: the packed cell carries only a
  // presence bit, so two cells under different URIs are equal and `row_cells`
  // alone would miss it. `None` for a row with no links (the common case → no
  // allocation). The full link still resolves via the terminal-level snapshot.
  mut row_link_ids : Array[FixedArray[@hyperlink.HyperlinkId]?]
  // The active screen's style table, captured each `update`. The snapshotted
  // `row_cells` carry `StyleId`s minted from it, so it resolves their styles for
  // the renderer/formatter. Grow-only and shared, so ids captured here stay valid.
  mut style_table : @style.StyleTable
  // The active screen's grapheme table, captured the same way: the VT-framebuffer
  // formatter resolves each cell's combining marks through it.
  mut grapheme_table : @page.GraphemeTable
  // The active screen's hyperlink table, captured the same way so a snapshot-driven
  // renderer can resolve each cell's uri from `row_link_ids` without reaching back
  // into the live terminal (symmetric with style/grapheme resolution).
  mut hyperlink_table : @hyperlink.HyperlinkTable
}

///|
pub fn RenderState::new() -> RenderState {
  {
    initialized: false,
    rows: 0,
    columns: 0,
    dirty: False,
    screen: Primary,
    viewport_origin: None,
    background: default_render_background(),
    foreground: default_render_foreground(),
    cursor_color: None,
    palette: @color.default_palette(),
    cursor_visual_style: Block,
    cursor_visible: true,
    cursor_blinking: false,
    cursor_password_input: false,
    cursor_viewport: None,
    cursor_viewport_wide_tail: false,
    row_states: [],
    row_cells: [],
    row_link_ids: [],
    style_table: @style.StyleTable::new(),
    grapheme_table: @page.GraphemeTable::new(),
    hyperlink_table: @hyperlink.HyperlinkTable::new(),
  }
}

///|
pub fn RenderState::rows(self : RenderState) -> @size.CellCountInt {
  self.rows
}

///|
pub fn RenderState::columns(self : RenderState) -> @size.CellCountInt {
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
pub fn RenderState::background_color(self : RenderState) -> @color.RGB {
  self.background
}

///|
pub fn RenderState::foreground_color(self : RenderState) -> @color.RGB {
  self.foreground
}

///|
pub fn RenderState::cursor_color(self : RenderState) -> @color.RGB? {
  self.cursor_color
}

///|
pub fn RenderState::palette(self : RenderState) -> Array[@color.RGB] {
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
  let reverse_colors = terminal.mode_get(ReverseColors)
  let background = resolved_render_background(terminal, reverse_colors)
  let foreground = resolved_render_foreground(terminal, reverse_colors)
  let cursor_color = terminal.cursor_color()
  let palette = terminal.palette()
  let cursor_visual_style = terminal.cursor_visual_style()
  let cursor_visible = terminal.cursor_visible()
  let cursor_blinking = terminal.mode_get(CursorBlinking)
  let cursor_password_input = false
  let (cursor_viewport, cursor_viewport_wide_tail) = resolve_cursor_viewport(
    terminal,
  )
  // The snapshot diff compares the *numeric* ids packed in each cell (style,
  // grapheme) plus the raw hyperlink id. Those ids are only stable while the
  // intern tables that mint them are. A full reset (RIS) rebuilds the screen
  // storage, so `PageList::new` mints brand-new tables whose ids restart from the
  // same small values — a redraw of a different glyph/style/link can then reuse an
  // old id and read as unchanged. Treat a change of table identity as full damage.
  // (A primary/alternate switch also swaps tables, but `self.screen` already
  // covers that; tables persist across resize and ordinary printing.)
  let style_table = terminal.active_style_table()
  let grapheme_table = terminal.active_grapheme_table()
  let hyperlink_table = terminal.active_hyperlink_table()
  let full_dirty = !self.initialized ||
    self.rows != rows ||
    self.columns != columns ||
    self.screen != screen ||
    self.viewport_origin != viewport_origin ||
    self.background != background ||
    self.foreground != foreground ||
    !render_palette_equals(self.palette, palette) ||
    !physical_equal(self.style_table, style_table) ||
    !physical_equal(self.grapheme_table, grapheme_table) ||
    !physical_equal(self.hyperlink_table, hyperlink_table) ||
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
    self.dirty = Full
  } else if (any_row_dirty || cursor_dirty) && self.dirty == False {
    self.dirty = Partial
  }

  self.initialized = true
  self.style_table = style_table
  self.grapheme_table = grapheme_table
  self.hyperlink_table = hyperlink_table
  self.rows = rows
  self.columns = columns
  self.screen = screen
  self.viewport_origin = viewport_origin
  self.background = background
  self.foreground = foreground
  self.cursor_color = cursor_color
  // `palette` came from `terminal.palette()`, which already returns a fresh
  // snapshot owned by no one else — store it directly instead of cloning again.
  self.palette = palette
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
  rows : @size.CellCountInt,
  columns : @size.CellCountInt,
) -> Unit {
  let row_states : Array[@page.PageRowState] = []
  let row_cells : Array[FixedArray[@page.PageCellState]] = []
  let row_link_ids : Array[FixedArray[@hyperlink.HyperlinkId]?] = []
  let mut row_idx = 0
  while row_idx < rows.to_int() {
    let snapshot = snapshot_render_row(terminal, row_idx.to_uint16()).with_dirty(
      true,
    )
    let cells = snapshot_render_cells(terminal, row_idx.to_uint16(), columns)
    row_states.push(snapshot)
    row_link_ids.push(
      snapshot_render_link_ids(terminal, row_idx.to_uint16(), cells),
    )
    row_cells.push(cells)
    row_idx += 1
  }
  self.row_states = row_states
  self.row_cells = row_cells
  self.row_link_ids = row_link_ids
}

///|
fn RenderState::update_changed_rows(
  self : RenderState,
  terminal : StreamTerminal,
  rows : @size.CellCountInt,
  columns : @size.CellCountInt,
) -> Bool {
  let mut any_row_dirty = false
  let mut row_idx = 0
  while row_idx < rows.to_int() {
    let snapshot = snapshot_render_row(terminal, row_idx.to_uint16())
    let cells = snapshot_render_cells(terminal, row_idx.to_uint16(), columns)
    let link_ids = snapshot_render_link_ids(
      terminal,
      row_idx.to_uint16(),
      cells,
    )
    if !render_row_snapshot_equals(self.row_states[row_idx], snapshot) ||
      !render_row_cells_equal(self.row_cells[row_idx], cells) ||
      !render_link_ids_equal(self.row_link_ids[row_idx], link_ids) {
      self.row_states[row_idx] = snapshot.with_dirty(true)
      self.row_cells[row_idx] = cells
      self.row_link_ids[row_idx] = link_ids
      any_row_dirty = true
    }
    row_idx += 1
  }
  any_row_dirty
}

///|
fn resolve_viewport_origin(
  terminal : StreamTerminal,
  rows : @size.CellCountInt,
  columns : @size.CellCountInt,
) -> Coordinate? {
  if rows == 0 || columns == 0 {
    None
  } else {
    terminal.bridge().point_from_point(Viewport(Coordinate::new(0, 0U)), Screen)
  }
}

///|
fn resolved_render_background(
  terminal : StreamTerminal,
  reverse_colors : Bool,
) -> @color.RGB {
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
) -> @color.RGB {
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
  match state.point_from_point(cursor_point, Viewport) {
    Some(viewport) => {
      let wide_tail = match state.cell_at_point(cursor_point) {
        Some(cell) => cell.wide() == SpacerTail
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
  rows : @size.CellCountInt,
  columns : @size.CellCountInt,
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
  row : @size.CellCountInt,
) -> @page.PageRowState {
  match terminal.screen_row_snapshot(row) {
    Some(snapshot) => snapshot
    None => @page.PageRowState::new()
  }
}

///|
fn snapshot_render_cells(
  terminal : StreamTerminal,
  row : @size.CellCountInt,
  columns : @size.CellCountInt,
) -> FixedArray[@page.PageCellState] {
  let width = columns.to_int()
  let result : FixedArray[@page.PageCellState] = FixedArray::make(
    width,
    @page.PageCellState::new(),
  )
  for col_idx in 0..<width {
    let col = col_idx.to_uint16()
    result[col_idx] = match terminal.screen_cell_snapshot(row, col) {
      Some(snapshot) => snapshot
      None => @page.PageCellState::new()
    }
  }
  result
}

///|
fn snapshot_render_link_ids(
  terminal : StreamTerminal,
  row : @size.CellCountInt,
  cells : FixedArray[@page.PageCellState],
) -> FixedArray[@hyperlink.HyperlinkId]? {
  // Only a row that actually holds a hyperlinked cell allocates an id array; the
  // common linkless row stays `None`. The id is fetched solely for cells whose
  // presence bit is set (read off the already-snapshotted `cells`), so a
  // link-free frame does no extra lookups.
  let mut links : FixedArray[@hyperlink.HyperlinkId]? = None
  for col_idx in 0..<cells.length() {
    if cells[col_idx].has_hyperlink() {
      let arr = match links {
        Some(arr) => arr
        None => {
          let arr = FixedArray::make(cells.length(), @hyperlink.no_hyperlink_id)
          links = Some(arr)
          arr
        }
      }
      arr[col_idx] = terminal.screen_cell_hyperlink_id_snapshot(
        row,
        col_idx.to_uint16(),
      )
    }
  }
  links
}

///|
fn render_link_ids_equal(
  left : FixedArray[@hyperlink.HyperlinkId]?,
  right : FixedArray[@hyperlink.HyperlinkId]?,
) -> Bool {
  match (left, right) {
    (None, None) => true
    (Some(left), Some(right)) => {
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
    // One row gained or lost all its links (e.g. an unlinked overwrite cleared the
    // row's last presence bit): the side differs, so the row is dirty.
    _ => false
  }
}

///|
fn render_row_snapshot_equals(
  left : @page.PageRowState,
  right : @page.PageRowState,
) -> Bool {
  // Compare every flag *except* `dirty`, which tracks render bookkeeping rather
  // than content.
  left.equals_ignoring_dirty(right)
}

///|
fn render_row_cells_equal(
  left : FixedArray[@page.PageCellState],
  right : FixedArray[@page.PageCellState],
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
fn render_row_at(state : RenderState, row_idx : Int) -> @page.PageRowState? {
  if row_idx < 0 || row_idx >= state.row_states.length() {
    None
  } else {
    Some(state.row_states[row_idx])
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
    state.row_states[row_idx] = state.row_states[row_idx].with_dirty(value)
    true
  }
}

///|
fn render_cell_at(
  state : RenderState,
  row_idx : Int,
  col_idx : Int,
) -> @page.PageCellState? {
  if row_idx < 0 || row_idx >= state.row_cells.length() {
    return None
  }
  if col_idx < 0 || col_idx >= state.row_cells[row_idx].length() {
    return None
  }
  Some(state.row_cells[row_idx][col_idx])
}

///|
// The resolved hyperlink of the snapshot cell at (row, col), or `None` when it
// carries no link. Gated on the cell's presence bit (the snapshot's source of
// truth); the id comes from the parallel `row_link_ids` and resolves through the
// captured `hyperlink_table`, so no live-terminal access is needed.
fn render_cell_hyperlink_at(
  state : RenderState,
  row_idx : Int,
  col_idx : Int,
) -> @hyperlink.CellHyperlink? {
  match render_cell_at(state, row_idx, col_idx) {
    Some(cell) =>
      if cell.has_hyperlink() {
        let id = match state.row_link_ids[row_idx] {
          Some(links) => links[col_idx]
          None => @hyperlink.no_hyperlink_id
        }
        state.hyperlink_table.get(id)
      } else {
        None
      }
    None => None
  }
}

///|
fn render_cell_background_color_at(
  state : RenderState,
  row_idx : Int,
  col_idx : Int,
) -> @color.RGB? {
  match render_cell_at(state, row_idx, col_idx) {
    Some(cell) =>
      render_cell_background_color(
        state.style_table.get(cell.style_id()),
        state.palette,
      )
    None => None
  }
}

///|
fn render_cell_foreground_color_at(
  state : RenderState,
  row_idx : Int,
  col_idx : Int,
) -> @color.RGB? {
  match render_cell_at(state, row_idx, col_idx) {
    Some(cell) =>
      render_cell_foreground_color(
        state.style_table.get(cell.style_id()),
        state.palette,
      )
    None => None
  }
}

///|
fn render_cell_background_color(
  style : @style.CellStyle,
  palette : Array[@color.RGB],
) -> @color.RGB? {
  // Every cell keeps its background in the style now (no separate background
  // content kind), so this is just the style's resolved bg.
  style.bg_color_rgb(palette)
}

///|
fn render_cell_foreground_color(
  style : @style.CellStyle,
  palette : Array[@color.RGB],
) -> @color.RGB? {
  style.fg_rgb(palette)
}

///|
fn clone_render_palette(source : Array[@color.RGB]) -> Array[@color.RGB] {
  let result : Array[@color.RGB] = []
  for color in source {
    result.push(color)
  }
  result
}

///|
fn render_palette_equals(
  left : Array[@color.RGB],
  right : Array[@color.RGB],
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
fn resolve_terminal_background(terminal : StreamTerminal) -> @color.RGB {
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
fn resolve_terminal_foreground(terminal : StreamTerminal) -> @color.RGB {
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
fn default_render_background() -> @color.RGB {
  @color.RGB::new(0, 0, 0)
}

///|
fn default_render_foreground() -> @color.RGB {
  @color.RGB::new(0xFF, 0xFF, 0xFF)
}
