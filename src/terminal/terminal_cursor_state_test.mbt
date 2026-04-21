///|
test "terminal cursor state/defaults and full reset" {
  let state = TerminalCursorState::new(24, 80)
  guard state.x() == 0 &&
    state.y() == 0 &&
    state.visual_style() == CursorVisualStyle::Block &&
    !state.pending_wrap() &&
    state.top_margin() == 0 &&
    state.bottom_margin() == 23 &&
    state.left_margin() == 0 &&
    state.right_margin() == 79 else {
    fail("expected terminal cursor defaults")
  }

  state.set_pending_wrap(true)
  ignore(state.apply_cursor_style(BlinkingBar))
  state.set_top_and_bottom_margin(3, 10, true)
  state.set_left_and_right_margin(true, 5, 20, true)
  state.full_reset()
  guard state.x() == 0 &&
    state.y() == 0 &&
    state.visual_style() == CursorVisualStyle::Block &&
    !state.pending_wrap() &&
    state.top_margin() == 0 &&
    state.bottom_margin() == 23 &&
    state.left_margin() == 0 &&
    state.right_margin() == 79 else {
    fail("expected terminal cursor full reset")
  }
}

///|
test "terminal cursor state/zero dimensions clamp to one cell" {
  let state = TerminalCursorState::new(0, 0)
  guard state.x() == 0 &&
    state.y() == 0 &&
    state.top_margin() == 0 &&
    state.bottom_margin() == 0 &&
    state.left_margin() == 0 &&
    state.right_margin() == 0 else {
    fail("expected zero dimensions to clamp to a 1x1 cursor state")
  }
}

///|
test "terminal cursor state/applies csi cursor style mapping" {
  let state = TerminalCursorState::new(24, 80)

  guard !state.apply_cursor_style(Default) &&
    state.visual_style() == CursorVisualStyle::Block else {
    fail("expected default cursor style mapping")
  }

  guard state.apply_cursor_style(BlinkingBlock) &&
    state.visual_style() == CursorVisualStyle::Block else {
    fail("expected blinking block mapping")
  }

  guard !state.apply_cursor_style(SteadyBlock) &&
    state.visual_style() == CursorVisualStyle::Block else {
    fail("expected steady block mapping")
  }

  guard state.apply_cursor_style(BlinkingUnderline) &&
    state.visual_style() == CursorVisualStyle::Underline else {
    fail("expected blinking underline mapping")
  }

  guard !state.apply_cursor_style(SteadyUnderline) &&
    state.visual_style() == CursorVisualStyle::Underline else {
    fail("expected steady underline mapping")
  }

  guard !state.apply_cursor_style(SteadyBar) &&
    state.visual_style() == CursorVisualStyle::Bar else {
    fail("expected steady bar mapping")
  }
}

///|
test "terminal cursor state/set cursor pos clamps and clears pending wrap" {
  let state = TerminalCursorState::new(24, 80)
  state.set_pending_wrap(true)

  state.set_cursor_pos(0, 0, false)
  guard state.x() == 0 && state.y() == 0 && !state.pending_wrap() else {
    fail("expected zero requests to clamp to the first cell")
  }

  state.set_pending_wrap(true)
  state.set_cursor_pos(40, 120, false)
  guard state.x() == 79 && state.y() == 23 && !state.pending_wrap() else {
    fail("expected oversized cursor requests to clamp to screen bounds")
  }
}

///|
test "terminal cursor state/origin mode uses margins for positioning" {
  let state = TerminalCursorState::new(24, 80)

  state.set_top_and_bottom_margin(3, 10, true)
  guard state.x() == 0 && state.y() == 2 else {
    fail("expected top-bottom margin update to home within origin region")
  }

  state.set_left_and_right_margin(true, 5, 20, true)
  guard state.x() == 4 && state.y() == 2 else {
    fail("expected left-right margin update to home within origin region")
  }

  state.set_cursor_pos(1, 1, true)
  guard state.x() == 4 && state.y() == 2 else {
    fail("expected origin-mode cursor position to use region offsets")
  }

  state.set_cursor_pos(20, 40, true)
  guard state.x() == 19 && state.y() == 9 else {
    fail("expected origin-mode cursor position to clamp to region bounds")
  }
}

///|
test "terminal cursor state/zero bottom requests clamp to terminal bounds" {
  let state = TerminalCursorState::new(24, 80)

  state.set_top_and_bottom_margin(3, 0, false)
  guard state.top_margin() == 2 && state.bottom_margin() == 23 else {
    fail("expected zero bottom margin request to clamp to screen bottom")
  }

  state.set_left_and_right_margin(true, 5, 0, false)
  guard state.left_margin() == 4 && state.right_margin() == 79 else {
    fail("expected zero right margin request to clamp to screen right edge")
  }
}

///|
test "terminal cursor state/invalid or disabled margins keep prior state" {
  let state = TerminalCursorState::new(24, 80)

  state.set_left_and_right_margin(false, 5, 20, false)
  guard state.left_margin() == 0 && state.right_margin() == 79 else {
    fail("expected disabled left-right margin update to do nothing")
  }

  state.set_top_and_bottom_margin(12, 12, false)
  guard state.top_margin() == 0 && state.bottom_margin() == 23 else {
    fail("expected invalid top-bottom margins to be ignored")
  }

  state.set_left_and_right_margin(true, 20, 20, false)
  guard state.left_margin() == 0 && state.right_margin() == 79 else {
    fail("expected invalid left-right margins to be ignored")
  }
}
