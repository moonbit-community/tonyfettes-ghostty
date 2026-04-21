///|
test "terminal saved cursor state/charset defaults and reset" {
  let state = ScreenCharsetState::new()
  guard state.charset(G0) == Charset::Utf8 &&
    state.charset(G1) == Charset::Utf8 &&
    state.charset(G2) == Charset::Utf8 &&
    state.charset(G3) == Charset::Utf8 &&
    state.gl() == G0 &&
    state.gr() == G2 &&
    state.single_shift() == None else {
    fail("expected charset state defaults")
  }

  state.configure(G0, Charset::Ascii)
  state.configure(G1, Charset::DecSpecial)
  state.configure(G2, Charset::British)
  state.invoke(Gl, G1, false)
  state.invoke(Gl, G2, true)
  guard state.charset(G0) == Charset::Ascii &&
    state.charset(G2) == Charset::British else {
    fail("expected charset reset setup to cover non-default slot updates")
  }

  state.reset()
  guard state.charset(G0) == Charset::Utf8 &&
    state.charset(G1) == Charset::Utf8 &&
    state.charset(G2) == Charset::Utf8 &&
    state.charset(G3) == Charset::Utf8 &&
    state.gl() == G0 &&
    state.gr() == G2 &&
    state.single_shift() == None else {
    fail("expected charset state reset")
  }
}

///|
test "terminal saved cursor state/charset configure invoke and single shift" {
  let state = ScreenCharsetState::new()
  state.configure(G1, Charset::DecSpecial)
  state.configure(G3, Charset::British)
  guard state.charset(G1) == Charset::DecSpecial &&
    state.charset(G3) == Charset::British else {
    fail("expected charset slot configuration")
  }

  state.invoke(Gl, G1, false)
  state.invoke(Gr, G3, false)
  guard state.gl() == G1 && state.gr() == G3 else {
    fail("expected charset invocation to update GL and GR")
  }

  state.invoke(Gl, G2, true)
  guard state.single_shift() == Some(G2) else {
    fail("expected single shift state to be stored")
  }

  guard state.consume_single_shift() == Some(G2) && state.single_shift() == None else {
    fail("expected consuming single shift to clear it")
  }

  guard state.consume_single_shift() == None else {
    fail("expected empty single shift to stay empty")
  }
}

///|
test "terminal saved cursor state/restore defaults when empty" {
  let state = ScreenSavedCursorState::new()
  guard !state.has_saved() else { fail("expected empty saved cursor state") }

  let saved = state.restore()
  let saved_charset = saved.charset()
  guard saved.x() == 0 &&
    saved.y() == 0 &&
    saved.style().is_default() &&
    !saved.cursor_protected() &&
    !saved.pending_wrap() &&
    !saved.origin() &&
    saved_charset.charset(G0) == Charset::Utf8 &&
    saved_charset.charset(G1) == Charset::Utf8 &&
    saved_charset.charset(G2) == Charset::Utf8 &&
    saved_charset.charset(G3) == Charset::Utf8 &&
    saved_charset.gl() == G0 &&
    saved_charset.gr() == G2 &&
    saved_charset.single_shift() == None else {
    fail("expected default restore snapshot")
  }
}

///|
test "terminal saved cursor state/save captures snapshot values" {
  let cursor = TerminalCursorState::new(24, 80)
  cursor.set_cursor_pos(5, 7, false)
  cursor.set_pending_wrap(true)

  let style = CellStyle::new()
  style.apply_attribute(Bold)
  style.apply_attribute(Color256Fg(9))

  let charset = ScreenCharsetState::new()
  charset.configure(G1, Charset::DecSpecial)
  charset.invoke(Gl, G1, false)
  charset.invoke(Gl, G2, true)

  let state = ScreenSavedCursorState::new()
  state.save(cursor, style, true, true, charset)
  guard state.has_saved() else {
    fail("expected save to populate saved cursor state")
  }

  style.reset()
  charset.reset()
  cursor.set_cursor_pos(1, 1, false)
  cursor.set_pending_wrap(false)

  let saved = state.restore()
  let saved_style = saved.style()
  let saved_charset = saved.charset()
  guard saved.x() == 6 &&
    saved.y() == 4 &&
    saved.cursor_protected() &&
    saved.pending_wrap() &&
    saved.origin() else {
    fail("expected saved cursor scalar fields to be restored")
  }

  guard saved_style.bold() && saved_style.fg_color().palette_index() == Some(9) else {
    fail("expected saved cursor style snapshot")
  }

  guard saved_charset.charset(G1) == Charset::DecSpecial &&
    saved_charset.gl() == G1 &&
    saved_charset.single_shift() == Some(G2) else {
    fail("expected saved cursor charset snapshot")
  }
}

///|
test "terminal saved cursor state/latest save wins and reset clears state" {
  let state = ScreenSavedCursorState::new()

  let first_cursor = TerminalCursorState::new(24, 80)
  let first_style = CellStyle::new()
  first_style.apply_attribute(Bold)
  let first_charset = ScreenCharsetState::new()
  first_charset.configure(G1, Charset::DecSpecial)
  state.save(first_cursor, first_style, false, false, first_charset)

  let second_cursor = TerminalCursorState::new(24, 80)
  second_cursor.set_cursor_pos(2, 3, false)
  let second_style = CellStyle::new()
  second_style.apply_attribute(Italic)
  let second_charset = ScreenCharsetState::new()
  second_charset.configure(G3, Charset::British)
  second_charset.invoke(Gr, G3, false)
  state.save(second_cursor, second_style, false, true, second_charset)

  let restored = state.restore()
  let restored_style = restored.style()
  let restored_charset = restored.charset()
  guard restored.x() == 2 &&
    restored.y() == 1 &&
    !restored.cursor_protected() &&
    !restored.pending_wrap() &&
    restored.origin() else {
    fail("expected most recent save to overwrite prior snapshot")
  }

  guard restored_style.italic() && !restored_style.bold() else {
    fail("expected most recent saved style")
  }

  guard restored_charset.charset(G3) == Charset::British &&
    restored_charset.gr() == G3 else {
    fail("expected most recent saved charset state")
  }

  restored_style.reset()
  restored_charset.reset()
  let restored_again = state.restore()
  let restored_again_style = restored_again.style()
  let restored_again_charset = restored_again.charset()
  guard restored_again_style.italic() &&
    restored_again_charset.charset(G3) == Charset::British &&
    restored_again_charset.gr() == G3 else {
    fail("expected restore to return deep copies")
  }

  state.reset()
  guard !state.has_saved() else {
    fail("expected reset to clear saved cursor state")
  }

  let cleared = state.restore()
  guard cleared.style().is_default() &&
    !cleared.origin() &&
    cleared.charset().gl() == G0 else {
    fail("expected restore after reset to return defaults")
  }
}
