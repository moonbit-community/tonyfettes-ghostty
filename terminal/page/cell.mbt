///|
pub(all) enum PageCellWide {
  Narrow
  Wide
  SpacerTail
  SpacerHead
} derive(Eq, Debug)

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
pub fn PageRowState::with_wrap(
  self : PageRowState,
  value : Bool,
) -> PageRowState {
  self.with_bit(RowWrapBit, value)
}

///|
pub fn PageRowState::wrap_continuation(self : PageRowState) -> Bool {
  (self.0 & RowWrapContinuationBit) != 0
}

///|
pub fn PageRowState::with_wrap_continuation(
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
pub fn PageRowState::with_grapheme(
  self : PageRowState,
  value : Bool,
) -> PageRowState {
  self.with_bit(RowGraphemeBit, value)
}

///|
// Unconditional single-bit setters for the incremental write hot path. Unlike
// `with_bit`, these are branchless single expressions so the cross-package
// inliner folds them into a plain OR/AND at the call site.
pub fn PageRowState::set_styled(self : PageRowState) -> PageRowState {
  self.0 | RowStyledBit
}

///|
pub fn PageRowState::set_hyperlink(self : PageRowState) -> PageRowState {
  self.0 | RowHyperlinkBit
}

///|
pub fn PageRowState::clear_kitty_virtual_placeholder(
  self : PageRowState,
) -> PageRowState {
  self.0 & RowKittyPlaceholderBit.lnot()
}

///|
pub fn PageRowState::styled(self : PageRowState) -> Bool {
  (self.0 & RowStyledBit) != 0
}

///|
pub fn PageRowState::with_styled(
  self : PageRowState,
  value : Bool,
) -> PageRowState {
  self.with_bit(RowStyledBit, value)
}

///|
pub fn PageRowState::hyperlink(self : PageRowState) -> Bool {
  (self.0 & RowHyperlinkBit) != 0
}

///|
pub fn PageRowState::with_hyperlink(
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
pub fn PageRowState::with_semantic_prompt(
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
pub fn PageRowState::with_kitty_virtual_placeholder(
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
pub fn PageRowState::with_dirty(
  self : PageRowState,
  value : Bool,
) -> PageRowState {
  self.with_bit(RowDirtyBit, value)
}

///|
pub fn PageRowState::managed_memory(self : PageRowState) -> Bool {
  (self.0 & (RowStyledBit | RowHyperlinkBit | RowGraphemeBit)) != 0
}

///|
/// Whether two row descriptors are equal ignoring the `dirty` bit. `dirty` tracks
/// render bookkeeping rather than row content, so the render-damage diff compares
/// descriptors with it masked out (it forces the bit on in both sides).
pub fn PageRowState::equals_ignoring_dirty(
  self : PageRowState,
  other : PageRowState,
) -> Bool {
  (self.0 | RowDirtyBit) == (other.0 | RowDirtyBit)
}

///|
// The codepoint of a cell with no glyph. U+0000 (NUL) is never a displayable
// character — terminals discard a printed NUL — so it is the conventional
// "empty cell" sentinel (upstream Ghostty uses it the same way). Kept as a named
// scalar rather than `UInt?` so the cell stays allocation-free and value-typed.
const EmptyCodepoint : UInt = 0

///|
// `wide` (2 bits), `protected` (1 bit), `hyperlink_present` (1 bit), and
// `semantic_content` (2 bits) packed into one 6-bit field, mirroring how upstream
// Ghostty bit-packs these flags inside its `u64` cell. `PageCellState` stores this
// value in bits [53, 59) of its word; `PageCellFlags` owns the decode/encode of
// the individual flags. The field order (wide, protected, hyperlink, semantic)
// matches upstream's cell.
//
//   bit 0-1 : wide              (Narrow=0 Wide=1 SpacerTail=2 SpacerHead=3)
//   bit 2   : protected
//   bit 3   : hyperlink_present (the cell is part of a hyperlink; the actual
//             `HyperlinkId` lives in a per-row side array, not in the cell — see
//             `ScreenGridState.link_ids`)
//   bit 4-5 : semantic_content  (Output=0 Input=1 Prompt=2)
struct PageCellFlags(Int) derive(Eq, Debug)

///|
const CellWideMask : Int = 0x03

///|
const CellProtectedBit : Int = 0x04

///|
const CellHyperlinkBit : Int = 0x08

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
fn PageCellFlags::with_hyperlink_present(
  self : PageCellFlags,
  value : Bool,
) -> PageCellFlags {
  if value {
    PageCellFlags(self.0 | CellHyperlinkBit)
  } else {
    PageCellFlags(self.0 & CellHyperlinkBit.lnot())
  }
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
// A cell is an immutable, flat `u64` value — upstream Ghostty's `packed
// struct(u64)` cell. All writes go through the `with_*` builders / `pack`, which
// return a new `u64` the grid stores back into its slot; nothing mutates in
// place, so a cell copies as a single 8-byte word with no refcount and a row of
// them is a contiguous scalar buffer (`FixedArray[PageCellState]` is a flat
// `u64` array). A newtype-over-`UInt64` is already a transparent scalar, so this
// needs no `#valtype`.
//
// Bit layout (LSB first), 59 of 64 bits used:
//   [0, 21)  codepoint   (21 bits — full Unicode scalar range)
//   [21, 37) style_id    (16 bits — index into the screen's StyleTable)
//   [37, 53) grapheme_id (16 bits — index into the screen's GraphemeTable)
//   [53, 59) flags       ( 6 bits — wide 2, protected 1, hyperlink 1, semantic 2)
// The hyperlink is a presence *bit* only; its `HyperlinkId` lives in a per-row
// side array (`ScreenGridState.link_ids`), since it can accumulate unboundedly
// (e.g. `ls --hyperlink`) and so cannot fit a fixed 16-bit field in the word.
struct PageCellState(UInt64) derive(Eq, Debug)

///|
const CellCodepointMask : UInt64 = 0x1F_FFFF

///|
const CellStyleShift : Int = 21

///|
const CellGraphemeShift : Int = 37

///|
// Shared 16-bit mask for the style and grapheme id fields.
const CellIdMask : UInt64 = 0xFFFF

///|
const CellFlagsShift : Int = 53

///|
const CellFlagsMask : UInt64 = 0x3F

///|
// Pack the four fields into the `u64` cell. The single point where a cell is
// minted from components — `new` and `write_cell` route through here.
fn PageCellState::pack(
  codepoint : UInt,
  grapheme_id : GraphemeId,
  style_id : @style.StyleId,
  flags : PageCellFlags,
) -> PageCellState {
  PageCellState(
    (codepoint.to_uint64() & CellCodepointMask) |
    ((style_id.to_uint16().to_uint64() & CellIdMask) << CellStyleShift) |
    ((grapheme_id.0.to_uint64() & CellIdMask) << CellGraphemeShift) |
    ((flags.0.to_uint64() & CellFlagsMask) << CellFlagsShift),
  )
}

///|
// Replace the bits of one field (given its mask and shift) with `value`, leaving
// the rest of the word untouched — the primitive the single-field `with_*`
// builders share.
fn PageCellState::with_field(
  self : PageCellState,
  mask : UInt64,
  shift : Int,
  value : UInt64,
) -> PageCellState {
  let clear = (mask << shift) ^ 0xFFFF_FFFF_FFFF_FFFF
  PageCellState((self.0 & clear) | ((value & mask) << shift))
}

///|
// The cell's packed flag bits as a `PageCellFlags`. The decode/encode of
// wide/protected/hyperlink/semantic still lives in `PageCellFlags`; the cell just
// stores its 6-bit value in place.
fn PageCellState::flags(self : PageCellState) -> PageCellFlags {
  PageCellFlags(((self.0 >> CellFlagsShift) & CellFlagsMask).to_int())
}

///|
fn PageCellState::with_flags(
  self : PageCellState,
  flags : PageCellFlags,
) -> PageCellState {
  self.with_field(CellFlagsMask, CellFlagsShift, flags.0.to_uint64())
}

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
  hyperlink_present? : Bool = false,
  semantic_content? : SemanticContent = Output,
) -> PageCellState {
  PageCellState::pack(
    codepoint,
    // `grapheme` only ever flags an *empty* cluster here (marks are appended
    // later through the grid), so the reserved empty id sets it with no table.
    if grapheme {
      empty_grapheme_id
    } else {
      no_grapheme_id
    },
    style_id,
    PageCellFlags::pack(wide, protected_flag, semantic_content).with_hyperlink_present(
      hyperlink_present,
    ),
  )
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
  self
  .with_field(CellCodepointMask, 0, codepoint.to_uint64())
  .with_grapheme_id(if grapheme { empty_grapheme_id } else { no_grapheme_id })
}

///|
pub fn PageCellState::codepoint(self : PageCellState) -> UInt {
  (self.0 & CellCodepointMask).to_uint()
}

///|
// The cell's style id into the screen's `StyleTable`. Resolution to a concrete
// `CellStyle` (and thus `palette_index`/`background_rgb`/the full style) is done
// by the grid/screen that owns the table — see `ScreenGridState::cell_style`.
pub fn PageCellState::style_id(self : PageCellState) -> @style.StyleId {
  @style.StyleId::from_uint16(
    ((self.0 >> CellStyleShift) & CellIdMask).to_uint16(),
  )
}

///|
// A single shared blank cell value (the zero `u64`). A cell is a flat value, so
// every empty slot just holds this word — a cleared/scrolled-in row is a scalar
// fill, with no per-cell allocation.
pub let default_page_cell_state : PageCellState = PageCellState::new()

///|
pub fn PageCellState::with_style_id(
  self : PageCellState,
  style_id : @style.StyleId,
) -> PageCellState {
  // Swap in a new style id (a 16-bit value); the style itself lives in the table.
  self.with_field(CellIdMask, CellStyleShift, style_id.to_uint16().to_uint64())
}

///|
pub fn PageCellState::wide(self : PageCellState) -> PageCellWide {
  // Decode the 2-bit wide field directly from the packed word (flags window at
  // CellFlagsShift, wide in its low CellWideMask bits) instead of routing through
  // flags() + PageCellFlags::wide(); the single-level match folds in at the call
  // site like has_grapheme/has_styling.
  match ((self.0 >> CellFlagsShift) & CellWideMask.to_uint64()).to_int() {
    1 => Wide
    2 => SpacerTail
    3 => SpacerHead
    _ => Narrow
  }
}

///|
pub fn PageCellState::with_wide(
  self : PageCellState,
  value : PageCellWide,
) -> PageCellState {
  self.with_flags(self.flags().with_wide(value))
}

///|
pub fn PageCellState::is_protected(self : PageCellState) -> Bool {
  self.flags().is_protected()
}

///|
pub fn PageCellState::with_protected(
  self : PageCellState,
  value : Bool,
) -> PageCellState {
  self.with_flags(self.flags().with_protected(value))
}

///|
// Whether this cell is part of a hyperlink. A single flag-bit test — no table
// lookup. The actual `HyperlinkId` lives in the owning grid/row's `link_ids` side
// array, resolved by position via `ScreenGridState::cell_hyperlink`.
pub fn PageCellState::has_hyperlink(self : PageCellState) -> Bool {
  // Direct test of the absolute hyperlink bit (CellHyperlinkBit 0x08 inside the
  // flags window at CellFlagsShift 53 → bit 56), matching the single-expression
  // shape of has_grapheme/has_styling so the cross-package inliner folds it in
  // rather than emitting an out-of-line flags() + PageCellFlags::has_hyperlink.
  (self.0 & (1UL << (CellFlagsShift + 3))) != 0UL
}

///|
// Set/clear the hyperlink-presence bit. The id itself is stored separately, keyed
// by the cell's column, in the owning grid/row's `link_ids` array.
pub fn PageCellState::with_hyperlink_present(
  self : PageCellState,
  value : Bool,
) -> PageCellState {
  self.with_flags(self.flags().with_hyperlink_present(value))
}

///|
pub fn PageCellState::semantic_content(self : PageCellState) -> SemanticContent {
  self.flags().semantic_content()
}

///|
pub fn PageCellState::is_zero(self : PageCellState) -> Bool {
  self == default_page_cell_state
}

///|
pub fn PageCellState::has_text(self : PageCellState) -> Bool {
  self.codepoint() != EmptyCodepoint
}

///|
pub fn PageCellState::grid_width(self : PageCellState) -> Int {
  match self.flags().wide() {
    Narrow | SpacerHead | SpacerTail => 1
    Wide => 2
  }
}

///|
pub fn PageCellState::has_styling(self : PageCellState) -> Bool {
  // The style id is the default (0) exactly when the cell is unstyled, so this is
  // a single field test against the 16-bit style window — like Ghostty's
  // `style_id != default_id`.
  ((self.0 >> CellStyleShift) & CellIdMask) != 0UL
}

///|
pub fn PageCellState::is_empty(self : PageCellState) -> Bool {
  // Note: a cell carrying only a background color is now "empty" here (no glyph)
  // but `has_styling()` is true, so trim/emit sites use `!is_empty() ||
  // has_styling()` to keep it.
  self.codepoint() == EmptyCodepoint && self.flags().wide() == Narrow
}

///|
pub fn PageCellState::has_grapheme(self : PageCellState) -> Bool {
  ((self.0 >> CellGraphemeShift) & CellIdMask) != 0UL
}

///|
// The cell's grapheme id. The combining codepoints themselves are resolved by the
// grid/screen that owns the table — see `ScreenGridState::cell_grapheme_codepoints`.
pub fn PageCellState::grapheme_id(self : PageCellState) -> GraphemeId {
  GraphemeId(((self.0 >> CellGraphemeShift) & CellIdMask).to_uint16())
}

///|
pub fn PageCellState::with_grapheme_id(
  self : PageCellState,
  value : GraphemeId,
) -> PageCellState {
  self.with_field(CellIdMask, CellGraphemeShift, value.0.to_uint64())
}
