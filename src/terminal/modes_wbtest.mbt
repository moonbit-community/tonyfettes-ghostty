///|
test "modes/mode_from_int" {
  guard mode_from_int(4, true) == Some(Mode::Insert) else {
    fail("expected ansi insert mode")
  }
  guard mode_from_int(9, true) == None else { fail("unexpected ansi mode") }
  guard mode_from_int(9, false) == Some(Mode::MouseEventX10) else {
    fail("expected dec mouse x10 mode")
  }
  guard mode_from_int(14, true) == None else { fail("unexpected ansi mode") }
}

///|
test "modes/all tags roundtrip through lookup and raw layout" {
  let modes : Array[Mode] = [
    Mode::DisableKeyboard,
    Mode::Insert,
    Mode::SendReceiveMode,
    Mode::Linefeed,
    Mode::CursorKeys,
    Mode::Mode132Column,
    Mode::SlowScroll,
    Mode::ReverseColors,
    Mode::Origin,
    Mode::Wraparound,
    Mode::Autorepeat,
    Mode::MouseEventX10,
    Mode::CursorBlinking,
    Mode::CursorVisible,
    Mode::EnableMode3,
    Mode::ReverseWrap,
    Mode::AltScreenLegacy,
    Mode::KeypadKeys,
    Mode::BackarrowKeyMode,
    Mode::EnableLeftAndRightMargin,
    Mode::MouseEventNormal,
    Mode::MouseEventButton,
    Mode::MouseEventAny,
    Mode::FocusEvent,
    Mode::MouseFormatUtf8,
    Mode::MouseFormatSgr,
    Mode::MouseAlternateScroll,
    Mode::MouseFormatUrxvt,
    Mode::MouseFormatSgrPixels,
    Mode::IgnoreKeypadWithNumlock,
    Mode::AltEscPrefix,
    Mode::AltSendsEscape,
    Mode::ReverseWrapExtended,
    Mode::AltScreen,
    Mode::SaveCursor,
    Mode::AltScreenSaveCursorClearEnter,
    Mode::BracketedPaste,
    Mode::SynchronizedOutput,
    Mode::GraphemeCluster,
    Mode::ReportColorScheme,
    Mode::InBandSizeReports,
  ]

  for mode in modes {
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
  guard state.get(Mode::SendReceiveMode) else {
    fail("expected send_receive_mode default")
  }
  guard state.get(Mode::Wraparound) else { fail("expected wraparound default") }
  guard state.get(Mode::CursorVisible) else {
    fail("expected cursor_visible default")
  }
  guard state.get(Mode::MouseAlternateScroll) else {
    fail("expected mouse_alternate_scroll default")
  }
  guard state.get(Mode::IgnoreKeypadWithNumlock) else {
    fail("expected ignore_keypad_with_numlock default")
  }
  guard state.get(Mode::AltEscPrefix) else {
    fail("expected alt_esc_prefix default")
  }
  assert_eq(default_mode_packed().bits, state.values.bits)
}

///|
test "modes/state set get save restore" {
  let state = ModeState::new()
  guard !state.get(Mode::CursorKeys) else { fail("expected unset cursor_keys") }
  state.set(Mode::CursorKeys, true)
  guard state.get(Mode::CursorKeys) else { fail("expected set cursor_keys") }
  state.save(Mode::CursorKeys)
  state.set(Mode::CursorKeys, false)
  guard !state.get(Mode::CursorKeys) else {
    fail("expected cleared cursor_keys")
  }
  guard state.restore(Mode::CursorKeys) else {
    fail("expected restore to true")
  }
  guard state.get(Mode::CursorKeys) else {
    fail("expected restored cursor_keys")
  }
}

///|
test "modes/get report for known dec mode" {
  let state = ModeState::new()
  let report = state.get_report(mode_tag(1, false))
  guard report.state == ReportState::Reset else {
    fail("expected reset report")
  }
  assert_eq(report.tag.ansi(), false)
  assert_eq(report.tag.value(), 1)
}

///|
test "modes/get report for known ansi mode and unknown mode" {
  let state = ModeState::new()
  state.set(Mode::Insert, true)
  let ansi_report = state.get_report(mode_tag(4, true))
  guard ansi_report.state == ReportState::Set else {
    fail("expected set report")
  }
  assert_eq(ansi_report.tag.ansi(), true)

  let unknown = state.get_report(mode_tag(9999, false))
  guard unknown.state == ReportState::NotRecognized else {
    fail("expected not recognized report")
  }
}

///|
test "modes/report encode" {
  inspect(
    { tag: mode_tag(1, false), state: ReportState::Set }.encode(),
    content="\u{001B}[?1;1$y",
  )
  inspect(
    { tag: mode_tag(1, false), state: ReportState::Reset }.encode(),
    content="\u{001B}[?1;2$y",
  )
  inspect(
    { tag: mode_tag(4, true), state: ReportState::Set }.encode(),
    content="\u{001B}[4;1$y",
  )
  inspect(
    { tag: mode_tag(9999, false), state: ReportState::NotRecognized }.encode(),
    content="\u{001B}[?9999;0$y",
  )
  assert_eq(
    report_max_size,
    { tag: mode_tag(0x7FFF, false), state: ReportState::PermanentlyReset }
    .encode()
    .length(),
  )
}
