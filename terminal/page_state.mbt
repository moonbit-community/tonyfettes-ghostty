///|
// Internal representation of a cell's content. Kept package-private: external
// callers query via codepoint()/palette_index()/background_rgb()/has_grapheme()
// /grapheme_codepoints() rather than matching on this enum, so the storage
// layout stays an implementation detail.
enum PageCellContent {
  Codepoint(UInt)
  CodepointGrapheme(UInt, Array[UInt])
  BackgroundPalette(Byte)
  BackgroundRgb(@color.RGB)
} derive(Eq, Debug)

///|
pub(all) enum PageCellWide {
  Narrow
  Wide
  SpacerTail
  SpacerHead
} derive(Eq, Debug)

///|
struct CellHyperlink {
  uri : String
  explicit_id : String?
  implicit_id : Int?
} derive(Eq, Debug)

///|
pub fn CellHyperlink::explicit(uri : String, id : String) -> CellHyperlink {
  { uri, explicit_id: Some(id), implicit_id: None }
}

///|
pub fn CellHyperlink::implicit(uri : String, id : Int) -> CellHyperlink {
  { uri, explicit_id: None, implicit_id: Some(id) }
}

///|
pub fn CellHyperlink::uri(self : CellHyperlink) -> String {
  self.uri
}

///|
pub fn CellHyperlink::explicit_id(self : CellHyperlink) -> String? {
  self.explicit_id
}

///|
pub fn CellHyperlink::implicit_id(self : CellHyperlink) -> Int? {
  self.implicit_id
}

///|
struct PageRowState {
  mut wrap : Bool
  mut wrap_continuation : Bool
  mut grapheme : Bool
  mut styled : Bool
  mut hyperlink : Bool
  mut semantic_prompt : RowSemanticPrompt
  mut kitty_virtual_placeholder : Bool
  mut dirty : Bool
} derive(Eq, Debug)

///|
pub fn PageRowState::new() -> PageRowState {
  {
    wrap: false,
    wrap_continuation: false,
    grapheme: false,
    styled: false,
    hyperlink: false,
    semantic_prompt: None,
    kitty_virtual_placeholder: false,
    dirty: false,
  }
}

///|
pub fn PageRowState::wrap(self : PageRowState) -> Bool {
  self.wrap
}

///|
pub fn PageRowState::set_wrap(self : PageRowState, value : Bool) -> Unit {
  self.wrap = value
}

///|
pub fn PageRowState::wrap_continuation(self : PageRowState) -> Bool {
  self.wrap_continuation
}

///|
pub fn PageRowState::set_wrap_continuation(
  self : PageRowState,
  value : Bool,
) -> Unit {
  self.wrap_continuation = value
}

///|
pub fn PageRowState::grapheme(self : PageRowState) -> Bool {
  self.grapheme
}

///|
pub fn PageRowState::set_grapheme(self : PageRowState, value : Bool) -> Unit {
  self.grapheme = value
}

///|
pub fn PageRowState::styled(self : PageRowState) -> Bool {
  self.styled
}

///|
pub fn PageRowState::set_styled(self : PageRowState, value : Bool) -> Unit {
  self.styled = value
}

///|
pub fn PageRowState::hyperlink(self : PageRowState) -> Bool {
  self.hyperlink
}

///|
pub fn PageRowState::set_hyperlink(self : PageRowState, value : Bool) -> Unit {
  self.hyperlink = value
}

///|
pub fn PageRowState::semantic_prompt(self : PageRowState) -> RowSemanticPrompt {
  self.semantic_prompt
}

///|
pub fn PageRowState::set_semantic_prompt(
  self : PageRowState,
  value : RowSemanticPrompt,
) -> Unit {
  self.semantic_prompt = value
}

///|
pub fn PageRowState::kitty_virtual_placeholder(self : PageRowState) -> Bool {
  self.kitty_virtual_placeholder
}

///|
pub fn PageRowState::set_kitty_virtual_placeholder(
  self : PageRowState,
  value : Bool,
) -> Unit {
  self.kitty_virtual_placeholder = value
}

///|
pub fn PageRowState::dirty(self : PageRowState) -> Bool {
  self.dirty
}

///|
pub fn PageRowState::set_dirty(self : PageRowState, value : Bool) -> Unit {
  self.dirty = value
}

///|
pub fn PageRowState::managed_memory(self : PageRowState) -> Bool {
  self.styled || self.hyperlink || self.grapheme
}

///|
pub fn PageRowState::full_reset(self : PageRowState) -> Unit {
  self.wrap = false
  self.wrap_continuation = false
  self.grapheme = false
  self.styled = false
  self.hyperlink = false
  self.semantic_prompt = None
  self.kitty_virtual_placeholder = false
  self.dirty = false
}

///|
struct PageCellState {
  mut content : PageCellContent
  mut style : CellStyle
  mut wide : PageCellWide
  mut protected_flag : Bool
  mut hyperlink : CellHyperlink?
  mut semantic_content : SemanticContent
} derive(Eq, Debug)

///|
pub fn PageCellState::new() -> PageCellState {
  {
    content: Codepoint(0U),
    style: default_cell_style,
    wide: Narrow,
    protected_flag: false,
    hyperlink: None,
    semantic_content: Output,
  }
}

///|
pub fn PageCellState::init(codepoint : UInt) -> PageCellState {
  let cell = PageCellState::new()
  cell.set_codepoint(codepoint, false)
  cell
}

///|
fn PageCellState::content(self : PageCellState) -> PageCellContent {
  self.content
}

///|
pub fn PageCellState::set_codepoint(
  self : PageCellState,
  codepoint : UInt,
  grapheme : Bool,
) -> Unit {
  self.content = if grapheme {
    CodepointGrapheme(codepoint, [])
  } else {
    Codepoint(codepoint)
  }
}

///|
pub fn PageCellState::set_background_palette(
  self : PageCellState,
  index : Byte,
) -> Unit {
  self.content = BackgroundPalette(index)
}

///|
pub fn PageCellState::set_background_rgb(
  self : PageCellState,
  rgb : @color.RGB,
) -> Unit {
  self.content = BackgroundRgb(rgb)
}

///|
pub fn PageCellState::codepoint(self : PageCellState) -> UInt {
  match self.content {
    Codepoint(cp) | CodepointGrapheme(cp, _) => cp
    BackgroundPalette(_) | BackgroundRgb(_) => 0U
  }
}

///|
pub fn PageCellState::palette_index(self : PageCellState) -> Byte? {
  match self.content {
    BackgroundPalette(index) => Some(index)
    _ => None
  }
}

///|
pub fn PageCellState::background_rgb(self : PageCellState) -> @color.RGB? {
  match self.content {
    BackgroundRgb(rgb) => Some(rgb)
    _ => None
  }
}

///|
pub fn PageCellState::style(self : PageCellState) -> CellStyle {
  copy_page_cell_style(self.style)
}

///|
// The default cell style, shared by every cell that has no SGR styling.
//
// Analogous to upstream Ghostty's `style.default_id`: the overwhelmingly common
// style needs neither per-cell storage nor a copy. The singleton is treated as
// immutable — `set_style` shares it by reference, `full_reset` re-points to it,
// and the only in-place mutator a cell had (`full_reset`'s `style.reset()`) now
// replaces the field instead. Reads go through `PageCellState::style()`, which
// returns a copy, so no caller can mutate the shared instance.
let default_cell_style : CellStyle = CellStyle::new()

///|
pub fn PageCellState::set_style(
  self : PageCellState,
  style : CellStyle,
) -> Unit {
  // Share the default singleton (no allocation) for unstyled cells — the hot
  // path for plain text; copy only when the style actually carries SGR state.
  if style.is_default() {
    // Skip the assignment when the cell already points at the singleton, so the
    // common "overwrite an unstyled cell with unstyled text" case touches no
    // reference counts at all.
    if !physical_equal(self.style, default_cell_style) {
      self.style = default_cell_style
    }
  } else {
    self.style = copy_page_cell_style(style)
  }
}

///|
pub fn PageCellState::wide(self : PageCellState) -> PageCellWide {
  self.wide
}

///|
pub fn PageCellState::set_wide(
  self : PageCellState,
  value : PageCellWide,
) -> Unit {
  self.wide = value
}

///|
pub fn PageCellState::is_protected(self : PageCellState) -> Bool {
  self.protected_flag
}

///|
pub fn PageCellState::set_protected(self : PageCellState, value : Bool) -> Unit {
  self.protected_flag = value
}

///|
pub fn PageCellState::hyperlink(self : PageCellState) -> CellHyperlink? {
  self.hyperlink
}

///|
pub fn PageCellState::set_hyperlink(
  self : PageCellState,
  value : CellHyperlink?,
) -> Unit {
  self.hyperlink = value
}

///|
pub fn PageCellState::semantic_content(self : PageCellState) -> SemanticContent {
  self.semantic_content
}

///|
pub fn PageCellState::set_semantic_content(
  self : PageCellState,
  value : SemanticContent,
) -> Unit {
  self.semantic_content = value
}

///|
pub fn PageCellState::is_zero(self : PageCellState) -> Bool {
  self == PageCellState::new()
}

///|
pub fn PageCellState::has_text(self : PageCellState) -> Bool {
  match self.content {
    Codepoint(cp) | CodepointGrapheme(cp, _) => cp != 0U
    BackgroundPalette(_) | BackgroundRgb(_) => false
  }
}

///|
pub fn PageCellState::grid_width(self : PageCellState) -> Int {
  match self.wide {
    Narrow | SpacerHead | SpacerTail => 1
    Wide => 2
  }
}

///|
pub fn PageCellState::has_styling(self : PageCellState) -> Bool {
  // Fast path: cells written on the active grid share the `default_cell_style`
  // singleton for unstyled text (set_style / full_reset / new), so the identity
  // check resolves the hot print path in O(1), like Ghostty's
  // `style_id != default_id`. The scrollback/reflow copy paths build a
  // fresh-but-equal default style, so when the identity test misses, fall back
  // to the structural is_default() — keeping the answer exact regardless of how
  // the cell was constructed.
  !physical_equal(self.style, default_cell_style) && !self.style.is_default()
}

///|
pub fn PageCellState::is_empty(self : PageCellState) -> Bool {
  match self.content {
    Codepoint(cp) | CodepointGrapheme(cp, _) => cp == 0U && self.wide == Narrow
    BackgroundPalette(_) | BackgroundRgb(_) => false
  }
}

///|
pub fn PageCellState::has_grapheme(self : PageCellState) -> Bool {
  self.content is CodepointGrapheme(_, _)
}

///|
// The cell's combining codepoints (empty when the cell is not a grapheme
// cluster). Returns a read-only `ArrayView` over the cell's internal storage —
// no copy on the render hot path, and the view exposes no `push`/element-set,
// so callers cannot resize or mutate the cell's grapheme run (which would
// desync `PageRowState::grapheme`/dirty flags). Callers that need to retain or
// edit the codepoints should `.to_array()` first.
pub fn PageCellState::grapheme_codepoints(
  self : PageCellState,
) -> ArrayView[UInt] {
  match self.content {
    CodepointGrapheme(_, extras) => extras
    _ => []
  }
}

///|
// Append a combining codepoint onto this cell. Upgrades Codepoint to
// CodepointGrapheme on first call; subsequent calls push onto the existing
// extras. Only meaningful when the cell has text.
fn PageCellState::append_grapheme(
  self : PageCellState,
  codepoint : UInt,
) -> Unit {
  match self.content {
    Codepoint(base) => self.content = CodepointGrapheme(base, [codepoint])
    CodepointGrapheme(_, extras) => extras.push(codepoint)
    _ => ()
  }
}

///|
pub fn PageCellState::full_reset(self : PageCellState) -> Unit {
  self.content = Codepoint(0U)
  // Re-point to the shared default rather than mutating the style in place:
  // the field may alias the shared default singleton (see `default_cell_style`).
  self.style = default_cell_style
  self.wide = Narrow
  self.protected_flag = false
  self.hyperlink = None
  self.semantic_content = Output
}

///|
fn copy_page_cell_style(style : CellStyle) -> CellStyle {
  {
    fg_color: style.fg_color,
    bg_color: style.bg_color,
    underline_color: style.underline_color,
    bold: style.bold,
    italic: style.italic,
    faint: style.faint,
    blink: style.blink,
    inverse: style.inverse,
    invisible: style.invisible,
    strikethrough: style.strikethrough,
    overline: style.overline,
    underline: style.underline,
  }
}
