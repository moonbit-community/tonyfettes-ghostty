///|
test "stream terminal bridge/default state and unsupported action" {
  let state = StreamTerminalBridgeState::new()
  guard !state.palette_dirty() else {
    fail("expected palette dirty to start false")
  }
  guard state.mode_enabled(Mode::Wraparound) &&
    state.mode_enabled(Mode::CursorVisible) else {
    fail("expected default mode set")
  }
  guard state.display_state().status_display() == StatusDisplay::Main else {
    fail("expected default status display")
  }
  guard state.display_state().mouse_shape() == MouseShape::Text else {
    fail("expected default mouse shape")
  }
  guard state.protected_state().mode() == ProtectedMode::Off &&
    !state.protected_state().cursor_protected() else {
    fail("expected default protected state")
  }
  guard state.cursor_x() == 0 &&
    state.cursor_y() == 0 &&
    state.cursor_visual_style() == CursorVisualStyle::Block &&
    !state.cursor_pending_wrap() &&
    state.cursor_top_margin() == 0 &&
    state.cursor_bottom_margin() == 23 &&
    state.cursor_left_margin() == 0 &&
    state.cursor_right_margin() == 79 else {
    fail("expected default cursor state")
  }
  guard state.mouse_event() == MouseEvent::None &&
    state.mouse_format() == MouseFormat::X10 else {
    fail("expected default mouse reporting state")
  }
  guard !state.modify_other_keys_2() &&
    state.mouse_shift_capture() == None &&
    state.kitty_keyboard_flags() == KittyKeyboardFlags(0) else {
    fail("expected default input state")
  }
  guard state.charset(Slots::G0) == Charset::Utf8 &&
    state.charset_gl() == Slots::G0 &&
    state.charset_gr() == Slots::G2 &&
    state.charset_single_shift() == None &&
    !state.has_saved_cursor() else {
    fail("expected default charset/save state")
  }
  guard state.tabstop(8) && !state.tabstop(0) else {
    fail("expected default tabstop layout")
  }

  guard state.apply(StreamRestoreCursor) else {
    fail("expected restore cursor to be handled")
  }
  guard state.cursor_x() == 0 &&
    state.cursor_y() == 0 &&
    state.charset_gl() == Slots::G0 else {
    fail("expected restore without save to keep defaults")
  }

  guard !state.apply(StreamBell) else {
    fail("expected unsupported action to return false")
  }
}

///|
test "stream terminal bridge/applies protected and display actions" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamProtectedModeIso) else {
    fail("expected protected mode iso to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Iso &&
    state.protected_state().cursor_protected() else {
    fail("expected protected mode iso semantics")
  }

  guard state.apply(StreamProtectedModeOff) else {
    fail("expected protected mode off to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Iso &&
    !state.protected_state().cursor_protected() else {
    fail("expected off to preserve last non-off mode")
  }

  guard state.apply(StreamProtectedModeDec) else {
    fail("expected protected mode dec to be handled")
  }
  guard state.protected_state().mode() == ProtectedMode::Dec &&
    state.protected_state().cursor_protected() else {
    fail("expected protected mode dec semantics")
  }

  guard state.apply(StreamActiveStatusDisplay(StatusDisplay::StatusLine)) else {
    fail("expected active status display to be handled")
  }
  guard state.apply(StreamMouseShape(MouseShape::Pointer)) else {
    fail("expected mouse shape to be handled")
  }
  guard state.display_state().status_display() == StatusDisplay::StatusLine &&
    state.display_state().mouse_shape() == MouseShape::Pointer else {
    fail("expected display actions to update state")
  }
}

///|
test "stream terminal bridge/applies cursor movement and mode metadata" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamCursorPos({ row: 4, col: 5 })) else {
    fail("expected cursor position to be handled")
  }
  guard state.cursor_x() == 4 && state.cursor_y() == 3 else {
    fail("expected cursor position update")
  }

  guard state.apply(StreamCursorCol(CursorMovement(2))) else {
    fail("expected cursor column to be handled")
  }
  guard state.cursor_x() == 1 && state.cursor_y() == 3 else {
    fail("expected cursor column update")
  }

  guard state.apply(StreamCursorRow(CursorMovement(6))) else {
    fail("expected cursor row to be handled")
  }
  guard state.cursor_x() == 1 && state.cursor_y() == 5 else {
    fail("expected cursor row update")
  }

  guard state.apply(StreamCursorColRelative(CursorMovement(3))) else {
    fail("expected cursor relative column to be handled")
  }
  guard state.cursor_x() == 4 && state.cursor_y() == 5 else {
    fail("expected cursor relative column update")
  }

  guard state.apply(StreamCursorRowRelative(CursorMovement(2))) else {
    fail("expected cursor relative row to be handled")
  }
  guard state.cursor_x() == 4 && state.cursor_y() == 7 else {
    fail("expected cursor relative row update")
  }

  guard state.apply(StreamCursorUp(CursorMovement(2))) else {
    fail("expected cursor up to be handled")
  }
  guard state.cursor_y() == 5 else { fail("expected cursor up clamp") }

  guard state.apply(StreamCursorDown(CursorMovement(0))) else {
    fail("expected cursor down to be handled")
  }
  guard state.cursor_y() == 6 else {
    fail("expected cursor down default count")
  }

  guard state.apply(StreamCursorLeft(CursorMovement(10))) else {
    fail("expected cursor left to be handled")
  }
  guard state.cursor_x() == 0 && !state.cursor_pending_wrap() else {
    fail("expected cursor left clamp")
  }

  guard state.apply(StreamCursorRight(CursorMovement(100))) else {
    fail("expected cursor right to be handled")
  }
  guard state.cursor_x() == 79 && !state.cursor_pending_wrap() else {
    fail("expected cursor right clamp")
  }

  guard state.apply(StreamCursorColRelative(CursorMovement(65535))) else {
    fail("expected large relative column to be handled")
  }
  guard state.cursor_x() == 79 else {
    fail("expected large relative column saturation")
  }

  guard state.apply(StreamCursorStyle(CursorStyle::BlinkingUnderline)) else {
    fail("expected cursor style to be handled")
  }
  guard state.cursor_visual_style() == CursorVisualStyle::Underline &&
    state.mode_enabled(Mode::CursorBlinking) else {
    fail("expected cursor style metadata update")
  }

  guard state.apply(StreamModifyKeyFormat(ModifyKeyFormat::OtherKeysNumeric)) else {
    fail("expected modify-key format to be handled")
  }
  guard state.modify_other_keys_2() else {
    fail("expected modify-other-keys state")
  }

  guard state.apply(StreamModifyKeyFormat(ModifyKeyFormat::Legacy)) else {
    fail("expected legacy modify-key format to be handled")
  }
  guard !state.modify_other_keys_2() else {
    fail("expected legacy modify-key format reset")
  }

  guard state.apply(StreamMouseShiftCapture(true)) else {
    fail("expected mouse shift capture to be handled")
  }
  guard state.mouse_shift_capture() == Some(true) else {
    fail("expected mouse shift capture state")
  }

  guard state.apply(StreamSetMode(Mode::MouseEventButton)) else {
    fail("expected mouse event mode to be handled")
  }
  guard state.mode_enabled(Mode::MouseEventButton) &&
    state.mouse_event() == MouseEvent::Button else {
    fail("expected mouse event mode state")
  }

  guard state.apply(StreamResetMode(Mode::MouseEventButton)) else {
    fail("expected mouse event reset to be handled")
  }
  guard !state.mode_enabled(Mode::MouseEventButton) &&
    state.mouse_event() == MouseEvent::None else {
    fail("expected mouse event reset state")
  }

  guard state.apply(StreamSetMode(Mode::MouseEventX10)) else {
    fail("expected x10 mouse event mode to be handled")
  }
  guard state.mouse_event() == MouseEvent::X10 else {
    fail("expected x10 mouse event mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseEventX10)) else {
    fail("expected x10 mouse event reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseEventNormal)) else {
    fail("expected normal mouse event mode to be handled")
  }
  guard state.mouse_event() == MouseEvent::Normal else {
    fail("expected normal mouse event mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseEventNormal)) else {
    fail("expected normal mouse event reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseEventAny)) else {
    fail("expected any mouse event mode to be handled")
  }
  guard state.mouse_event() == MouseEvent::Any else {
    fail("expected any mouse event mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseEventAny)) else {
    fail("expected any mouse event reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseFormatSgr)) else {
    fail("expected mouse format mode to be handled")
  }
  guard state.mode_enabled(Mode::MouseFormatSgr) &&
    state.mouse_format() == MouseFormat::Sgr else {
    fail("expected mouse format mode state")
  }

  guard state.apply(StreamResetMode(Mode::MouseFormatSgr)) else {
    fail("expected mouse format reset to be handled")
  }
  guard !state.mode_enabled(Mode::MouseFormatSgr) &&
    state.mouse_format() == MouseFormat::X10 else {
    fail("expected mouse format reset state")
  }

  guard state.apply(StreamSetMode(Mode::MouseFormatUtf8)) else {
    fail("expected utf8 mouse format mode to be handled")
  }
  guard state.mouse_format() == MouseFormat::Utf8 else {
    fail("expected utf8 mouse format mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseFormatUtf8)) else {
    fail("expected utf8 mouse format reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseFormatUrxvt)) else {
    fail("expected urxvt mouse format mode to be handled")
  }
  guard state.mouse_format() == MouseFormat::Urxvt else {
    fail("expected urxvt mouse format mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseFormatUrxvt)) else {
    fail("expected urxvt mouse format reset to be handled")
  }

  guard state.apply(StreamSetMode(Mode::MouseFormatSgrPixels)) else {
    fail("expected sgr-pixels mouse format mode to be handled")
  }
  guard state.mouse_format() == MouseFormat::SgrPixels else {
    fail("expected sgr-pixels mouse format mode state")
  }
  guard state.apply(StreamResetMode(Mode::MouseFormatSgrPixels)) else {
    fail("expected sgr-pixels mouse format reset to be handled")
  }

  guard state.apply(StreamResetMode(Mode::CursorVisible)) else {
    fail("expected cursor-visible reset to be handled")
  }
  guard !state.mode_enabled(Mode::CursorVisible) else {
    fail("expected cursor-visible mode reset")
  }

  guard state.apply(StreamSaveMode(Mode::CursorVisible)) else {
    fail("expected save mode to be handled")
  }
  guard state.apply(StreamSetMode(Mode::CursorVisible)) else {
    fail("expected cursor-visible set to be handled")
  }
  guard state.mode_enabled(Mode::CursorVisible) else {
    fail("expected cursor-visible mode set")
  }

  guard state.apply(StreamRestoreMode(Mode::CursorVisible)) else {
    fail("expected restore mode to be handled")
  }
  guard !state.mode_enabled(Mode::CursorVisible) else {
    fail("expected restore mode to reapply saved value")
  }
}

///|
test "stream terminal bridge/applies margin actions and cursor save branches" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamTopAndBottomMargin({ top_left: 3, bottom_right: 5 })) else {
    fail("expected top/bottom margins to be handled")
  }
  guard state.cursor_top_margin() == 2 &&
    state.cursor_bottom_margin() == 4 &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 0 else {
    fail("expected top/bottom margin state")
  }

  guard state.apply(StreamSetMode(Mode::Origin)) else {
    fail("expected origin mode to be handled")
  }
  guard state.mode_enabled(Mode::Origin) &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 2 else {
    fail("expected origin mode home position")
  }

  guard state.apply(StreamSetMode(Mode::EnableLeftAndRightMargin)) else {
    fail("expected left/right margin mode to be handled")
  }
  guard state.mode_enabled(Mode::EnableLeftAndRightMargin) else {
    fail("expected left/right margin mode state")
  }

  guard state.apply(
    StreamLeftAndRightMargin({ top_left: 11, bottom_right: 20 }),
  ) else {
    fail("expected left/right margins to be handled")
  }
  guard state.cursor_left_margin() == 10 &&
    state.cursor_right_margin() == 19 &&
    state.cursor_x() == 10 &&
    state.cursor_y() == 2 else {
    fail("expected left/right margin state")
  }

  guard state.apply(StreamCursorRight(CursorMovement(100))) else {
    fail("expected cursor right in margins to be handled")
  }
  guard state.cursor_x() == 19 else {
    fail("expected cursor right margin clamp")
  }

  guard state.apply(StreamCursorPos({ row: 1, col: 3 })) else {
    fail("expected cursor position inside left/right margins")
  }
  guard state.apply(StreamCursorLeft(CursorMovement(5))) else {
    fail("expected cursor left inside origin margins")
  }
  guard state.cursor_x() == 10 else {
    fail("expected origin left-margin clamp")
  }

  guard state.apply(StreamHorizontalTabBack(1)) else {
    fail("expected horizontal tab back at left limit to be handled")
  }
  guard state.cursor_x() == 10 else {
    fail("expected horizontal tab back to stop at origin left limit")
  }

  guard state.apply(StreamLeftAndRightMarginAmbiguous) else {
    fail("expected ambiguous left/right margin action to be handled")
  }
  guard state.cursor_left_margin() == 0 &&
    state.cursor_right_margin() == 79 &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 2 else {
    fail("expected enabled ambiguous margin branch")
  }

  guard state.apply(StreamResetMode(Mode::EnableLeftAndRightMargin)) else {
    fail("expected left/right margin mode reset to be handled")
  }
  guard !state.mode_enabled(Mode::EnableLeftAndRightMargin) &&
    state.cursor_left_margin() == 0 &&
    state.cursor_right_margin() == 79 &&
    state.cursor_x() == 0 &&
    state.cursor_y() == 2 else {
    fail("expected left/right margin reset branch")
  }

  guard state.apply(StreamCursorPos({ row: 4, col: 5 })) else {
    fail("expected cursor position after margin reset")
  }
  guard state.apply(StreamLeftAndRightMarginAmbiguous) else {
    fail("expected ambiguous action disabled branch")
  }
  guard state.has_saved_cursor() else {
    fail("expected ambiguous action to save cursor when margins disabled")
  }

  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor mutation before restore")
  }
  guard state.apply(StreamRestoreCursor) else {
    fail("expected restore cursor after ambiguous save")
  }
  guard state.cursor_x() == 4 &&
    state.cursor_y() == 4 &&
    state.mode_enabled(Mode::Origin) else {
    fail("expected restore cursor after ambiguous save")
  }
}

///|
test "stream terminal bridge/applies charset save restore and keyboard state" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(
    StreamConfigureCharset({ slot: Slots::G1, charset: Charset::British }),
  ) else {
    fail("expected charset configure to be handled")
  }
  guard state.apply(
    StreamInvokeCharset({
      bank: ActiveSlot::Gl,
      charset: Slots::G1,
      locking: false,
    }),
  ) else {
    fail("expected locking charset invoke to be handled")
  }
  guard state.apply(
    StreamInvokeCharset({
      bank: ActiveSlot::Gl,
      charset: Slots::G2,
      locking: true,
    }),
  ) else {
    fail("expected single-shift charset invoke to be handled")
  }
  guard state.apply(StreamProtectedModeDec) else {
    fail("expected protected mode dec before save")
  }
  guard state.apply(StreamSetMode(Mode::Origin)) else {
    fail("expected origin mode before save")
  }
  guard state.apply(StreamCursorPos({ row: 2, col: 3 })) else {
    fail("expected cursor position before save")
  }
  guard state.apply(StreamSaveCursor) else {
    fail("expected direct save cursor to be handled")
  }

  guard state.apply(
    StreamConfigureCharset({ slot: Slots::G1, charset: Charset::Ascii }),
  ) else {
    fail("expected charset reconfigure to be handled")
  }
  guard state.apply(
    StreamInvokeCharset({
      bank: ActiveSlot::Gl,
      charset: Slots::G0,
      locking: false,
    }),
  ) else {
    fail("expected charset invoke mutation")
  }
  guard state.apply(StreamProtectedModeOff) else {
    fail("expected protected mode off mutation")
  }
  guard state.apply(StreamResetMode(Mode::Origin)) else {
    fail("expected origin reset mutation")
  }
  guard state.apply(StreamCursorPos({ row: 10, col: 10 })) else {
    fail("expected cursor mutation before restore")
  }

  guard state.apply(StreamRestoreCursor) else {
    fail("expected direct restore cursor to be handled")
  }
  guard state.cursor_x() == 2 &&
    state.cursor_y() == 1 &&
    state.mode_enabled(Mode::Origin) else {
    fail("expected restored cursor position and origin mode")
  }
  guard state.charset(Slots::G1) == Charset::British &&
    state.charset_gl() == Slots::G1 &&
    state.charset_single_shift() == Some(Slots::G2) else {
    fail("expected restored charset state")
  }
  guard state.protected_state().mode() == ProtectedMode::Dec &&
    state.protected_state().cursor_protected() else {
    fail("expected restored cursor protection")
  }

  guard state.apply(StreamCursorPos({ row: 5, col: 6 })) else {
    fail("expected cursor mutation before mode save")
  }
  guard state.apply(StreamSetMode(Mode::SaveCursor)) else {
    fail("expected save-cursor mode set to be handled")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor mutation before mode restore")
  }
  guard state.apply(StreamResetMode(Mode::SaveCursor)) else {
    fail("expected save-cursor mode reset to restore cursor")
  }
  guard state.cursor_x() == 5 && state.cursor_y() == 4 else {
    fail("expected save-cursor mode restore")
  }

  guard state.apply(StreamKittyKeyboardPush(KittyKeyboardFlags(3))) else {
    fail("expected kitty keyboard push to be handled")
  }
  guard state.apply(StreamKittyKeyboardSetOr(KittyKeyboardFlags(4))) else {
    fail("expected kitty keyboard set-or to be handled")
  }
  guard state.kitty_keyboard_flags() == KittyKeyboardFlags(7) else {
    fail("expected kitty keyboard or state")
  }

  guard state.apply(StreamKittyKeyboardSetNot(KittyKeyboardFlags(1))) else {
    fail("expected kitty keyboard set-not to be handled")
  }
  guard state.kitty_keyboard_flags() == KittyKeyboardFlags(6) else {
    fail("expected kitty keyboard not state")
  }

  guard state.apply(StreamKittyKeyboardSet(KittyKeyboardFlags(5))) else {
    fail("expected kitty keyboard set to be handled")
  }
  guard state.kitty_keyboard_flags() == KittyKeyboardFlags(5) else {
    fail("expected kitty keyboard set state")
  }

  guard state.apply(StreamKittyKeyboardPop(9)) else {
    fail("expected kitty keyboard pop to be handled")
  }
  guard state.kitty_keyboard_flags() == KittyKeyboardFlags(0) else {
    fail("expected kitty keyboard pop reset")
  }
}

///|
test "stream terminal bridge/applies tab operations" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamHorizontalTab(1)) else {
    fail("expected horizontal tab to be handled")
  }
  guard state.cursor_x() == 8 else {
    fail("expected default horizontal tab stop")
  }

  guard state.apply(StreamCursorPos({ row: 1, col: 6 })) else {
    fail("expected cursor position before tab set")
  }
  guard state.apply(StreamTabSet) else {
    fail("expected tab set to be handled")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor reset before tab jump")
  }
  guard state.apply(StreamHorizontalTab(1)) else {
    fail("expected horizontal tab after custom set")
  }
  guard state.cursor_x() == 5 else { fail("expected custom tab stop") }

  guard state.apply(StreamTabClearCurrent) else {
    fail("expected tab clear current to be handled")
  }
  guard !state.tabstop(5) else { fail("expected current tab stop clear") }

  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor reset before default tab")
  }
  guard state.apply(StreamHorizontalTab(1)) else {
    fail("expected horizontal tab after clear current")
  }
  guard state.cursor_x() == 8 else {
    fail("expected fallback to default tab stop")
  }

  guard state.apply(StreamTabClearAll) else {
    fail("expected tab clear all to be handled")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 1 })) else {
    fail("expected cursor reset before clear-all tab")
  }
  guard state.apply(StreamHorizontalTab(1)) else {
    fail("expected horizontal tab without tab stops")
  }
  guard state.cursor_x() == 79 else {
    fail("expected tab without stops to run to the right edge")
  }

  guard state.apply(StreamHorizontalTab(2)) else {
    fail("expected horizontal tab at the right edge to be handled")
  }
  guard state.cursor_x() == 79 else {
    fail("expected horizontal tab at the right edge to stay put")
  }

  guard state.apply(StreamTabReset) else {
    fail("expected tab reset to be handled")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 21 })) else {
    fail("expected cursor position before horizontal tab back")
  }
  guard state.apply(StreamHorizontalTabBack(1)) else {
    fail("expected horizontal tab back to be handled")
  }
  guard state.cursor_x() == 16 else {
    fail("expected horizontal tab back to previous stop")
  }
}

///|
test "stream terminal bridge/covers cursor movement edge branches" {
  let state = StreamTerminalBridgeState::new()

  guard state.apply(StreamTopAndBottomMargin({ top_left: 3, bottom_right: 5 })) else {
    fail("expected top/bottom margin setup")
  }
  guard state.apply(StreamCursorPos({ row: 10, col: 1 })) else {
    fail("expected cursor move below bottom margin")
  }
  guard state.apply(StreamCursorDown(CursorMovement(1))) else {
    fail("expected cursor down below margin to be handled")
  }
  guard state.cursor_y() == 10 else {
    fail("expected cursor down outside-scroll-region branch")
  }

  guard state.apply(StreamSetMode(Mode::EnableLeftAndRightMargin)) else {
    fail("expected left/right margin mode setup")
  }
  guard state.apply(
    StreamLeftAndRightMargin({ top_left: 11, bottom_right: 20 }),
  ) else {
    fail("expected left/right margin setup")
  }
  guard state.apply(StreamCursorPos({ row: 1, col: 80 })) else {
    fail("expected cursor move outside right margin")
  }
  guard state.apply(StreamCursorRight(CursorMovement(1))) else {
    fail("expected cursor right outside margin to be handled")
  }
  guard state.cursor_x() == 79 else {
    fail("expected cursor right outside-scroll-region branch")
  }
}

///|
test "stream terminal bridge/applies color set operations and ignores non-terminal targets" {
  let state = StreamTerminalBridgeState::new()
  let command = ColorCommand::new(
    Osc4,
    [
      Set(ColoredTarget::new(Palette(1), RGB::new(9, 8, 7))),
      Set(ColoredTarget::new(Dynamic(Foreground), RGB::new(1, 2, 3))),
      Set(ColoredTarget::new(Dynamic(Background), RGB::new(4, 5, 6))),
      Set(ColoredTarget::new(Dynamic(Cursor), RGB::new(7, 8, 9))),
      Set(ColoredTarget::new(Dynamic(PointerForeground), RGB::new(9, 9, 9))),
      Set(ColoredTarget::new(Special(Bold), RGB::new(6, 6, 6))),
    ],
    Terminator::St,
  )

  guard state.apply(StreamColorOperation(command)) else {
    fail("expected color operation to be handled")
  }
  guard state.palette_dirty() else {
    fail("expected palette writes to mark palette dirty")
  }
  guard state.colors().palette_color(1) == RGB::new(9, 8, 7) else {
    fail("expected palette color write")
  }
  guard state.colors().foreground() == Some(RGB::new(1, 2, 3)) else {
    fail("expected foreground dynamic color write")
  }
  guard state.colors().background() == Some(RGB::new(4, 5, 6)) else {
    fail("expected background dynamic color write")
  }
  guard state.colors().cursor() == Some(RGB::new(7, 8, 9)) else {
    fail("expected cursor dynamic color write")
  }
}

///|
test "stream terminal bridge/applies color resets and reset palette" {
  let state = StreamTerminalBridgeState::new()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc4,
        [
          Set(ColoredTarget::new(Palette(1), RGB::new(10, 11, 12))),
          Set(ColoredTarget::new(Palette(2), RGB::new(20, 21, 22))),
          Set(ColoredTarget::new(Dynamic(Foreground), RGB::new(1, 2, 3))),
          Set(ColoredTarget::new(Dynamic(Background), RGB::new(4, 5, 6))),
          Set(ColoredTarget::new(Dynamic(Cursor), RGB::new(7, 8, 9))),
        ],
        Terminator::St,
      ),
    ),
  ) else {
    fail("expected setup color operation")
  }

  state.clear_palette_dirty()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc104,
        [
          Reset(Palette(1)),
          Reset(Dynamic(Foreground)),
          Reset(Dynamic(Background)),
          Reset(Dynamic(Cursor)),
          Reset(Dynamic(PointerBackground)),
        ],
        Terminator::Bel,
      ),
    ),
  ) else {
    fail("expected reset color operation")
  }

  guard state.palette_dirty() else {
    fail("expected palette reset to mark palette dirty")
  }
  guard state.colors().palette_color(1) == Name::Red.default_rgb() else {
    fail("expected palette reset to restore default entry")
  }
  guard state.colors().foreground() == None &&
    state.colors().background() == None &&
    state.colors().cursor() == None else {
    fail("expected dynamic color resets to restore unset state")
  }

  state.clear_palette_dirty()
  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(Osc104, [ResetPalette], Terminator::St),
    ),
  ) else {
    fail("expected reset palette operation")
  }
  guard state.palette_dirty() else {
    fail("expected reset palette to mark palette dirty when changes exist")
  }
  guard state.colors().palette_color(2) == Name::Green.default_rgb() else {
    fail("expected reset palette to restore all palette entries")
  }
}

///|
test "stream terminal bridge/empty and query color operations are handled without mutation" {
  let state = StreamTerminalBridgeState::new()
  guard state.apply(
    StreamColorOperation(ColorCommand::new(Osc4, [], Terminator::St)),
  ) else {
    fail("expected empty color operation to be handled")
  }

  guard state.apply(
    StreamColorOperation(
      ColorCommand::new(
        Osc4,
        [Query(Palette(1)), Reset(Special(Bold))],
        Terminator::St,
      ),
    ),
  ) else {
    fail("expected query-only color operation to be handled")
  }
  guard !state.palette_dirty() else {
    fail("expected query-only color operation to leave state unchanged")
  }
}
