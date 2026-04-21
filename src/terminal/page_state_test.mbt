///|
test "page row state/defaults and managed memory" {
  let row = PageRowState::new()
  guard !row.wrap() &&
    !row.wrap_continuation() &&
    !row.grapheme() &&
    !row.styled() &&
    !row.hyperlink() &&
    row.semantic_prompt() == RowSemanticPrompt::None &&
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
  row.set_semantic_prompt(RowSemanticPrompt::PromptContinuation)
  row.set_kitty_virtual_placeholder(true)
  row.set_dirty(true)

  guard row.wrap() &&
    row.wrap_continuation() &&
    row.grapheme() &&
    row.styled() &&
    row.hyperlink() &&
    row.semantic_prompt() == RowSemanticPrompt::PromptContinuation &&
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
    row.semantic_prompt() == RowSemanticPrompt::None &&
    !row.kitty_virtual_placeholder() &&
    !row.dirty() &&
    !row.managed_memory() else {
    fail("expected page row full reset")
  }
}

///|
test "page cell state/defaults and zero helpers" {
  let cell = PageCellState::new()
  guard cell.content_tag() == PageCellContentTag::Codepoint &&
    cell.codepoint() == 0U &&
    cell.palette_index() == None &&
    cell.background_rgb() == None &&
    cell.style().is_default() &&
    cell.wide() == PageCellWide::Narrow &&
    !cell.is_protected() &&
    cell.hyperlink() == None &&
    cell.semantic_content() == SemanticContent::Output &&
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
  let cell = PageCellState::init(0x41U)
  guard cell.content_tag() == PageCellContentTag::Codepoint &&
    cell.codepoint() == 0x41U &&
    cell.has_text() &&
    !cell.has_grapheme() &&
    cell.is_empty() == false else {
    fail("expected basic codepoint cell")
  }

  cell.set_codepoint(0x62U, true)
  cell.set_wide(PageCellWide::Wide)
  guard cell.content_tag() == PageCellContentTag::CodepointGrapheme &&
    cell.codepoint() == 0x62U &&
    cell.has_text() &&
    cell.has_grapheme() &&
    cell.grid_width() == 2 else {
    fail("expected grapheme and wide state")
  }

  cell.set_codepoint(0U, false)
  cell.set_wide(PageCellWide::SpacerHead)
  guard !cell.is_empty() && cell.grid_width() == 1 else {
    fail("expected spacer head to remain non-empty")
  }
}

///|
test "page cell state/background content reports no text and preserves payloads" {
  let cell = PageCellState::new()
  let rgb = RGB::new(1, 2, 3)
  cell.set_background_palette(7)
  guard cell.content_tag() == PageCellContentTag::BackgroundPalette &&
    cell.palette_index() == Some(7) &&
    cell.background_rgb() == None &&
    !cell.has_text() &&
    !cell.is_empty() &&
    cell.codepoint() == 0U else {
    fail("expected palette background cell state")
  }

  cell.set_background_rgb(rgb)
  guard cell.content_tag() == PageCellContentTag::BackgroundRgb &&
    cell.palette_index() == None &&
    cell.background_rgb() == Some(rgb) &&
    !cell.has_text() &&
    !cell.is_empty() else {
    fail("expected rgb background cell state")
  }
}

///|
test "page cell state/style hyperlink semantic and full reset" {
  let cell = PageCellState::new()
  let style = CellStyle::new()
  style.apply_attribute(Bold)
  let hyperlink = CellHyperlink::implicit("https://example.com", 3)

  cell.set_style(style)
  cell.set_protected(true)
  cell.set_hyperlink(Some(hyperlink))
  cell.set_semantic_content(SemanticContent::Prompt)

  let style_copy = cell.style()
  guard style_copy.bold() &&
    cell.has_styling() &&
    cell.is_protected() &&
    cell.hyperlink() == Some(hyperlink) &&
    cell.semantic_content() == SemanticContent::Prompt else {
    fail("expected style, hyperlink, protection, and semantic state")
  }

  style_copy.reset()
  guard cell.style().bold() else {
    fail("expected cell style getter to return a defensive copy")
  }

  cell.full_reset()
  guard cell.content_tag() == PageCellContentTag::Codepoint &&
    cell.codepoint() == 0U &&
    cell.palette_index() == None &&
    cell.background_rgb() == None &&
    cell.style().is_default() &&
    cell.wide() == PageCellWide::Narrow &&
    !cell.is_protected() &&
    cell.hyperlink() == None &&
    cell.semantic_content() == SemanticContent::Output else {
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
