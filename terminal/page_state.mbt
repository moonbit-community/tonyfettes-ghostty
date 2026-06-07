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
// The codepoint of a cell with no glyph. U+0000 (NUL) is never a displayable
// character — terminals discard a printed NUL — so it is the conventional
// "empty cell" sentinel (upstream Ghostty uses it the same way). Kept as a named
// scalar rather than `UInt?` so the cell stays allocation-free and value-typed.
const EmptyCodepoint : UInt = 0

///|
// A cell is an immutable value: writes produce a new `PageCellState` via the
// `with_*` builders and the grid stores it back into its slot, rather than
// mutating fields in place. This keeps cells aliasing-safe (a value can be
// copied freely) and is the prerequisite for later making the cell a flat
// `#valtype` so `Array[PageCellState]` becomes a contiguous value buffer.
struct PageCellState {
  // The cell's base codepoint (`EmptyCodepoint` = blank). A cell's background
  // color lives in `style.bg_color` like any other style attribute — there is no
  // separate "background cell" kind, so the codepoint is a plain scalar.
  codepoint : UInt
  // Combining codepoints (skin-tone modifiers, accents, …) layered on top of
  // the base codepoint. `None` for the overwhelmingly common single-
  // codepoint cell, so a normal cell write allocates nothing here; only a real
  // grapheme cluster pays for the array. `ReadOnlyArray` so it can never be
  // mutated in place — together with the immutable cell that means copying a
  // cell into another slot is a plain value share, with no deep copy needed.
  grapheme_extras : ReadOnlyArray[UInt]?
  style : @style.CellStyle
  wide : PageCellWide
  protected_flag : Bool
  hyperlink : CellHyperlink?
  semantic_content : SemanticContent
} derive(Eq, Debug)

///|
// Construct a cell. Every field is an optional with the blank-cell default, so
// `new()` is still a blank cell and a fully-specified cell is one call —
// `new(codepoint=.., style=.., wide=..)` — rather than a `with_*` chain. A
// background-color cell is just a blank cell whose `style` carries the bg, so it
// is `new(style=...)` too; the `with_*` builders remain for transforming an
// *existing* cell.
pub fn PageCellState::new(
  codepoint? : UInt = EmptyCodepoint,
  grapheme? : Bool = false,
  style? : @style.CellStyle = default_cell_style,
  wide? : PageCellWide = Narrow,
  protected_flag? : Bool = false,
  hyperlink? : CellHyperlink? = None,
  semantic_content? : SemanticContent = Output,
) -> PageCellState {
  {
    codepoint,
    grapheme_extras: if grapheme {
      Some([])
    } else {
      None
    },
    style,
    wide,
    protected_flag,
    hyperlink,
    semantic_content,
  }
}

///|
pub fn PageCellState::init(codepoint : UInt) -> PageCellState {
  PageCellState::new(codepoint~)
}

///|
pub fn PageCellState::with_codepoint(
  self : PageCellState,
  codepoint : UInt,
  grapheme : Bool,
) -> PageCellState {
  // `grapheme` marks the start of a cluster; the combining marks arrive later
  // via with_grapheme_appended. `Some([])` records "this is a grapheme cell"
  // before any extras land. Either way this overwrite drops any prior extras.
  { ..self, codepoint, grapheme_extras: if grapheme { Some([]) } else { None } }
}

///|
pub fn PageCellState::codepoint(self : PageCellState) -> UInt {
  self.codepoint
}

///|
// The cell's background as a palette index, if its style's bg is a palette
// color. Equivalent to `style().bg_color().palette_index()`; kept as a cell-level
// convenience for renderers.
pub fn PageCellState::palette_index(self : PageCellState) -> Byte? {
  self.style.bg_color().palette_index()
}

///|
// The cell's background as a direct RGB color, if its style's bg is RGB.
pub fn PageCellState::background_rgb(self : PageCellState) -> @color.RGB? {
  self.style.bg_color().rgb_value()
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
pub fn PageCellState::with_style(
  self : PageCellState,
  style : @style.CellStyle,
) -> PageCellState {
  // A `CellStyle` is 16 inline bytes, so this is a value copy with no allocation.
  { ..self, style, }
}

///|
pub fn PageCellState::wide(self : PageCellState) -> PageCellWide {
  self.wide
}

///|
pub fn PageCellState::with_wide(
  self : PageCellState,
  value : PageCellWide,
) -> PageCellState {
  { ..self, wide: value }
}

///|
pub fn PageCellState::is_protected(self : PageCellState) -> Bool {
  self.protected_flag
}

///|
pub fn PageCellState::with_protected(
  self : PageCellState,
  value : Bool,
) -> PageCellState {
  { ..self, protected_flag: value }
}

///|
pub fn PageCellState::hyperlink(self : PageCellState) -> CellHyperlink? {
  self.hyperlink
}

///|
pub fn PageCellState::with_hyperlink(
  self : PageCellState,
  value : CellHyperlink?,
) -> PageCellState {
  { ..self, hyperlink: value }
}

///|
pub fn PageCellState::semantic_content(self : PageCellState) -> SemanticContent {
  self.semantic_content
}

///|
pub fn PageCellState::is_zero(self : PageCellState) -> Bool {
  self == PageCellState::new()
}

///|
pub fn PageCellState::has_text(self : PageCellState) -> Bool {
  self.codepoint != EmptyCodepoint
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
  // Note: a cell carrying only a background color is now "empty" here (no glyph)
  // but `has_styling()` is true, so trim/emit sites use `!is_empty() ||
  // has_styling()` to keep it.
  self.codepoint == EmptyCodepoint && self.wide == Narrow
}

///|
pub fn PageCellState::has_grapheme(self : PageCellState) -> Bool {
  self.grapheme_extras is Some(_)
}

///|
// The cell's combining codepoints (empty when the cell is not a grapheme
// cluster). Returns the cell's `ReadOnlyArray` directly — no copy on the render
// hot path, and the type itself forbids `push`/element-set, so callers cannot
// resize or mutate the cell's grapheme run (which would desync
// `PageRowState::grapheme`/dirty flags). Callers that need a mutable copy should
// `.iter().collect()` first.
pub fn PageCellState::grapheme_codepoints(
  self : PageCellState,
) -> ReadOnlyArray[UInt] {
  match self.grapheme_extras {
    Some(extras) => extras
    None => []
  }
}

///|
// Return a copy of this cell with one more combining codepoint. Seeds the
// extras on the first mark; subsequent marks extend a *fresh* array so the
// returned cell never shares storage with `self` (value-semantics safe). Callers
// only invoke this on a cell that already has a base glyph.
fn PageCellState::with_grapheme_appended(
  self : PageCellState,
  codepoint : UInt,
) -> PageCellState {
  let extras : Array[UInt] = match self.grapheme_extras {
    Some(existing) => {
      let copy = Array::make(existing.length() + 1, codepoint)
      for index in 0..<existing.length() {
        copy[index] = existing.at(index)
      }
      copy
    }
    None => [codepoint]
  }
  { ..self, grapheme_extras: Some(ReadOnlyArray::from_array(extras)) }
}
