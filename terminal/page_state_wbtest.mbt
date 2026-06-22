///|
test "page cell state/append_grapheme combines combining codepoints" {
  // The extras live in a `GraphemeTable` now; the cell holds an id. Appending is
  // `GraphemeTable::append` (the old `with_grapheme_appended`), resolution is
  // `get`.
  let graphemes = GraphemeTable::new()
  // Base: 'e' (U+0065) + combining acute accent (U+0301) → é
  let mut cell = PageCellState::init(0x65U)
  guard !cell.has_grapheme() && graphemes.get(cell.grapheme_id()) == [] else {
    fail("expected no grapheme before append")
  }

  cell = cell.with_grapheme_id(graphemes.append(cell.grapheme_id(), 0x301U))
  guard cell.has_grapheme() &&
    cell.codepoint() == 0x65U &&
    graphemes.get(cell.grapheme_id()) == [0x301U] else {
    fail("expected single combining codepoint after first append")
  }

  // Second combining codepoint accumulates
  cell = cell.with_grapheme_id(graphemes.append(cell.grapheme_id(), 0x300U))
  guard graphemes.get(cell.grapheme_id()) == [0x301U, 0x300U] else {
    fail("expected two combining codepoints after second append")
  }

  // with_codepoint clears grapheme extras (id back to none)
  cell = cell.with_codepoint(0x61U, false)
  guard !cell.has_grapheme() && graphemes.get(cell.grapheme_id()) == [] else {
    fail("expected grapheme cleared after with_codepoint")
  }
}

///|
test "page cell state/a fresh cell has no grapheme extras" {
  let graphemes = GraphemeTable::new()
  let mut cell = PageCellState::init(0x41U)
  cell = cell.with_grapheme_id(graphemes.append(cell.grapheme_id(), 0x301U))
  guard cell.has_grapheme() else {
    fail("precondition: cell should have grapheme")
  }
  // A blank cell is a fresh value (full_reset is gone); it carries no extras.
  cell = PageCellState::new()
  guard !cell.has_grapheme() &&
    graphemes.get(cell.grapheme_id()) == [] &&
    cell.codepoint() == 0U else {
    fail("expected a fresh cell to have no grapheme extras")
  }
}

///|
/// White-box: the `with_*` builders are package-private (no external caller sets
/// row flags), so this exercises the `Int` bitfield packing/unpacking directly.
test "page row state/with builders pack and unpack flags" {
  let row = PageRowState::new()
    .with_wrap(true)
    .with_wrap_continuation(true)
    .with_grapheme(true)
    .with_styled(true)
    .with_hyperlink(true)
    .with_semantic_prompt(PromptContinuation)
    .with_kitty_virtual_placeholder(true)
    .with_dirty(true)
  guard row.wrap() &&
    row.wrap_continuation() &&
    row.grapheme() &&
    row.styled() &&
    row.hyperlink() &&
    row.semantic_prompt() == PromptContinuation &&
    row.kitty_virtual_placeholder() &&
    row.dirty() &&
    row.managed_memory() else {
    fail("expected every flag set")
  }

  // Clearing one bit leaves the others untouched.
  let cleared = row.with_styled(false).with_semantic_prompt(Prompt)
  guard cleared.wrap() &&
    !cleared.styled() &&
    cleared.hyperlink() &&
    cleared.semantic_prompt() == Prompt &&
    cleared.managed_memory() else {
    fail("expected a single-bit clear to preserve the rest")
  }

  // A fresh descriptor is the all-zero value (the old `full_reset`).
  let blank = PageRowState::new()
  guard !blank.wrap() &&
    !blank.dirty() &&
    blank.semantic_prompt() == None &&
    !blank.managed_memory() else {
    fail("expected a blank descriptor to clear every flag")
  }
}

///|
test "hyperlink table interns, dedups runs, and round-trips through a cell" {
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

  // The id round-trips through a cell and resolves back to the link.
  let cell = PageCellState::new().with_hyperlink_id(id)
  guard cell.has_hyperlink() &&
    cell.hyperlink_id() == id &&
    table.get(cell.hyperlink_id()) == Some(link) else {
    fail("cell hyperlink id must resolve back to the interned link")
  }

  // A cell with the no-hyperlink id reports no link.
  let blank = PageCellState::new()
  guard !blank.has_hyperlink() && table.get(blank.hyperlink_id()) == None else {
    fail("a fresh cell must carry no hyperlink")
  }
}
