///|
test "hyperlink table interns, dedups runs, and the cell carries a presence bit" {
  let table = HyperlinkTable::new()
  // None is the free fast path: no entry, id 0, resolves back to None.
  let none_id = table.intern(None)
  guard none_id.is_none() && table.get(none_id) == None else {
    fail("None must intern to the no-hyperlink id")
  }

  // A real link gets a non-zero id; the same link (a run under one OSC 8 span)
  // re-interns to the same id.
  let link = CellHyperlink::implicit("https://example.com", 7)
  let id = table.intern(Some(link))
  guard !id.is_none() && table.intern(Some(link)) == id else {
    fail("re-interning the same link must be idempotent")
  }

  // A distinct link gets a distinct id.
  let other = CellHyperlink::explicit("https://other.example", "x")
  let other_id = table.intern(Some(other))
  guard other_id != id else { fail("distinct links must get distinct ids") }

  // The interned id resolves back to its link through the table. (The id is
  // stored in the grid's per-row `link_ids` side array, not in the cell — the
  // cell carries only a presence bit; see the grid round-trip test.)
  guard table.get(id) == Some(link) else {
    fail("interned hyperlink id must resolve back to its link")
  }

  // The cell records hyperlink membership as a flag bit, independent of any id.
  let cell = @page.PageCellState::new().with_hyperlink_present(true)
  guard cell.has_hyperlink() else {
    fail("with_hyperlink_present must set the cell's presence bit")
  }

  // A fresh cell reports no link.
  let blank = @page.PageCellState::new()
  guard !blank.has_hyperlink() else {
    fail("a fresh cell must carry no hyperlink")
  }
}
