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
  // When set_codepoint is called with a new codepoint, grapheme_codepoints
  // should return [] regardless of the grapheme flag.
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
test "page cell state/style hyperlink semantic and full reset" {
  let mut style = @style.CellStyle::new()
  style = style.apply_attribute(Bold)
  let styles = @style.StyleTable::new()
  let mut cell = PageCellState::new(
    style_id=styles.intern(style),
    protected_flag=true,
    semantic_content=Prompt,
  )

  // Hyperlink round-trips through the shared table, which is package-internal;
  // that path is covered white-box in `page_state_wbtest.mbt`.
  guard styles.get(cell.style_id()).bold() &&
    cell.has_styling() &&
    cell.is_protected() &&
    !cell.has_hyperlink() &&
    cell.semantic_content() == Prompt else {
    fail("expected style, protection, and semantic state")
  }

  // A blank cell is just a fresh value now (full_reset is gone).
  cell = PageCellState::new()
  guard cell.codepoint() == 0U &&
    cell.style_id().is_default() &&
    cell.wide() == Narrow &&
    !cell.is_protected() &&
    !cell.has_hyperlink() &&
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
