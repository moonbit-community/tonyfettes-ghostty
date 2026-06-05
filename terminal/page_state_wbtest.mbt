///|
test "page cell state/append_grapheme combines combining codepoints" {
  // Base: 'e' (U+0065) + combining acute accent (U+0301) → é
  let cell = PageCellState::init(0x65U)
  guard !cell.has_grapheme() && cell.grapheme_codepoints() == [] else {
    fail("expected no grapheme before append")
  }

  cell.append_grapheme(0x301U)
  guard cell.has_grapheme() &&
    cell.codepoint() == 0x65U &&
    cell.grapheme_codepoints() == [0x301U] else {
    fail("expected single combining codepoint after first append")
  }

  // Second combining codepoint accumulates
  cell.append_grapheme(0x300U)
  guard cell.grapheme_codepoints() == [0x301U, 0x300U] else {
    fail("expected two combining codepoints after second append")
  }

  // set_codepoint clears grapheme extras
  cell.set_codepoint(0x61U, false)
  guard !cell.has_grapheme() && cell.grapheme_codepoints() == [] else {
    fail("expected grapheme cleared after set_codepoint")
  }
}

///|
test "page cell state/full_reset clears grapheme extras" {
  let cell = PageCellState::init(0x41U)
  cell.append_grapheme(0x301U)
  guard cell.has_grapheme() else {
    fail("precondition: cell should have grapheme")
  }
  cell.full_reset()
  guard !cell.has_grapheme() &&
    cell.grapheme_codepoints() == [] &&
    cell.content() is Codepoint(_) else {
    fail("expected full_reset to clear grapheme extras")
  }
}
