///|
test "page cell state/append_grapheme combines combining codepoints" {
  // Base: 'e' (U+0065) + combining acute accent (U+0301) → é
  let mut cell = PageCellState::init(0x65U)
  guard !cell.has_grapheme() && cell.grapheme_codepoints() == [] else {
    fail("expected no grapheme before append")
  }

  cell = cell.with_grapheme_appended(0x301U)
  guard cell.has_grapheme() &&
    cell.codepoint() == 0x65U &&
    cell.grapheme_codepoints() == [0x301U] else {
    fail("expected single combining codepoint after first append")
  }

  // Second combining codepoint accumulates
  cell = cell.with_grapheme_appended(0x300U)
  guard cell.grapheme_codepoints() == [0x301U, 0x300U] else {
    fail("expected two combining codepoints after second append")
  }

  // with_codepoint clears grapheme extras
  cell = cell.with_codepoint(0x61U, false)
  guard !cell.has_grapheme() && cell.grapheme_codepoints() == [] else {
    fail("expected grapheme cleared after with_codepoint")
  }
}

///|
test "page cell state/a fresh cell has no grapheme extras" {
  let mut cell = PageCellState::init(0x41U)
  cell = cell.with_grapheme_appended(0x301U)
  guard cell.has_grapheme() else {
    fail("precondition: cell should have grapheme")
  }
  // A blank cell is a fresh value (full_reset is gone); it carries no extras.
  cell = PageCellState::new()
  guard !cell.has_grapheme() &&
    cell.grapheme_codepoints() == [] &&
    cell.content() is Codepoint(_) else {
    fail("expected a fresh cell to have no grapheme extras")
  }
}
