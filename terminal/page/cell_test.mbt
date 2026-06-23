///|
test "page cell state/append_grapheme combines combining codepoints" {
  // The extras live in a `GraphemeTable`; the cell holds an id. Appending is
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
  // A blank cell is a fresh value; it carries no extras.
  cell = PageCellState::new()
  guard !cell.has_grapheme() &&
    graphemes.get(cell.grapheme_id()) == [] &&
    cell.codepoint() == 0U else {
    fail("expected a fresh cell to have no grapheme extras")
  }
}

///|
test "page row state/with builders pack and unpack flags" {
  // The `with_*` builders pack each flag into the `Int` bitfield; this checks the
  // full round-trip through every accessor.
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

  // A fresh descriptor is the all-zero value.
  let blank = PageRowState::new()
  guard !blank.wrap() &&
    !blank.dirty() &&
    blank.semantic_prompt() == None &&
    !blank.managed_memory() else {
    fail("expected a blank descriptor to clear every flag")
  }

  // `dirty` is bookkeeping, not content: two descriptors differing only in it
  // compare equal under `equals_ignoring_dirty` (the render-damage diff's check).
  guard row.equals_ignoring_dirty(row.with_dirty(false)) &&
    row.with_dirty(false) != row else {
    fail("expected equals_ignoring_dirty to mask the dirty bit")
  }
}

///|
test "page row state/defaults and managed memory" {
  let row = PageRowState::new()
  guard !row.wrap() &&
    !row.wrap_continuation() &&
    !row.grapheme() &&
    !row.styled() &&
    !row.hyperlink() &&
    row.semantic_prompt() == None &&
    !row.kitty_virtual_placeholder() &&
    !row.dirty() &&
    !row.managed_memory() else {
    fail("expected default page row state")
  }
}

///|
test "page cell state/defaults and zero helpers" {
  let cell = PageCellState::new()
  guard cell.codepoint() == 0U &&
    cell.style_id().is_default() &&
    cell.wide() == Narrow &&
    !cell.is_protected() &&
    !cell.has_hyperlink() &&
    cell.semantic_content() == Output &&
    cell.is_zero() &&
    !cell.has_text() &&
    !cell.has_styling() &&
    cell.is_empty() &&
    !cell.has_grapheme() &&
    cell.grid_width() == 1 else {
    fail("expected default page cell state")
  }
}

///|
test "page cell state/codepoint grapheme and wide helpers" {
  let mut cell = PageCellState::init(0x41U)
  guard cell.codepoint() == 0x41U &&
    cell.has_text() &&
    !cell.has_grapheme() &&
    cell.is_empty() == false else {
    fail("expected basic codepoint cell")
  }
  cell = cell.with_codepoint(0x62U, true).with_wide(Wide)
  guard cell.codepoint() == 0x62U &&
    cell.has_text() &&
    cell.has_grapheme() &&
    cell.grid_width() == 2 else {
    fail("expected grapheme and wide state")
  }
  cell = cell.with_codepoint(0U, false).with_wide(SpacerHead)
  guard !cell.is_empty() && cell.grid_width() == 1 else {
    fail("expected spacer head to remain non-empty")
  }
}

///|
test "page cell state/set_codepoint clears grapheme extras" {
  // When set_codepoint is called with a new codepoint, the grapheme flag should
  // clear regardless of its prior state.
  let mut cell = PageCellState::init(0x65U)
  cell = cell.with_codepoint(0x65U, true) // flag grapheme but no extras yet
  guard cell.has_grapheme() else {
    fail("expected grapheme flag set when flagged but no extras")
  }
  cell = cell.with_codepoint(0x61U, false) // overwrite: clears flag and extras
  guard !cell.has_grapheme() else {
    fail("expected grapheme cleared after with_codepoint(_, false)")
  }
}

///|
test "page cell state/hyperlink presence is a flag bit independent of any id" {
  // The cell records hyperlink membership as a flag bit only; the actual id lives
  // in the grid's per-row side array, not the cell.
  let linked = PageCellState::new().with_hyperlink_present(true)
  guard linked.has_hyperlink() else {
    fail("with_hyperlink_present(true) must set the presence bit")
  }
  guard !linked.with_hyperlink_present(false).has_hyperlink() else {
    fail("with_hyperlink_present(false) must clear the presence bit")
  }
  guard !PageCellState::new().has_hyperlink() else {
    fail("a fresh cell must carry no hyperlink")
  }
}

///|
test "page cell state/background color lives in the style" {
  // A background-color cell is a glyph-less cell whose style carries the bg, so
  // it has no text and is `is_empty()` (no glyph) but `has_styling()`.
  let rgb = @color.RGB::new(1, 2, 3)
  let styles = @style.StyleTable::new()
  let palette_cell = PageCellState::new(
    style_id=styles.intern(
      @style.CellStyle::new().with_bg_color(@style.StyleColor::palette(7)),
    ),
  )
  guard styles.get(palette_cell.style_id()).bg_color().palette_index() ==
    Some(7) &&
    styles.get(palette_cell.style_id()).bg_color().rgb_value() == None &&
    !palette_cell.has_text() &&
    palette_cell.is_empty() &&
    palette_cell.has_styling() &&
    palette_cell.codepoint() == 0U else {
    fail("expected palette background carried in the style")
  }
  let rgb_cell = PageCellState::new(
    style_id=styles.intern(
      @style.CellStyle::new().with_bg_color(@style.StyleColor::rgb(rgb)),
    ),
  )
  guard styles.get(rgb_cell.style_id()).bg_color().palette_index() == None &&
    styles.get(rgb_cell.style_id()).bg_color().rgb_value() == Some(rgb) &&
    !rgb_cell.has_text() &&
    rgb_cell.has_styling() else {
    fail("expected rgb background carried in the style")
  }
}

///|
test "page cell state/style protected and semantic round-trip" {
  let mut style = @style.CellStyle::new()
  style = style.apply_attribute(Bold)
  let styles = @style.StyleTable::new()
  let cell = PageCellState::new(
    style_id=styles.intern(style),
    protected_flag=true,
    semantic_content=Prompt,
  )

  // The hyperlink id round-trips through the grid's per-row side array, not the
  // cell; the cell carries only a presence bit (false here).
  guard styles.get(cell.style_id()).bold() &&
    cell.has_styling() &&
    cell.is_protected() &&
    !cell.has_hyperlink() &&
    cell.semantic_content() == Prompt else {
    fail("expected style, protection, and semantic state")
  }

  // A blank cell is just a fresh value.
  let blank = PageCellState::new()
  guard blank.codepoint() == 0U &&
    blank.style_id().is_default() &&
    blank.wide() == Narrow &&
    !blank.is_protected() &&
    !blank.has_hyperlink() &&
    blank.semantic_content() == Output else {
    fail("expected a fresh blank cell")
  }
}
