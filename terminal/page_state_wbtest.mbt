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
