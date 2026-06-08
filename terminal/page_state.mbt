///|
// Internal representation of a cell's content. Kept package-private: external
// callers query via codepoint()/palette_index()/background_rgb()/has_grapheme()
// /grapheme_codepoints() rather than matching on this enum, so the storage
// layout stays an implementation detail.
//
// All payloads are scalar (`RGB` is a `UInt` newtype), so this is a `#valtype`
// enum: it is stored *inline* in `PageCellState` rather than as a boxed object,
// and writing a cell's content (the print hot path) is an inline value store
// with no allocation. The grapheme combining marks — the one non-scalar piece —
// live in a separate `grapheme_extras` field on the cell instead of a payload
// here, which is what lets this enum stay unboxed.
#valtype
priv enum PageCellContent {
  Codepoint(UInt)
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
  // Combining codepoints (skin-tone modifiers, accents, …) layered on top of
  // `content`'s base codepoint. `None` for the overwhelmingly common single-
  // codepoint cell, so a normal cell write allocates nothing here; only a real
  // grapheme cluster pays for the array.
  mut grapheme_extras : Array[UInt]?
  mut style : @style.CellStyle
  mut wide : PageCellWide
  mut protected_flag : Bool
  mut hyperlink : CellHyperlink?
  mut semantic_content : SemanticContent
} derive(Eq, Debug)

///|
pub fn PageCellState::new() -> PageCellState {
  {
    content: Codepoint(0U),
    grapheme_extras: None,
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
  self.content = Codepoint(codepoint)
  // `grapheme` marks the start of a cluster; the combining marks arrive later
  // via append_grapheme. `Some([])` records "this is a grapheme cell" before any
  // extras land, matching the old `CodepointGrapheme(_, [])`. Either way this
  // overwrite drops any prior cell's extras.
  self.grapheme_extras = if grapheme { Some([]) } else { None }
}

///|
pub fn PageCellState::set_background_palette(
  self : PageCellState,
  index : Byte,
) -> Unit {
  self.content = BackgroundPalette(index)
  self.grapheme_extras = None
}

///|
pub fn PageCellState::set_background_rgb(
  self : PageCellState,
  rgb : @color.RGB,
) -> Unit {
  self.content = BackgroundRgb(rgb)
  self.grapheme_extras = None
}

///|
pub fn PageCellState::codepoint(self : PageCellState) -> UInt {
  match self.content {
    Codepoint(cp) => cp
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
pub fn PageCellState::style(self : PageCellState) -> @style.CellStyle {
  self.style
}

///|
// The default (unstyled) cell style. `CellStyle` is a `#valtype`, so this is
// just the canonical zero value a fresh cell starts from — there is no shared
// instance or reference counting to manage.
let default_cell_style : @style.CellStyle = @style.CellStyle::new()

///|
pub fn PageCellState::set_style(
  self : PageCellState,
  style : @style.CellStyle,
) -> Unit {
  // A `CellStyle` is 16 inline bytes, so storing it is a value copy with no
  // allocation — the default and the styled cases are the same store.
  self.style = style
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
    Codepoint(cp) => cp != 0U
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
  // The style is an inline `#valtype`, so this is a handful of register
  // comparisons (`is_default` is `fg|bg|underline == 0 && flags == 0`) — no
  // pointer chase, like Ghostty's `style_id != default_id`.
  !self.style.is_default()
}

///|
pub fn PageCellState::is_empty(self : PageCellState) -> Bool {
  match self.content {
    Codepoint(cp) => cp == 0U && self.wide == Narrow
    BackgroundPalette(_) | BackgroundRgb(_) => false
  }
}

///|
pub fn PageCellState::has_grapheme(self : PageCellState) -> Bool {
  self.grapheme_extras is Some(_)
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
  match self.grapheme_extras {
    Some(extras) => extras
    None => []
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
  // Only text cells carry combining marks; ignore on background-color cells.
  guard self.content is Codepoint(_) else { return }
  match self.grapheme_extras {
    Some(extras) => extras.push(codepoint)
    None => self.grapheme_extras = Some([codepoint])
  }
}

///|
pub fn PageCellState::full_reset(self : PageCellState) -> Unit {
  self.content = Codepoint(0U)
  self.grapheme_extras = None
  // Re-point to the shared default rather than mutating the style in place:
  // the field may alias the shared default singleton (see `default_cell_style`).
  self.style = default_cell_style
  self.wide = Narrow
  self.protected_flag = false
  self.hyperlink = None
  self.semantic_content = Output
}
