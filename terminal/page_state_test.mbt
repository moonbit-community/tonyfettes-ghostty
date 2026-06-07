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
test "page row state/flags semantic prompt and full reset" {
  let row = PageRowState::new()
  row.set_wrap(true)
  row.set_wrap_continuation(true)
  row.set_grapheme(true)
  row.set_styled(true)
  row.set_hyperlink(true)
  row.set_semantic_prompt(PromptContinuation)
  row.set_kitty_virtual_placeholder(true)
  row.set_dirty(true)

  guard row.wrap() &&
    row.wrap_continuation() &&
    row.grapheme() &&
    row.styled() &&
    row.hyperlink() &&
    row.semantic_prompt() == PromptContinuation &&
    row.kitty_virtual_placeholder() &&
    row.dirty() &&
    row.managed_memory() else {
    fail("expected mutated page row state")
  }

  row.full_reset()
  guard !row.wrap() &&
    !row.wrap_continuation() &&
    !row.grapheme() &&
    !row.styled() &&
    !row.hyperlink() &&
    row.semantic_prompt() == None &&
    !row.kitty_virtual_placeholder() &&
    !row.dirty() &&
    !row.managed_memory() else {
    fail("expected page row full reset")
  }
}

///|
test "page cell state/defaults and zero helpers" {
  let cell = PageCellState::new()
  guard cell.codepoint() == 0U &&
    cell.palette_index() == None &&
    cell.background_rgb() == None &&
    cell.style().is_default() &&
    cell.wide() == Narrow &&
    !cell.is_protected() &&
    cell.hyperlink() == None &&
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
    cell.grapheme_codepoints() == [] &&
    cell.is_empty() == false else {
    fail("expected basic codepoint cell")
  }

  cell = cell.with_codepoint(0x62U, true).with_wide(Wide)
  guard cell.codepoint() == 0x62U &&
    cell.has_text() &&
    cell.has_grapheme() &&
    cell.grapheme_codepoints() == [] &&
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
  // When set_codepoint is called with a new codepoint, grapheme_codepoints
  // should return [] regardless of the grapheme flag.
  let mut cell = PageCellState::init(0x65U)
  cell = cell.with_codepoint(0x65U, true) // flag grapheme but no extras yet
  guard cell.has_grapheme() && cell.grapheme_codepoints() == [] else {
    fail("expected empty grapheme_codepoints when flagged but no extras")
  }
  cell = cell.with_codepoint(0x61U, false) // overwrite: clears flag and extras
  guard !cell.has_grapheme() && cell.grapheme_codepoints() == [] else {
    fail("expected grapheme cleared after with_codepoint(_, false)")
  }
}

///|
test "page cell state/background content reports no text and preserves payloads" {
  let mut cell = PageCellState::new()
  let rgb = @color.RGB::new(1, 2, 3)
  cell = cell.with_background_palette(7)
  guard cell.palette_index() == Some(7) &&
    cell.background_rgb() == None &&
    !cell.has_text() &&
    !cell.is_empty() &&
    cell.codepoint() == 0U else {
    fail("expected palette background cell state")
  }

  cell = cell.with_background_rgb(rgb)
  guard cell.palette_index() == None &&
    cell.background_rgb() == Some(rgb) &&
    !cell.has_text() &&
    !cell.is_empty() else {
    fail("expected rgb background cell state")
  }
}

///|
test "page cell state/style hyperlink semantic and full reset" {
  let mut cell = PageCellState::new()
  let mut style = @style.CellStyle::new()
  style = style.apply_attribute(Bold)
  let hyperlink = CellHyperlink::implicit("https://example.com", 3)

  cell = cell
    .with_style(style)
    .with_protected(true)
    .with_hyperlink(Some(hyperlink))
    .with_semantic_content(Prompt)

  guard cell.style().bold() &&
    cell.has_styling() &&
    cell.is_protected() &&
    cell.hyperlink() == Some(hyperlink) &&
    cell.semantic_content() == Prompt else {
    fail("expected style, hyperlink, protection, and semantic state")
  }

  // A blank cell is just a fresh value now (full_reset is gone).
  cell = PageCellState::new()
  guard cell.codepoint() == 0U &&
    cell.palette_index() == None &&
    cell.background_rgb() == None &&
    cell.style().is_default() &&
    cell.wide() == Narrow &&
    !cell.is_protected() &&
    cell.hyperlink() == None &&
    cell.semantic_content() == Output else {
    fail("expected page cell full reset")
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
