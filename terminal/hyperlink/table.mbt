///|
/// A resolved hyperlink: the URI plus its OSC 8 id (explicit `id=` param, or an
/// implicit per-anchor id when none was given). Lives with the hyperlink intern
/// table rather than the cell, since the cell carries only a presence bit (the
/// id is kept in the grid's per-row `link_ids` side array). Mirrors upstream
/// Ghostty's split between `hyperlink.zig` and the cell in `page.zig`.
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
/// A hyperlink id: a small handle stored in a cell that stands in for a
/// `CellHyperlink`. `0` means "no hyperlink", so the common (linkless) cell needs
/// no table entry and no lookup — only a presence check (`!is_none()`). Real ids
/// start at 1. Mirrors the `StyleId`/`StyleTable` design; see [[StyleTable]].
struct HyperlinkId(UInt16) derive(Eq, Debug, Hash)

///|
/// The id meaning "this cell has no hyperlink".
pub let no_hyperlink_id : HyperlinkId = HyperlinkId(0)

///|
pub fn HyperlinkId::is_none(self : HyperlinkId) -> Bool {
  self.0 == 0
}

///|
/// A grow-only, content-addressed intern table mapping each distinct
/// `CellHyperlink` to a `HyperlinkId` and back. Like `StyleTable`, it never
/// reclaims (distinct hyperlinks are rare and bounded in practice) and is
/// position-independent: all cells under one OSC 8 link share the same
/// `CellHyperlink` value, so they intern to one id that stays valid as their row
/// scrolls into history. One table is shared across a `PageList`'s active page
/// and scrollback.
pub struct HyperlinkTable {
  // Real entries, id-1 indexed: `list[id - 1]` is the hyperlink for id >= 1.
  // There is no entry for id 0 (it means "no hyperlink").
  priv list : Array[CellHyperlink]
  // Reverse map for dedup.
  priv index : Map[CellHyperlink, HyperlinkId]
  // One-entry cache of the last interned link — a run of cells under one OSC 8
  // link interns with a single struct compare instead of re-hashing per cell.
  priv mut last_link : CellHyperlink?
  priv mut last_id : HyperlinkId
}

///|
pub fn HyperlinkTable::new() -> HyperlinkTable {
  { list: [], index: Map([]), last_link: None, last_id: no_hyperlink_id }
}

///|
/// Intern an optional hyperlink, returning its id. `None` is the free fast path
/// (no hash) and yields `no_hyperlink_id`; a real link is deduped by content.
pub fn HyperlinkTable::intern(
  self : HyperlinkTable,
  hyperlink : CellHyperlink?,
) -> HyperlinkId {
  guard hyperlink is Some(link) else { no_hyperlink_id }
  if self.last_link is Some(last) && last == link {
    return self.last_id
  }
  let id = if self.index.get(link) is Some(id) {
    id
  } else {
    // Ids are 16 bit. Once all 65 535 real ids are spent, `(length + 1)
    // .to_uint16()` would wrap (the first overflow lands on 0 = "no link", later
    // ones collide with earlier links). Degrade instead: drop the link on further
    // distinct uris — the cell renders unlinked rather than resolving to a wrong
    // uri. (65 k distinct links in one session is already pathological; the
    // side-array id could be widened past 16 bits if this ever bites.)
    if self.list.length() + 1 > 0xFFFF {
      return no_hyperlink_id
    }
    // id is 1-based: the new entry lands at the current length, so its id is
    // length + 1 (id 0 is reserved for "no hyperlink").
    let id = HyperlinkId((self.list.length() + 1).to_uint16())
    self.list.push(link)
    self.index[link] = id
    id
  }
  self.last_link = Some(link)
  self.last_id = id
  id
}

///|
/// Resolve an id back to its hyperlink. `no_hyperlink_id` resolves to `None`.
pub fn HyperlinkTable::get(
  self : HyperlinkTable,
  id : HyperlinkId,
) -> CellHyperlink? {
  if id.is_none() {
    None
  } else {
    Some(self.list[id.0.to_int() - 1])
  }
}
