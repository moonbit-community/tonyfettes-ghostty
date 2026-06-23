///|
/// A grapheme id stored in a cell, standing in for the cell's combining-codepoint
/// extras. `0` means "not a grapheme cell" (no combining marks). `1` is reserved
/// for "a grapheme cell whose extras are empty" — the transient state a cell is
/// in between being flagged as a cluster and its first mark arriving — so that
/// flag can be set without touching the table. Ids `>= 2` index real extras.
/// Mirrors `StyleId`/`HyperlinkId`; see [[StyleTable]].
struct GraphemeId(UInt16) derive(Eq, Debug, Hash)

///|
/// The id meaning "this cell has no combining codepoints".
let no_grapheme_id : GraphemeId = GraphemeId(0)

///|
/// The id meaning "this cell is a grapheme cluster but carries no marks yet".
/// Every `GraphemeTable` resolves it to the empty array, so it is a constant a
/// cell builder can set without a table.
let empty_grapheme_id : GraphemeId = GraphemeId(1)

///|
fn GraphemeId::is_none(self : GraphemeId) -> Bool {
  self.0 == 0
}

///|
/// A grow-only, content-addressed intern table mapping each distinct combining
/// run (`ReadOnlyArray[UInt]`) to a `GraphemeId` and back. Like the style and
/// hyperlink tables it never reclaims and is position-independent, so a cell's id
/// stays valid as its row scrolls into history. The empty run is pre-seeded at id
/// 1 (`empty_grapheme_id`); real runs get ids from 2.
priv struct GraphemeTable {
  // id-1 indexed: `list[id - 1]` is the extras for id >= 1. `list[0]` is the
  // empty run (id 1). There is no entry for id 0 ("not a grapheme cell").
  list : Array[ReadOnlyArray[UInt]]
  index : Map[ReadOnlyArray[UInt], GraphemeId]
  // One-entry cache of the last interned run.
  mut last_extras : ReadOnlyArray[UInt]?
  mut last_id : GraphemeId
}

///|
fn GraphemeTable::new() -> GraphemeTable {
  let empty : ReadOnlyArray[UInt] = []
  let index : Map[ReadOnlyArray[UInt], GraphemeId] = Map([])
  index[empty] = empty_grapheme_id
  { list: [empty], index, last_extras: None, last_id: no_grapheme_id }
}

///|
/// Intern a combining run, returning its id (always >= 1; the empty run is id 1).
fn GraphemeTable::intern(
  self : GraphemeTable,
  extras : ReadOnlyArray[UInt],
) -> GraphemeId {
  if self.last_extras is Some(last) && last == extras {
    return self.last_id
  }
  let id = match self.index.get(extras) {
    Some(id) => id
    None => {
      // Ids are 16 bit (they pack into the `u64` cell). Once all are spent, `(length
      // + 1).to_uint16()` would wrap to 0 ("not a grapheme") or an earlier id, so a
      // copied/formatted cell would lose its marks or resolve to an unrelated run.
      // Degrade instead: map further distinct runs to `no_grapheme_id` — the base
      // codepoint still renders, only the combining marks are dropped. (65 k
      // distinct clusters in one session is already pathological.)
      if self.list.length() + 1 > 0xFFFF {
        return no_grapheme_id
      }
      // New run lands at the current length; its id is length + 1 (id 0 is
      // reserved for "not a grapheme cell", id 1 for the pre-seeded empty run).
      let id = GraphemeId((self.list.length() + 1).to_uint16())
      self.list.push(extras)
      self.index[extras] = id
      id
    }
  }
  self.last_extras = Some(extras)
  self.last_id = id
  id
}

///|
/// Resolve an id to its combining run. `no_grapheme_id` (and the empty run id)
/// resolve to the empty array.
fn GraphemeTable::get(
  self : GraphemeTable,
  id : GraphemeId,
) -> ReadOnlyArray[UInt] {
  if id.is_none() {
    []
  } else {
    self.list[id.0.to_int() - 1]
  }
}

///|
/// Return the id for `id`'s run extended by one more combining codepoint. Reads
/// the current extras, appends, and interns the result — the table counterpart to
/// the old `PageCellState::with_grapheme_appended`.
fn GraphemeTable::append(
  self : GraphemeTable,
  id : GraphemeId,
  codepoint : UInt,
) -> GraphemeId {
  let existing = self.get(id)
  // Build a fresh array so interned runs never share mutable storage.
  let extras : Array[UInt] = Array::make(existing.length() + 1, codepoint)
  for index in 0..<existing.length() {
    extras[index] = existing.at(index)
  }
  self.intern(ReadOnlyArray::from_array(extras))
}
