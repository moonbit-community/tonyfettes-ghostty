///|
/// A style id: a small integer handle that stands in for a `CellStyle` inside a
/// cell. `0` is always the default (unstyled) style, so a blank cell needs no
/// table lookup. Stored as a `UInt16`, matching upstream Ghostty's `style.Id`
/// and leaving room for the eventual packed `u64` cell where the id occupies 16
/// bits. `pub` (not `pub(all)`) so other packages can carry/read it but only
/// `StyleTable` mints one.
struct StyleId(UInt16) derive(Eq, Debug, Hash)

///|
/// The default style id. A fresh cell starts here and resolving it always yields
/// `CellStyle::new()` with no allocation.
pub let default_style_id : StyleId = StyleId(0)

///|
pub fn StyleId::to_uint16(self : StyleId) -> UInt16 {
  self.0
}

///|
/// Reconstruct a `StyleId` from its raw 16-bit value. The inverse of
/// `to_uint16`, for callers that pack the id into a wider word (the `u64` cell)
/// and need to unpack it. The value must be one this table minted (or 0); ids are
/// never reclaimed, so any minted value stays valid.
pub fn StyleId::from_uint16(value : UInt16) -> StyleId {
  StyleId(value)
}

///|
pub fn StyleId::is_default(self : StyleId) -> Bool {
  self.0 == 0
}

///|
/// A grow-only, content-addressed intern table mapping each distinct `CellStyle`
/// to a `StyleId` and back. Mirrors upstream Ghostty's per-page style `Set`, but
/// WITHOUT refcounting: an id is assigned the first time a style is seen and is
/// never reclaimed until the whole table is reset. Distinct styles in a real
/// session are bounded (dozens to low hundreds), so the memory is negligible and
/// we skip the entire refcount-lifecycle that a release-on-overwrite scheme would
/// impose on every cell write/erase/scroll.
///
/// Because ids are content-addressed they are position-independent: a cell keeps
/// the same id when its row scrolls into history, so one table shared across a
/// `PageList`'s active page and scrollback is always consistent.
pub struct StyleTable {
  // Indexed by id: `list[id]` is the style. `list[0]` is always the default.
  priv list : Array[CellStyle]
  // Reverse map for dedup: style -> existing id.
  priv index : Map[CellStyle, StyleId]
  // One-entry cache of the last non-default style interned. A printed run of
  // identically-styled cells (the common case for any SGR span) then interns with
  // a single struct compare instead of re-hashing the same style per cell.
  priv mut last_style : CellStyle
  priv mut last_id : StyleId
}

///|
pub fn StyleTable::new() -> StyleTable {
  let default = CellStyle::new()
  let index : Map[CellStyle, StyleId] = Map([])
  index[default] = default_style_id
  { list: [default], index, last_style: default, last_id: default_style_id }
}

///|
/// Intern `style`, returning its id. Idempotent: the same style always maps to
/// the same id for the life of the table. The default style is never re-inserted
/// (it is pre-seeded at id 0), so unstyled writes hit the map's fast path.
pub fn StyleTable::intern(self : StyleTable, style : CellStyle) -> StyleId {
  // Fast path for the default style — the overwhelmingly common case (every
  // unstyled cell). `is_default` is a few integer compares, avoiding the hash of
  // the reverse map that the general path pays. Without this, plain-text printing
  // hashes a `CellStyle` per cell.
  if style.is_default() {
    return default_style_id
  }
  // Run-of-same-style fast path: avoids the reverse-map hash when consecutive
  // cells share a style (the usual case within an SGR span).
  if style == self.last_style {
    return self.last_id
  }
  let id = match self.index.get(style) {
    Some(id) => id
    None => {
      // Ids are 16 bit (they pack into the `u64` cell). Once all 65 536 are spent,
      // minting `length.to_uint16()` would wrap to an existing id and silently
      // resolve later cells to the wrong style. Degrade instead: map further
      // distinct styles to the default (unstyled) id — a visible loss, but never a
      // wrong color. (65 k distinct styles in one session is already pathological.)
      if self.list.length() > 0xFFFF {
        return default_style_id
      }
      let id = StyleId(self.list.length().to_uint16())
      self.list.push(style)
      self.index[style] = id
      id
    }
  }
  self.last_style = style
  self.last_id = id
  id
}

///|
/// Resolve an id back to its `CellStyle`. The id must have come from this table
/// (or be `default_style_id`); ids are never reclaimed, so any minted id stays
/// valid for the table's life.
pub fn StyleTable::get(self : StyleTable, id : StyleId) -> CellStyle {
  self.list[id.0.to_int()]
}

///|
/// Number of distinct styles interned so far (including the default). Exposed for
/// tests and capacity diagnostics.
pub fn StyleTable::len(self : StyleTable) -> Int {
  self.list.length()
}
