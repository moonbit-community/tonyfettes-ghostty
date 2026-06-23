///|
test "hyperlink table interns and dedups runs" {
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

  // The interned id resolves back to its link through the table. (The id itself
  // is stored in the grid's per-row `link_ids` side array, not in the cell.)
  guard table.get(id) == Some(link) else {
    fail("interned hyperlink id must resolve back to its link")
  }
}

///|
test "cell hyperlink constructors preserve explicit and implicit ids" {
  let explicit = CellHyperlink::explicit("https://a.example", "id-1")
  guard explicit.uri() == "https://a.example" &&
    explicit.explicit_id() == Some("id-1") &&
    explicit.implicit_id() == None else {
    fail("expected explicit hyperlink payload")
  }
  let implicit = CellHyperlink::implicit("https://b.example", 4)
  guard implicit.uri() == "https://b.example" &&
    implicit.explicit_id() == None &&
    implicit.implicit_id() == Some(4) else {
    fail("expected implicit hyperlink payload")
  }
}
