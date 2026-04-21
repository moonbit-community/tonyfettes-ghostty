///|
pub(all) enum PageCellContentTag {
  Codepoint
  CodepointGrapheme
  BackgroundPalette
  BackgroundRgb
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
    semantic_prompt: RowSemanticPrompt::None,
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
  self.semantic_prompt = RowSemanticPrompt::None
  self.kitty_virtual_placeholder = false
  self.dirty = false
}

///|
struct PageCellState {
  mut content_tag : PageCellContentTag
  mut codepoint : UInt
  mut palette_index : Byte
  mut bg_rgb : RGB
  mut style : CellStyle
  mut wide : PageCellWide
  mut protected_flag : Bool
  mut hyperlink : CellHyperlink?
  mut semantic_content : SemanticContent
} derive(Eq, Debug)

///|
pub fn PageCellState::new() -> PageCellState {
  {
    content_tag: PageCellContentTag::Codepoint,
    codepoint: 0U,
    palette_index: 0,
    bg_rgb: RGB::new(0, 0, 0),
    style: CellStyle::new(),
    wide: PageCellWide::Narrow,
    protected_flag: false,
    hyperlink: None,
    semantic_content: SemanticContent::Output,
  }
}

///|
pub fn PageCellState::init(codepoint : UInt) -> PageCellState {
  let cell = PageCellState::new()
  cell.set_codepoint(codepoint, false)
  cell
}

///|
pub fn PageCellState::content_tag(self : PageCellState) -> PageCellContentTag {
  self.content_tag
}

///|
pub fn PageCellState::set_codepoint(
  self : PageCellState,
  codepoint : UInt,
  grapheme : Bool,
) -> Unit {
  self.content_tag = if grapheme {
    PageCellContentTag::CodepointGrapheme
  } else {
    PageCellContentTag::Codepoint
  }
  self.codepoint = codepoint
}

///|
pub fn PageCellState::set_background_palette(
  self : PageCellState,
  index : Byte,
) -> Unit {
  self.content_tag = PageCellContentTag::BackgroundPalette
  self.palette_index = index
}

///|
pub fn PageCellState::set_background_rgb(
  self : PageCellState,
  rgb : RGB,
) -> Unit {
  self.content_tag = PageCellContentTag::BackgroundRgb
  self.bg_rgb = rgb
}

///|
pub fn PageCellState::codepoint(self : PageCellState) -> UInt {
  match self.content_tag {
    PageCellContentTag::Codepoint | PageCellContentTag::CodepointGrapheme =>
      self.codepoint
    PageCellContentTag::BackgroundPalette | PageCellContentTag::BackgroundRgb =>
      0U
  }
}

///|
pub fn PageCellState::palette_index(self : PageCellState) -> Byte? {
  match self.content_tag {
    PageCellContentTag::BackgroundPalette => Some(self.palette_index)
    PageCellContentTag::Codepoint
    | PageCellContentTag::CodepointGrapheme
    | PageCellContentTag::BackgroundRgb => None
  }
}

///|
pub fn PageCellState::background_rgb(self : PageCellState) -> RGB? {
  match self.content_tag {
    PageCellContentTag::BackgroundRgb => Some(self.bg_rgb)
    PageCellContentTag::Codepoint
    | PageCellContentTag::CodepointGrapheme
    | PageCellContentTag::BackgroundPalette => None
  }
}

///|
pub fn PageCellState::style(self : PageCellState) -> CellStyle {
  copy_page_cell_style(self.style)
}

///|
pub fn PageCellState::set_style(
  self : PageCellState,
  style : CellStyle,
) -> Unit {
  self.style = copy_page_cell_style(style)
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
  match self.content_tag {
    PageCellContentTag::Codepoint | PageCellContentTag::CodepointGrapheme =>
      self.codepoint != 0U
    PageCellContentTag::BackgroundPalette | PageCellContentTag::BackgroundRgb =>
      false
  }
}

///|
pub fn PageCellState::grid_width(self : PageCellState) -> Int {
  match self.wide {
    PageCellWide::Narrow
    | PageCellWide::SpacerHead
    | PageCellWide::SpacerTail => 1
    PageCellWide::Wide => 2
  }
}

///|
pub fn PageCellState::has_styling(self : PageCellState) -> Bool {
  !self.style.is_default()
}

///|
pub fn PageCellState::is_empty(self : PageCellState) -> Bool {
  match self.content_tag {
    PageCellContentTag::Codepoint | PageCellContentTag::CodepointGrapheme =>
      !self.has_text() && self.wide == PageCellWide::Narrow
    PageCellContentTag::BackgroundPalette | PageCellContentTag::BackgroundRgb =>
      false
  }
}

///|
pub fn PageCellState::has_grapheme(self : PageCellState) -> Bool {
  self.content_tag == PageCellContentTag::CodepointGrapheme
}

///|
pub fn PageCellState::full_reset(self : PageCellState) -> Unit {
  self.content_tag = PageCellContentTag::Codepoint
  self.codepoint = 0U
  self.palette_index = 0
  self.bg_rgb = RGB::new(0, 0, 0)
  self.style.reset()
  self.wide = PageCellWide::Narrow
  self.protected_flag = false
  self.hyperlink = None
  self.semantic_content = SemanticContent::Output
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
