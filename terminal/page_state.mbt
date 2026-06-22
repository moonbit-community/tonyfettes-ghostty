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
} derive(Eq, Debug, Hash)

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
/// Per-row flags packed into a single `Int` bitfield. The previous record had
/// seven `Bool` fields plus a `RowSemanticPrompt` enum, which the backend lays
/// out as eight separate int32 words inside a heap object — one allocation and
/// one `drop_object` per row. As an `Int` newtype it is an unboxed value (no
/// heap, no refcount) stored inline in `GridLine`, so a blank row scrolled in no
/// longer allocates a descriptor. Bits 0-6 are the boolean flags; bits 7-8 hold
/// the three-state semantic-prompt tag. Mutation is value-style: the `with_*`
/// builders return a new descriptor, so callers reassign the `lines[i].desc`
/// slot rather than mutating in place.
struct PageRowState(Int) derive(Eq, Debug)

///|
const RowWrapBit : Int = 0x01

///|
const RowWrapContinuationBit : Int = 0x02

///|
const RowGraphemeBit : Int = 0x04

///|
const RowStyledBit : Int = 0x08

///|
const RowHyperlinkBit : Int = 0x10

///|
const RowKittyPlaceholderBit : Int = 0x20

///|
const RowDirtyBit : Int = 0x40

///|
// Semantic-prompt tag lives in bits 7-8; the flag bits are everything below it,
// so clearing the tag is `& RowFlagMask`.
const RowSemanticShift : Int = 7

///|
const RowFlagMask : Int = 0x7F

///|
pub fn PageRowState::new() -> PageRowState {
  0
}

///|
fn PageRowState::with_bit(
  self : PageRowState,
  mask : Int,
  value : Bool,
) -> PageRowState {
  if value {
    self.0 | mask
  } else if (self.0 & mask) != 0 {
    self.0 ^ mask
  } else {
    self.0
  }
}

///|
pub fn PageRowState::wrap(self : PageRowState) -> Bool {
  (self.0 & RowWrapBit) != 0
}

///|
fn PageRowState::with_wrap(self : PageRowState, value : Bool) -> PageRowState {
  self.with_bit(RowWrapBit, value)
}

///|
pub fn PageRowState::wrap_continuation(self : PageRowState) -> Bool {
  (self.0 & RowWrapContinuationBit) != 0
}

///|
fn PageRowState::with_wrap_continuation(
  self : PageRowState,
  value : Bool,
) -> PageRowState {
  self.with_bit(RowWrapContinuationBit, value)
}

///|
pub fn PageRowState::grapheme(self : PageRowState) -> Bool {
  (self.0 & RowGraphemeBit) != 0
}

///|
fn PageRowState::with_grapheme(
  self : PageRowState,
  value : Bool,
) -> PageRowState {
  self.with_bit(RowGraphemeBit, value)
}

///|
pub fn PageRowState::styled(self : PageRowState) -> Bool {
  (self.0 & RowStyledBit) != 0
}

///|
fn PageRowState::with_styled(self : PageRowState, value : Bool) -> PageRowState {
  self.with_bit(RowStyledBit, value)
}

///|
pub fn PageRowState::hyperlink(self : PageRowState) -> Bool {
  (self.0 & RowHyperlinkBit) != 0
}

///|
fn PageRowState::with_hyperlink(
  self : PageRowState,
  value : Bool,
) -> PageRowState {
  self.with_bit(RowHyperlinkBit, value)
}

///|
pub fn PageRowState::semantic_prompt(self : PageRowState) -> RowSemanticPrompt {
  match (self.0 >> RowSemanticShift) & 0x3 {
    1 => Prompt
    2 => PromptContinuation
    _ => None
  }
}

///|
fn PageRowState::with_semantic_prompt(
  self : PageRowState,
  value : RowSemanticPrompt,
) -> PageRowState {
  let code = match value {
    None => 0
    Prompt => 1
    PromptContinuation => 2
  }
  (self.0 & RowFlagMask) | (code << RowSemanticShift)
}

///|
pub fn PageRowState::kitty_virtual_placeholder(self : PageRowState) -> Bool {
  (self.0 & RowKittyPlaceholderBit) != 0
}

///|
fn PageRowState::with_kitty_virtual_placeholder(
  self : PageRowState,
  value : Bool,
) -> PageRowState {
  self.with_bit(RowKittyPlaceholderBit, value)
}

///|
pub fn PageRowState::dirty(self : PageRowState) -> Bool {
  (self.0 & RowDirtyBit) != 0
}

///|
fn PageRowState::with_dirty(self : PageRowState, value : Bool) -> PageRowState {
  self.with_bit(RowDirtyBit, value)
}

///|
pub fn PageRowState::managed_memory(self : PageRowState) -> Bool {
  (self.0 & (RowStyledBit | RowHyperlinkBit | RowGraphemeBit)) != 0
}

///|
// The codepoint of a cell with no glyph. U+0000 (NUL) is never a displayable
// character — terminals discard a printed NUL — so it is the conventional
// "empty cell" sentinel (upstream Ghostty uses it the same way). Kept as a named
// scalar rather than `UInt?` so the cell stays allocation-free and value-typed.
const EmptyCodepoint : UInt = 0

///|
// `wide` (2 bits), `protected` (1 bit), and `semantic_content` (2 bits) packed
// into one machine word, mirroring how upstream Ghostty bit-packs these flags
// inside its `u64` cell. Folding three fields into one keeps `PageCellState`
// within the six-field limit a native `#valtype` struct allows. Bit 3 is
// reserved for a future `hyperlink` flag, so the layout already matches
// upstream's field order (wide, protected, hyperlink, semantic_content).
//
//   bit 0-1 : wide              (Narrow=0 Wide=1 SpacerTail=2 SpacerHead=3)
//   bit 2   : protected
//   bit 3   : reserved (hyperlink)
//   bit 4-5 : semantic_content  (Output=0 Input=1 Prompt=2)
struct PageCellFlags(Int) derive(Eq, Debug)

///|
const CellWideMask : Int = 0x03

///|
const CellProtectedBit : Int = 0x04

///|
const CellSemanticShift : Int = 4

///|
fn PageCellFlags::pack(
  wide : PageCellWide,
  protected_flag : Bool,
  semantic_content : SemanticContent,
) -> PageCellFlags {
  let wide_bits = match wide {
    Narrow => 0
    Wide => 1
    SpacerTail => 2
    SpacerHead => 3
  }
  let semantic_bits = match semantic_content {
    Output => 0
    Input => 1
    Prompt => 2
  }
  let protected_bit = if protected_flag { CellProtectedBit } else { 0 }
  PageCellFlags(
    wide_bits | protected_bit | (semantic_bits << CellSemanticShift),
  )
}

///|
fn PageCellFlags::wide(self : PageCellFlags) -> PageCellWide {
  match self.0 & CellWideMask {
    1 => Wide
    2 => SpacerTail
    3 => SpacerHead
    _ => Narrow
  }
}

///|
fn PageCellFlags::is_protected(self : PageCellFlags) -> Bool {
  (self.0 & CellProtectedBit) != 0
}

///|
fn PageCellFlags::semantic_content(self : PageCellFlags) -> SemanticContent {
  match (self.0 >> CellSemanticShift) & 0x3 {
    1 => Input
    2 => Prompt
    _ => Output
  }
}

///|
fn PageCellFlags::with_wide(
  self : PageCellFlags,
  value : PageCellWide,
) -> PageCellFlags {
  let wide_bits = match value {
    Narrow => 0
    Wide => 1
    SpacerTail => 2
    SpacerHead => 3
  }
  PageCellFlags((self.0 & CellWideMask.lnot()) | wide_bits)
}

///|
fn PageCellFlags::with_protected(
  self : PageCellFlags,
  value : Bool,
) -> PageCellFlags {
  if value {
    PageCellFlags(self.0 | CellProtectedBit)
  } else {
    PageCellFlags(self.0 & CellProtectedBit.lnot())
  }
}

///|
// A cell is an immutable value: writes produce a new `PageCellState` via the
// `with_*` builders and the grid stores it back into its slot, rather than
// mutating fields in place. This keeps cells aliasing-safe (a value can be
// copied freely).
//
// NOT `#valtype`, deliberately. The struct still holds three refcounted pointer
// fields (`style`, `grapheme_extras`, `hyperlink`), so as a value type every
// copy moves five words AND retains/releases up to three pointers — whereas a
// boxed cell is one pointer + one refcount per copy. The print/scroll path is
// copy-heavy (immutable `with_*`, snapshots, row shifts), so `#valtype` measured
// as a net regression: +30% on plain_lines, +140% on scroll_storm
// (`moon bench -p bench/workloads --release --target native`, 2026-06-22). A flat
// value cell only pays off once those pointer fields are gone (style packed/
// indexed, hyperlink→bool+side table, grapheme→side table — i.e. Zig's pointer-
// free `u64` cell). Until then, keep it boxed.
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
  // The cell's combining codepoints as a `GraphemeId` into the screen's shared
  // `GraphemeTable` (0 = not a grapheme cell). Presence (`has_grapheme`) is a
  // plain id compare; the actual marks are resolved through the grid/screen only
  // when emitting text. This is the cell's last non-scalar field removed — the
  // struct is now all-scalar.
  grapheme_id : GraphemeId
  // The cell's style as a `StyleId` index into the screen's shared `StyleTable`,
  // not an inline style. `0` (the default style) needs no lookup. This removes a
  // refcounted pointer from the cell — a prerequisite for the eventual flat
  // `u64` cell — and matches upstream Ghostty's `style_id`. Resolve it to a
  // `CellStyle` through the grid/screen that owns the table (the cell alone
  // cannot, by design).
  style_id : @style.StyleId
  // `wide`, `protected`, and `semantic_content` packed into one word — see
  // `PageCellFlags`. Three separate fields would push the struct to seven and
  // break the native `#valtype` six-field cap.
  flags : PageCellFlags
  // The cell's hyperlink as a `HyperlinkId` into the screen's shared
  // `HyperlinkTable` (0 = no link). Like `style_id`, this removes a pointer from
  // the cell; presence is a plain id compare and the uri is resolved through the
  // grid/screen only when actually needed (HTML export).
  hyperlink_id : HyperlinkId
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
  style_id? : @style.StyleId = @style.default_style_id,
  wide? : PageCellWide = Narrow,
  protected_flag? : Bool = false,
  hyperlink_id? : HyperlinkId = no_hyperlink_id,
  semantic_content? : SemanticContent = Output,
) -> PageCellState {
  {
    codepoint,
    // `grapheme` only ever flags an *empty* cluster here (marks are appended
    // later through the grid), so the reserved empty id sets it with no table.
    grapheme_id: if grapheme {
      empty_grapheme_id
    } else {
      no_grapheme_id
    },
    style_id,
    flags: PageCellFlags::pack(wide, protected_flag, semantic_content),
    hyperlink_id,
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
  // through the grid (`GraphemeTable::append`). The reserved empty id records
  // "this is a grapheme cell" before any marks land. Either way this overwrite
  // drops any prior extras.
  {
    ..self,
    codepoint,
    grapheme_id: if grapheme {
      empty_grapheme_id
    } else {
      no_grapheme_id
    },
  }
}

///|
pub fn PageCellState::codepoint(self : PageCellState) -> UInt {
  self.codepoint
}

///|
// The cell's style id into the screen's `StyleTable`. Resolution to a concrete
// `CellStyle` (and thus `palette_index`/`background_rgb`/the full style) is done
// by the grid/screen that owns the table — see `ScreenGridState::cell_style`.
pub fn PageCellState::style_id(self : PageCellState) -> @style.StyleId {
  self.style_id
}

///|
// A single shared blank cell. Because a cell is immutable, every empty slot can
// point at this one value instead of allocating its own — a cleared/scrolled-in
// row is then a fill of the same reference, with no per-cell allocation. A write
// replaces the slot wholesale (the shared value is never mutated), so the sharing
// is invisible to callers.
let default_page_cell_state : PageCellState = PageCellState::new()

///|
pub fn PageCellState::with_style_id(
  self : PageCellState,
  style_id : @style.StyleId,
) -> PageCellState {
  // Swap in a new style id (a 16-bit value); the style itself lives in the table.
  { ..self, style_id, }
}

///|
pub fn PageCellState::wide(self : PageCellState) -> PageCellWide {
  self.flags.wide()
}

///|
pub fn PageCellState::with_wide(
  self : PageCellState,
  value : PageCellWide,
) -> PageCellState {
  { ..self, flags: self.flags.with_wide(value) }
}

///|
pub fn PageCellState::is_protected(self : PageCellState) -> Bool {
  self.flags.is_protected()
}

///|
pub fn PageCellState::with_protected(
  self : PageCellState,
  value : Bool,
) -> PageCellState {
  { ..self, flags: self.flags.with_protected(value) }
}

///|
// The cell's hyperlink id. Resolution to the full `CellHyperlink` is done by the
// grid/screen that owns the table — see `ScreenGridState::cell_hyperlink`.
pub fn PageCellState::hyperlink_id(self : PageCellState) -> HyperlinkId {
  self.hyperlink_id
}

///|
// Whether this cell is part of a hyperlink. A plain id compare — no table lookup.
pub fn PageCellState::has_hyperlink(self : PageCellState) -> Bool {
  !self.hyperlink_id.is_none()
}

///|
pub fn PageCellState::with_hyperlink_id(
  self : PageCellState,
  value : HyperlinkId,
) -> PageCellState {
  { ..self, hyperlink_id: value }
}

///|
pub fn PageCellState::semantic_content(self : PageCellState) -> SemanticContent {
  self.flags.semantic_content()
}

///|
pub fn PageCellState::is_zero(self : PageCellState) -> Bool {
  self == default_page_cell_state
}

///|
pub fn PageCellState::has_text(self : PageCellState) -> Bool {
  self.codepoint != EmptyCodepoint
}

///|
pub fn PageCellState::grid_width(self : PageCellState) -> Int {
  match self.flags.wide() {
    Narrow | SpacerHead | SpacerTail => 1
    Wide => 2
  }
}

///|
pub fn PageCellState::has_styling(self : PageCellState) -> Bool {
  // The style id is the default (0) exactly when the cell is unstyled, so this is
  // a single integer compare — like Ghostty's `style_id != default_id`.
  !self.style_id.is_default()
}

///|
pub fn PageCellState::is_empty(self : PageCellState) -> Bool {
  // Note: a cell carrying only a background color is now "empty" here (no glyph)
  // but `has_styling()` is true, so trim/emit sites use `!is_empty() ||
  // has_styling()` to keep it.
  self.codepoint == EmptyCodepoint && self.flags.wide() == Narrow
}

///|
pub fn PageCellState::has_grapheme(self : PageCellState) -> Bool {
  !self.grapheme_id.is_none()
}

///|
// The cell's grapheme id. The combining codepoints themselves are resolved by the
// grid/screen that owns the table — see `ScreenGridState::cell_grapheme_codepoints`.
pub fn PageCellState::grapheme_id(self : PageCellState) -> GraphemeId {
  self.grapheme_id
}

///|
pub fn PageCellState::with_grapheme_id(
  self : PageCellState,
  value : GraphemeId,
) -> PageCellState {
  { ..self, grapheme_id: value }
}
