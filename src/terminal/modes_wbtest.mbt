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
  assert_eq(
    { tag: mode_tag(1, false), state: ReportState::Set }.encode(),
    b"\x1B[?1;1$y",
  )
  assert_eq(
    { tag: mode_tag(1, false), state: ReportState::Reset }.encode(),
    b"\x1B[?1;2$y",
  )
  assert_eq(
    { tag: mode_tag(4, true), state: ReportState::Set }.encode(),
    b"\x1B[4;1$y",
  )
  assert_eq(
    { tag: mode_tag(9999, false), state: ReportState::NotRecognized }.encode(),
    b"\x1B[?9999;0$y",
  )
  assert_eq(
    report_max_size,
    { tag: mode_tag(0x7FFF, false), state: ReportState::PermanentlyReset }
    .encode()
    .length(),
  )
}

///|
test "modes/packed state exercises set clear no-op and reset paths" {
  let packed = empty_mode_packed()
  guard !packed.get(Mode::CursorKeys) else {
    fail("expected cursor keys to start unset")
  }
  packed.set(Mode::CursorKeys, false)
  guard !packed.get(Mode::CursorKeys) else {
    fail("expected clearing an unset mode to remain unset")
  }
  packed.set(Mode::CursorKeys, true)
  guard packed.get(Mode::CursorKeys) else {
    fail("expected cursor keys to be set")
  }
  packed.set(Mode::CursorKeys, false)
  guard !packed.get(Mode::CursorKeys) else {
    fail("expected cursor keys to clear")
  }

  let state = ModeState::new()
  state.set(Mode::CursorKeys, true)
  state.save(Mode::CursorKeys)
  state.set(Mode::CursorKeys, false)
  state.reset()
  guard !state.get(Mode::CursorKeys) else {
    fail("expected reset to restore defaults")
  }
  guard !state.restore(Mode::ReverseWrap) else {
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

  assert_eq(mode_bit_index(Mode::DisableKeyboard), 0)
  assert_eq(mode_bit_index(Mode::Linefeed), 3)
  assert_eq(mode_bit_index(Mode::Mode132Column), 5)
  assert_eq(mode_bit_index(Mode::SlowScroll), 6)
  assert_eq(mode_bit_index(Mode::ReverseColors), 7)
  assert_eq(mode_bit_index(Mode::Origin), 8)
  assert_eq(mode_bit_index(Mode::MouseEventX10), 11)
  assert_eq(mode_bit_index(Mode::CursorBlinking), 12)
  assert_eq(mode_bit_index(Mode::Autorepeat), 10)
  assert_eq(mode_bit_index(Mode::EnableMode3), 14)
  assert_eq(mode_bit_index(Mode::AltScreenLegacy), 16)
  assert_eq(mode_bit_index(Mode::KeypadKeys), 17)
  assert_eq(mode_bit_index(Mode::BackarrowKeyMode), 18)
  assert_eq(mode_bit_index(Mode::EnableLeftAndRightMargin), 19)
  assert_eq(mode_bit_index(Mode::MouseEventNormal), 20)
  assert_eq(mode_bit_index(Mode::MouseEventButton), 21)
  assert_eq(mode_bit_index(Mode::MouseEventAny), 22)
  assert_eq(mode_bit_index(Mode::FocusEvent), 23)
  assert_eq(mode_bit_index(Mode::MouseFormatUtf8), 24)
  assert_eq(mode_bit_index(Mode::MouseFormatSgr), 25)
  assert_eq(mode_bit_index(Mode::MouseFormatUrxvt), 27)
  assert_eq(mode_bit_index(Mode::MouseFormatSgrPixels), 28)
  assert_eq(mode_bit_index(Mode::AltSendsEscape), 31)
  assert_eq(mode_bit_index(Mode::ReverseWrapExtended), 32)
  assert_eq(mode_bit_index(Mode::AltScreen), 33)
  assert_eq(mode_bit_index(Mode::SaveCursor), 34)
  assert_eq(mode_bit_index(Mode::AltScreenSaveCursorClearEnter), 35)
  assert_eq(mode_bit_index(Mode::BracketedPaste), 36)
  assert_eq(mode_bit_index(Mode::SynchronizedOutput), 37)
  assert_eq(mode_bit_index(Mode::GraphemeCluster), 38)
  assert_eq(mode_bit_index(Mode::ReportColorScheme), 39)
  assert_eq(mode_bit_index(Mode::InBandSizeReports), 40)
  assert_eq(mode_mask(Mode::DisableKeyboard), 1UL)
  assert_eq(mode_mask(Mode::InBandSizeReports), 1UL << 40)
}
