///|

///|
fn all_modes() -> Array[Mode] {
  [
    DisableKeyboard,
    Insert,
    SendReceiveMode,
    Linefeed,
    CursorKeys,
    Mode132Column,
    SlowScroll,
    ReverseColors,
    Origin,
    Wraparound,
    Autorepeat,
    MouseEventX10,
    CursorBlinking,
    CursorVisible,
    EnableMode3,
    ReverseWrap,
    AltScreenLegacy,
    KeypadKeys,
    BackarrowKeyMode,
    EnableLeftAndRightMargin,
    MouseEventNormal,
    MouseEventButton,
    MouseEventAny,
    FocusEvent,
    MouseFormatUtf8,
    MouseFormatSgr,
    MouseAlternateScroll,
    MouseFormatUrxvt,
    MouseFormatSgrPixels,
    IgnoreKeypadWithNumlock,
    AltEscPrefix,
    AltSendsEscape,
    ReverseWrapExtended,
    AltScreen,
    SaveCursor,
    AltScreenSaveCursorClearEnter,
    BracketedPaste,
    SynchronizedOutput,
    GraphemeCluster,
    ReportColorScheme,
    InBandSizeReports,
  ]
}

///|
test "modes/mode_from_int" {
  guard mode_from_int(4, true) == Some(Insert) else {
    fail("expected ansi insert mode")
  }
  guard mode_from_int(9, true) == None else { fail("unexpected ansi mode") }
  guard mode_from_int(9, false) == Some(MouseEventX10) else {
    fail("expected dec mouse x10 mode")
  }
  guard mode_from_int(14, true) == None else { fail("unexpected ansi mode") }
}

///|
test "modes/all tags roundtrip through lookup and raw layout" {
  for mode in all_modes() {
    let tag = mode.tag()
    guard mode_from_int(tag.value(), tag.ansi()) is Some(found) else {
      fail("expected roundtrip mode for raw tag \{tag.raw()}")
    }
    assert_eq(found.tag().raw(), tag.raw())
  }

  assert_eq(Mode::CursorKeys.tag().raw(), 0x0001)
  assert_eq(Mode::Insert.tag().raw(), 0x8004)
  let tag = mode_tag_from_raw(0x840C)
  assert_eq(tag.value(), 0x040C)
  assert_eq(tag.ansi(), true)
  assert_eq(tag.raw(), 0x840C)
}

///|
test "modes/defaults preserve upstream true flags" {
  let state = ModeState::new()
  let defaults = ModePacked::default()
  guard state.get(SendReceiveMode) else {
    fail("expected send_receive_mode default")
  }
  guard state.get(Wraparound) else { fail("expected wraparound default") }
  guard state.get(CursorVisible) else {
    fail("expected cursor_visible default")
  }
  guard state.get(MouseAlternateScroll) else {
    fail("expected mouse_alternate_scroll default")
  }
  guard state.get(IgnoreKeypadWithNumlock) else {
    fail("expected ignore_keypad_with_numlock default")
  }
  guard state.get(AltEscPrefix) else { fail("expected alt_esc_prefix default") }
  for mode in all_modes() {
    assert_eq(defaults.get(mode), state.get(mode))
  }
}

///|
test "modes/state set get save restore" {
  let state = ModeState::new()
  guard !state.get(CursorKeys) else { fail("expected unset cursor_keys") }
  state.set(CursorKeys, true)
  guard state.get(CursorKeys) else { fail("expected set cursor_keys") }
  state.save(CursorKeys)
  state.set(CursorKeys, false)
  guard !state.get(CursorKeys) else { fail("expected cleared cursor_keys") }
  guard state.restore(CursorKeys) else { fail("expected restore to true") }
  guard state.get(CursorKeys) else { fail("expected restored cursor_keys") }
}

///|
test "modes/reset restores original defaults after mutation" {
  let state = ModeState::new()
  state.set(CursorVisible, false)
  state.set(BracketedPaste, true)

  state.reset()
  guard state.get(CursorVisible) && !state.get(BracketedPaste) else {
    fail("expected reset to restore the original defaults")
  }
}

///|
test "modes/get report for known dec mode" {
  let state = ModeState::new()
  let report = state.get_report(mode_tag(1, false))
  guard report.state() == Reset else { fail("expected reset report") }
  assert_eq(report.tag().ansi(), false)
  assert_eq(report.tag().value(), 1)
}

///|
test "modes/get report for known ansi mode and unknown mode" {
  let state = ModeState::new()
  state.set(Insert, true)
  let ansi_report = state.get_report(mode_tag(4, true))
  guard ansi_report.state() == Set else { fail("expected set report") }
  assert_eq(ansi_report.tag().ansi(), true)

  let unknown = state.get_report(mode_tag(9999, false))
  guard unknown.state() == NotRecognized else {
    fail("expected not recognized report")
  }
}

///|
test "modes/report encode" {
  let state = ModeState::new()
  state.set(CursorKeys, true)
  assert_eq(state.get_report(mode_tag(1, false)).encode(), b"\x1B[?1;1$y")
  assert_eq(state.get_report(mode_tag(4, true)).encode(), b"\x1B[4;2$y")
  assert_eq(state.get_report(mode_tag(9999, false)).encode(), b"\x1B[?9999;0$y")
  assert_eq(
    state.get_report(mode_tag(0x7FFF, false)).encode(),
    b"\x1B[?32767;0$y",
  )
}

///|
test "modes/packed state exercises set clear no-op and reset paths" {
  let packed = ModePacked::empty()
  guard !packed.get(CursorKeys) else {
    fail("expected cursor keys to start unset")
  }
  packed.set(CursorKeys, false)
  guard !packed.get(CursorKeys) else {
    fail("expected clearing an unset mode to remain unset")
  }
  packed.set(CursorKeys, true)
  guard packed.get(CursorKeys) else { fail("expected cursor keys to be set") }
  packed.set(CursorKeys, false)
  guard !packed.get(CursorKeys) else { fail("expected cursor keys to clear") }

  let state = ModeState::new()
  state.set(CursorKeys, true)
  state.save(CursorKeys)
  state.set(CursorKeys, false)
  state.reset()
  guard !state.get(CursorKeys) else {
    fail("expected reset to restore defaults")
  }
  guard !state.restore(ReverseWrap) else {
    fail("expected unsaved mode restore to remain false")
  }
}

///|
test "modes/report state codes and bit helpers cover edge modes" {
  assert_eq(ReportState::NotRecognized.code(), 0)
  assert_eq(ReportState::Set.code(), 1)
  assert_eq(ReportState::Reset.code(), 2)
  assert_eq(ReportState::PermanentlySet.code(), 3)
  assert_eq(ReportState::PermanentlyReset.code(), 4)

  let packed = ModePacked::empty()
  guard !packed.get(DisableKeyboard) else {
    fail("expected disable keyboard to start unset")
  }
  guard !packed.get(InBandSizeReports) else {
    fail("expected in-band size reports to start unset")
  }
  packed.set(DisableKeyboard, true)
  packed.set(InBandSizeReports, true)
  guard packed.get(DisableKeyboard) else {
    fail("expected disable keyboard to become set")
  }
  guard packed.get(InBandSizeReports) else {
    fail("expected in-band size reports to become set")
  }
}
