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
}

///|
pub fn RenderState::new() -> RenderState {
  {
    initialized: false,
    rows: 0,
    columns: 0,
    dirty: RenderDirty::False,
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

  let dirty = if !self.initialized ||
    self.rows != rows ||
    self.columns != columns ||
    self.background != background ||
    self.foreground != foreground ||
    self.cursor_color != cursor_color ||
    !render_palette_equals(self.palette, palette) ||
    self.cursor_visual_style != cursor_visual_style ||
    self.cursor_visible != cursor_visible ||
    self.cursor_blinking != cursor_blinking ||
    self.cursor_password_input != cursor_password_input ||
    self.cursor_viewport != cursor_viewport ||
    self.cursor_viewport_wide_tail != cursor_viewport_wide_tail {
    RenderDirty::Full
  } else {
    RenderDirty::False
  }

  self.initialized = true
  self.rows = rows
  self.columns = columns
  self.dirty = dirty
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
  match terminal.grid_ref(cursor_point) {
    Some(grid_ref) =>
      match terminal.point_from_grid_ref(grid_ref, Tag::Viewport) {
        Some(viewport) => {
          let wide_tail = match terminal.grid_ref_cell(grid_ref) {
            Some(cell) => cell.wide() == PageCellWide::SpacerTail
            None => false
          }
          (Some(viewport), wide_tail)
        }
        None => (None, false)
      }
    None => (None, false)
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
