///|
fn make_key_event(
  key : Key,
  mods? : KeyMods = KeyMods::new(),
  utf8? : Bytes = b"",
  unshifted_codepoint? : UInt = 0U,
  action? : KeyAction = KeyAction::Press,
  consumed_mods? : KeyMods = KeyMods::new(),
  composing? : Bool = false,
) -> KeyEvent {
  let event = KeyEvent::new()
  event.set_key(key)
  event.set_mods(mods)
  event.set_utf8(utf8)
  event.set_unshifted_codepoint(unshifted_codepoint)
  event.set_action(action)
  event.set_consumed_mods(consumed_mods)
  event.set_composing(composing)
  event
}

///|
test "key encoder/new and setters expose typed owner surface" {
  let encoder = KeyEncoder::new()
  guard !encoder.cursor_key_application() &&
    !encoder.keypad_key_application() &&
    !encoder.ignore_keypad_with_numlock() &&
    !encoder.alt_esc_prefix() &&
    !encoder.modify_other_keys_state_2() &&
    encoder.kitty_flags() == KittyKeyboardFlags(0) &&
    !encoder.host_is_macos() &&
    encoder.macos_option_as_alt() == OptionAsAlt::False &&
    !encoder.backarrow_key_mode() else {
    fail("expected key encoder defaults")
  }

  encoder.set_cursor_key_application(true)
  encoder.set_keypad_key_application(true)
  encoder.set_ignore_keypad_with_numlock(true)
  encoder.set_alt_esc_prefix(true)
  encoder.set_modify_other_keys_state_2(true)
  encoder.set_kitty_flags(KittyKeyboardFlags(0xFF))
  encoder.set_host_is_macos(true)
  encoder.set_macos_option_as_alt(OptionAsAlt::Right)
  encoder.set_backarrow_key_mode(true)

  guard encoder.cursor_key_application() &&
    encoder.keypad_key_application() &&
    encoder.ignore_keypad_with_numlock() &&
    encoder.alt_esc_prefix() &&
    encoder.modify_other_keys_state_2() &&
    encoder.kitty_flags() == KittyKeyboardFlags(0x1F) &&
    encoder.host_is_macos() &&
    encoder.macos_option_as_alt() == OptionAsAlt::Right &&
    encoder.backarrow_key_mode() else {
    fail("expected key encoder setters to roundtrip")
  }
}

///|
test "key encoder/sync from terminal follows upstream terminal-derived defaults" {
  let terminal = StreamTerminal::new()
  let encoder = KeyEncoder::new()
  encoder.set_macos_option_as_alt(OptionAsAlt::True)

  terminal.mode_set(Mode::CursorKeys, true)
  terminal.mode_set(Mode::KeypadKeys, true)
  terminal.mode_set(Mode::IgnoreKeypadWithNumlock, true)
  terminal.mode_set(Mode::AltEscPrefix, true)
  terminal.mode_set(Mode::BackarrowKeyMode, true)
  terminal.next_slice(b"\x1B[>4;2m\x1B[=5;2u")

  encoder.sync_from_terminal(terminal)

  guard encoder.cursor_key_application() &&
    encoder.keypad_key_application() &&
    encoder.ignore_keypad_with_numlock() &&
    encoder.alt_esc_prefix() &&
    encoder.modify_other_keys_state_2() &&
    encoder.kitty_flags() == KittyKeyboardFlags(5) &&
    encoder.macos_option_as_alt() == OptionAsAlt::False &&
    encoder.backarrow_key_mode() else {
    fail(
      "expected sync_from_terminal to reset and copy the upstream option set",
    )
  }

  terminal.deinit()
}

///|
test "key encoder/kitty plain text control release and composing cases" {
  let encoder = KeyEncoder::new()
  encoder.set_kitty_flags(KittyKeyboardFlags(0x01))
  guard encoder.encode(make_key_event(Key::KeyA, utf8=b"abcd")) == b"abcd" else {
    fail("expected plain text with disambiguate-only kitty mode")
  }

  encoder.set_kitty_flags(KittyKeyboardFlags(0x1F))
  guard encoder.encode(
      make_key_event(
        Key::ControlLeft,
        mods=KeyMods::new().with_ctrl(true),
        action=KeyAction::Release,
      ),
    ) ==
    b"\x1B[57442;5:3u" else {
    fail("expected kitty release encoding for ctrl modifier")
  }

  encoder.set_kitty_flags(KittyKeyboardFlags(0x09))
  guard encoder.encode(
      make_key_event(
        Key::ShiftLeft,
        mods=KeyMods::new().with_shift(true),
        composing=true,
      ),
    ) ==
    b"\x1B[57441;2u" else {
    fail("expected composing modifier with report-all kitty mode")
  }

  guard encoder.encode(
      make_key_event(
        Key::KeyA,
        mods=KeyMods::new().with_shift(true),
        composing=true,
      ),
    ) ==
    b"" else {
    fail("expected composing plain keys to stay silent")
  }
}

///|
test "key encoder/kitty alternates associated text dead-key and keypad cases" {
  let encoder = KeyEncoder::new()
  encoder.set_kitty_flags(KittyKeyboardFlags(0x05))
  guard encoder.encode(
      make_key_event(
        Key::KeyA,
        mods=KeyMods::new().with_shift(true),
        utf8=b"A",
        unshifted_codepoint=b'a'.to_uint(),
      ),
    ) ==
    b"\x1B[97:65;2u" else {
    fail("expected kitty alternates for shifted ASCII")
  }

  encoder.set_kitty_flags(KittyKeyboardFlags(0x1D))
  guard encoder.encode(
      make_key_event(
        Key::KeyJ,
        mods=KeyMods::new().with_shift(true),
        utf8=b"J",
        unshifted_codepoint=b'j'.to_uint(),
      ),
    ) ==
    b"\x1B[106:74;2;74u" else {
    fail("expected kitty associated text for shifted ASCII")
  }

  guard encoder.encode(
      make_key_event(Key::Enter, utf8=b"A", unshifted_codepoint=0x0DU),
    ) ==
    b"A" else {
    fail("expected dead-key enter confirmation to pass UTF-8 text through")
  }

  guard encoder.encode(make_key_event(Key::Numpad1, utf8=b"1")) ==
    b"\x1B[57400;;49u" else {
    fail("expected kitty keypad number encoding")
  }
}

///|
test "key encoder/kitty macos option-as-alt behavior matches platform branches" {
  let encoder = KeyEncoder::new()
  encoder.set_kitty_flags(KittyKeyboardFlags(0x1D))
  encoder.set_host_is_macos(true)

  let event = make_key_event(
    Key::KeyW,
    mods=KeyMods::new().with_alt(true),
    utf8=b"\xE2\x88\x91",
    unshifted_codepoint=b'w'.to_uint(),
  )

  encoder.set_macos_option_as_alt(OptionAsAlt::False)
  guard encoder.encode(event) == b"\x1B[119;3;8721u" else {
    fail("expected option key text association when option-as-alt is false")
  }

  encoder.set_macos_option_as_alt(OptionAsAlt::True)
  guard encoder.encode(event) == b"\x1B[119;3u" else {
    fail("expected alt to suppress associated text when option-as-alt is true")
  }
}

///|
test "key encoder/legacy control and alt-prefix cases" {
  let encoder = KeyEncoder::new()

  guard encoder.encode(
      make_key_event(
        Key::KeyC,
        mods=KeyMods::new().with_ctrl(true).with_alt(true),
        utf8=b"c",
      ),
    ) ==
    b"\x1B\x03" else {
    fail("expected ctrl+alt+c legacy encoding")
  }

  encoder.set_alt_esc_prefix(true)
  encoder.set_macos_option_as_alt(OptionAsAlt::True)
  guard encoder.encode(
      make_key_event(Key::KeyC, mods=KeyMods::new().with_alt(true), utf8=b"c"),
    ) ==
    b"\x1Bc" else {
    fail("expected alt-esc-prefix encoding for text")
  }

  encoder.set_host_is_macos(true)
  encoder.set_macos_option_as_alt(OptionAsAlt::False)
  guard encoder.encode(
      make_key_event(
        Key::KeyC,
        mods=KeyMods::new().with_alt(true),
        utf8=b"\xE2\x89\x88",
        unshifted_codepoint=b'c'.to_uint(),
      ),
    ) ==
    b"\xE2\x89\x88" else {
    fail("expected macOS option text passthrough when option-as-alt is false")
  }
}

///|
test "key encoder/legacy backspace modify-other and csi-u cases" {
  let encoder = KeyEncoder::new()

  guard encoder.encode(make_key_event(Key::Backspace)) == b"\x7F" else {
    fail("expected backspace DEL with DECBKM reset")
  }
  guard encoder.encode(
      make_key_event(Key::Backspace, mods=KeyMods::new().with_ctrl(true)),
    ) ==
    b"\x08" else {
    fail("expected ctrl+backspace BS with DECBKM reset")
  }

  encoder.set_backarrow_key_mode(true)
  guard encoder.encode(make_key_event(Key::Backspace)) == b"\x08" &&
    encoder.encode(
      make_key_event(Key::Backspace, mods=KeyMods::new().with_ctrl(true)),
    ) ==
    b"\x7F" else {
    fail("expected DECBKM inversion for backspace")
  }

  encoder.set_backarrow_key_mode(false)
  encoder.set_modify_other_keys_state_2(true)
  guard encoder.encode(
      make_key_event(
        Key::KeyH,
        mods=KeyMods::new().with_ctrl(true).with_shift(true),
        utf8=b"H",
      ),
    ) ==
    b"\x1B[27;6;72~" else {
    fail("expected modify-other-keys state 2 encoding")
  }

  encoder.set_modify_other_keys_state_2(false)
  guard encoder.encode(
      make_key_event(Key::KeyI, mods=KeyMods::new().with_ctrl(true), utf8=b"i"),
    ) ==
    b"\x1B[105;5u" else {
    fail("expected fixterms awkward-letter fallback")
  }

  guard encoder.encode(
      make_key_event(
        Key::KeyM,
        mods=KeyMods::new().with_ctrl(true).with_shift(true),
        utf8=b"M",
        unshifted_codepoint=b'm'.to_uint(),
      ),
    ) ==
    b"\x1B[109;6u" else {
    fail("expected CSI-u for ctrl+shift+letter ASCII")
  }

  guard encoder.encode(
      make_key_event(
        Key::BracketLeft,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b"\xC5\x91",
        unshifted_codepoint=337U,
      ),
    ) ==
    b"\x1B[337;5u" else {
    fail("expected layout-preserving CSI-u fallback")
  }
}

///|
test "key encoder/legacy function key and keypad application paths" {
  let encoder = KeyEncoder::new()

  guard encoder.encode(
      make_key_event(
        Key::ArrowUp,
        mods=KeyMods::new().with_shift(true),
        consumed_mods=KeyMods::new().with_shift(true),
      ),
    ) ==
    b"\x1B[1;2A" else {
    fail("expected shift+up legacy function-key encoding")
  }

  guard encoder.encode(make_key_event(Key::Numpad1, utf8=b"1")) == b"1" else {
    fail("expected keypad text in numeric mode")
  }

  encoder.set_keypad_key_application(true)
  guard encoder.encode(make_key_event(Key::Numpad1, utf8=b"1")) == b"\x1BOq" else {
    fail("expected keypad application sequence")
  }

  encoder.set_ignore_keypad_with_numlock(true)
  guard encoder.encode(
      make_key_event(
        Key::Numpad1,
        mods=KeyMods::new().with_num_lock(true),
        utf8=b"1",
      ),
    ) ==
    b"1" else {
    fail("expected ignore-keypad-with-numlock to force numeric keypad behavior")
  }

  encoder.set_ignore_keypad_with_numlock(false)
  guard encoder.encode(
      make_key_event(Key::F5, mods=KeyMods::new().with_ctrl(true)),
    ) ==
    b"\x1B[15;5~" else {
    fail("expected ctrl+f5 legacy function-key encoding")
  }
}

///|
test "key encoder/kitty release gates and modifier suppression" {
  let encoder = KeyEncoder::new()

  encoder.set_kitty_flags(KittyKeyboardFlags(0x01))
  guard encoder.encode(make_key_event(Key::F1, action=KeyAction::Release)) ==
    b"" else {
    fail("expected kitty release to stay silent without report-events")
  }

  encoder.set_kitty_flags(KittyKeyboardFlags(0x02))
  guard encoder.encode(make_key_event(Key::Enter, action=KeyAction::Release)) ==
    b"" else {
    fail("expected kitty enter release to stay silent without report-all")
  }

  guard encoder.encode(make_key_event(Key::F1, action=KeyAction::Release)) ==
    b"\x1B[1;1:3P" else {
    fail(
      "expected kitty non-legacy release keys to keep reporting with report-events",
    )
  }

  encoder.set_kitty_flags(KittyKeyboardFlags(0x01))
  guard encoder.encode(
      make_key_event(Key::Enter, utf8=b"\r", unshifted_codepoint=0x0DU),
    ) ==
    b"\r" else {
    fail("expected kitty enter to preserve the legacy CR byte")
  }

  guard encoder.encode(make_key_event(Key::Tab)) == b"\t" else {
    fail("expected kitty tab to preserve the legacy HT byte")
  }

  guard encoder.encode(make_key_event(Key::Backspace)) == b"\x7F" else {
    fail("expected kitty backspace to preserve the legacy DEL byte")
  }

  guard encoder.encode(
      make_key_event(Key::Backspace, utf8=b"A", unshifted_codepoint=0x7FU),
    ) ==
    b"" else {
    fail("expected kitty backspace IME confirmation to stay silent")
  }

  guard encoder.encode(make_key_event(Key::CapsLock)) == b"" else {
    fail("expected modifier-only kitty events to require report-all")
  }
}

///|
test "key encoder/kitty alternates associated text and special keys" {
  let encoder = KeyEncoder::new()

  encoder.set_kitty_flags(KittyKeyboardFlags(0x01))
  guard encoder.encode(
      make_key_event(
        Key::Unidentified,
        mods=KeyMods::new().with_alt(true),
        utf8=b"X",
      ),
    ) ==
    b"X" else {
    fail(
      "expected unmatched kitty entries with modified text to pass bytes through",
    )
  }

  encoder.set_kitty_flags(KittyKeyboardFlags(0x10))
  guard encoder.encode(
      make_key_event(
        Key::KeyA,
        utf8=b"\xC3\x28",
        unshifted_codepoint=b'a'.to_uint(),
      ),
    ) ==
    b"\x1B[97u" else {
    fail(
      "expected invalid UTF-8 associated text to be dropped from kitty payloads",
    )
  }

  guard encoder.encode(
      make_key_event(
        Key::KeyA,
        utf8=b"\x01AB",
        unshifted_codepoint=b'a'.to_uint(),
      ),
    ) ==
    b"\x1B[97;;65:66u" else {
    fail("expected kitty associated text to skip controls and keep later runes")
  }

  encoder.set_kitty_flags(KittyKeyboardFlags(0x04))
  guard encoder.encode(
      make_key_event(
        Key::Numpad1,
        mods=KeyMods::new().with_shift(true),
        utf8=b"!",
      ),
    ) ==
    b"\x1B[57400:33:49;2u" else {
    fail(
      "expected kitty alternates to report shifted and base keypad codepoints",
    )
  }

  guard encoder.encode(
      make_key_event(
        Key::NumpadUp,
        mods=KeyMods::new().with_shift(true),
        utf8=b"A",
      ),
    ) ==
    b"\x1B[57419:65;2u" else {
    fail("expected kitty alternates to tolerate keys without base codepoints")
  }

  guard encoder.encode(make_key_event(Key::Numpad1)) == b"\x1B[57400::49u" else {
    fail(
      "expected kitty alternates to synthesize a base keypad codepoint without UTF-8",
    )
  }

  encoder.set_host_is_macos(true)
  encoder.set_macos_option_as_alt(OptionAsAlt::Left)
  encoder.set_kitty_flags(KittyKeyboardFlags(0x10))
  guard encoder.encode(
      make_key_event(
        Key::KeyW,
        mods=KeyMods::new().with_alt(true).with_alt_side(KeyModSide::Left),
        utf8=b"\xE2\x88\x91",
        unshifted_codepoint=b'w'.to_uint(),
      ),
    ) ==
    b"\x1B[119;3u" else {
    fail(
      "expected left-option-as-alt to suppress kitty associated text on macOS",
    )
  }

  encoder.set_host_is_macos(false)
  encoder.set_kitty_flags(KittyKeyboardFlags(0x08))
  guard encoder.encode(make_key_event(Key::F1)) == b"\x1B[P" else {
    fail("expected kitty special-key encoding without modifiers")
  }

  guard encoder.encode(
      make_key_event(Key::F1, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"\x1B[1;2P" else {
    fail("expected kitty special-key encoding with modifiers")
  }

  encoder.set_kitty_flags(KittyKeyboardFlags(0x0A))
  guard encoder.encode(make_key_event(Key::F1, action=KeyAction::Release)) ==
    b"\x1B[1;1:3P" else {
    fail("expected kitty special-key release encoding with report-events")
  }

  guard encoder.encode(
      make_key_event(Key::KeyA, utf8=b"a", unshifted_codepoint=b'a'.to_uint()),
    ) ==
    b"\x1B[97u" &&
    encoder.encode(
      make_key_event(
        Key::KeyA,
        utf8=b"a",
        unshifted_codepoint=b'a'.to_uint(),
        action=KeyAction::Repeat,
      ),
    ) ==
    b"\x1B[97;1:2u" else {
    fail("expected kitty press and repeat event coverage for text keys")
  }
}

///|
test "key encoder/legacy guard and ctrl fallback coverage" {
  let encoder = KeyEncoder::new()

  guard encoder.encode(
      make_key_event(Key::KeyA, utf8=b"a", action=KeyAction::Release),
    ) ==
    b"" else {
    fail("expected legacy release events to stay silent")
  }

  guard encoder.encode(make_key_event(Key::KeyA, utf8=b"a", composing=true)) ==
    b"" else {
    fail("expected legacy composing text to stay silent")
  }

  guard encoder.encode(
      make_key_event(
        Key::Backspace,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b"\x08",
      ),
    ) ==
    b"\x08" else {
    fail("expected legacy ctrl+backspace to preserve the control byte")
  }

  guard encoder.encode(make_key_event(Key::Backspace, utf8=b"A")) == b"" else {
    fail("expected legacy backspace IME confirmation to stay silent")
  }

  encoder.set_alt_esc_prefix(true)
  guard encoder.encode(
      make_key_event(
        Key::Unidentified,
        mods=KeyMods::new().with_alt(true),
        unshifted_codepoint=256U,
      ),
    ) ==
    b"" else {
    fail("expected missing legacy alt-prefix payloads to stay silent")
  }

  encoder.set_alt_esc_prefix(false)
  encoder.set_modify_other_keys_state_2(true)
  guard encoder.encode(
      make_key_event(Key::Digit1, utf8=b"1", unshifted_codepoint=b'1'.to_uint()),
    ) ==
    b"1" else {
    fail("expected state-2 modify-other-keys to ignore unmodified punctuation")
  }

  guard encoder.encode(
      make_key_event(Key::KeyA, utf8=b"ab", unshifted_codepoint=b'a'.to_uint()),
    ) ==
    b"ab" else {
    fail(
      "expected multi-codepoint modify-other-keys input to fall back to raw text",
    )
  }

  encoder.set_modify_other_keys_state_2(false)
  guard encoder.encode(
      make_key_event(
        Key::Unidentified,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b"\xC3\x28",
      ),
    ) ==
    b"\xC3\x28" else {
    fail("expected legacy invalid UTF-8 ctrl cases to fall back to raw bytes")
  }

  encoder.set_host_is_macos(true)
  guard encoder.encode(
      make_key_event(
        Key::KeyX,
        mods=KeyMods::new().with_super_(true),
        utf8=b"x",
      ),
    ) ==
    b"" else {
    fail("expected legacy macOS super-modified text to stay silent")
  }
}

///|
test "key encoder/legacy macos option-as-alt branches" {
  let encoder = KeyEncoder::new()
  encoder.set_host_is_macos(true)
  encoder.set_modify_other_keys_state_2(true)

  let alt_left = KeyMods::new().with_alt(true).with_alt_side(KeyModSide::Left)
  let alt_right = KeyMods::new().with_alt(true).with_alt_side(KeyModSide::Right)

  encoder.set_macos_option_as_alt(OptionAsAlt::False)
  guard encoder.encode(
      make_key_event(
        Key::KeyC,
        mods=alt_left,
        utf8=b"c",
        unshifted_codepoint=b'c'.to_uint(),
      ),
    ) ==
    b"c" else {
    fail(
      "expected macOS option-as-alt false to drop alt from modify-other-keys",
    )
  }

  encoder.set_macos_option_as_alt(OptionAsAlt::Left)
  guard encoder.encode(
      make_key_event(
        Key::KeyC,
        mods=alt_left,
        utf8=b"c",
        unshifted_codepoint=b'c'.to_uint(),
      ),
    ) ==
    b"\x1B[27;3;99~" else {
    fail(
      "expected left option-as-alt to preserve left alt in modify-other-keys",
    )
  }

  guard encoder.encode(
      make_key_event(
        Key::KeyC,
        mods=alt_right,
        utf8=b"c",
        unshifted_codepoint=b'c'.to_uint(),
      ),
    ) ==
    b"c" else {
    fail("expected left option-as-alt to ignore right alt in modify-other-keys")
  }

  encoder.set_macos_option_as_alt(OptionAsAlt::Right)
  guard encoder.encode(
      make_key_event(
        Key::KeyC,
        mods=alt_left,
        utf8=b"c",
        unshifted_codepoint=b'c'.to_uint(),
      ),
    ) ==
    b"c" else {
    fail("expected right option-as-alt to ignore left alt in modify-other-keys")
  }

  encoder.set_macos_option_as_alt(OptionAsAlt::True)
  guard encoder.encode(
      make_key_event(
        Key::KeyC,
        mods=alt_left,
        utf8=b"c",
        unshifted_codepoint=b'c'.to_uint(),
      ),
    ) ==
    b"\x1B[27;3;99~" else {
    fail("expected option-as-alt true to keep alt in modify-other-keys")
  }

  guard encoder.encode(
      make_key_event(
        Key::Space,
        mods=alt_left,
        utf8=b" ",
        unshifted_codepoint=b' '.to_uint(),
      ),
    ) ==
    b"\x1B[27;3;32~" else {
    fail("expected modify-other-keys to keep non-shift modifiers for space")
  }

  encoder.set_modify_other_keys_state_2(false)
  encoder.set_alt_esc_prefix(true)
  encoder.set_macos_option_as_alt(OptionAsAlt::Left)
  guard encoder.encode(
      make_key_event(
        Key::KeyA,
        mods=alt_right,
        unshifted_codepoint=b'A'.to_uint(),
      ),
    ) ==
    b"" else {
    fail("expected left option-as-alt to block right-alt ESC prefix payloads")
  }

  encoder.set_macos_option_as_alt(OptionAsAlt::Right)
  guard encoder.encode(
      make_key_event(
        Key::KeyA,
        mods=alt_left,
        unshifted_codepoint=b'A'.to_uint(),
      ),
    ) ==
    b"" else {
    fail("expected right option-as-alt to block left-alt ESC prefix payloads")
  }

  encoder.set_macos_option_as_alt(OptionAsAlt::True)
  guard encoder.encode(
      make_key_event(
        Key::KeyA,
        mods=alt_left,
        unshifted_codepoint=b'A'.to_uint(),
      ),
    ) ==
    b"\x1BA" else {
    fail("expected option-as-alt true to keep the ESC prefix payload")
  }
}

///|
test "key encoder/legacy ctrl sequence coverage" {
  let encoder = KeyEncoder::new()

  guard encoder.encode(
      make_key_event(
        Key::KeyA,
        mods=KeyMods::new().with_ctrl(true).with_shift(true),
      ),
    ) ==
    b"" else {
    fail(
      "expected ctrl+shift letter without UTF-8 to miss the legacy ctrl table",
    )
  }

  guard encoder.encode(
      make_key_event(Key::Unidentified, mods=KeyMods::new().with_ctrl(true)),
    ) ==
    b"" else {
    fail("expected unidentified ctrl keys without UTF-8 to stay silent")
  }

  guard encoder.encode(
      make_key_event(
        Key::Slash,
        mods=KeyMods::new().with_ctrl(true).with_shift(true),
        utf8=b"/",
        unshifted_codepoint=b'/'.to_uint(),
      ),
    ) ==
    b"\x1F" else {
    fail("expected ctrl+shift slash to drop shift before legacy ctrl encoding")
  }

  guard encoder.encode(
      make_key_event(
        Key::Space,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b" ",
        unshifted_codepoint=b' '.to_uint(),
      ),
    ) ==
    b"\x00" else {
    fail("expected ctrl+space to map to NUL")
  }

  guard encoder.encode(
      make_key_event(
        Key::Digit0,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b"0",
        unshifted_codepoint=b'0'.to_uint(),
      ),
    ) ==
    b"0" else {
    fail("expected ctrl+0 to keep the digit byte")
  }

  guard encoder.encode(
      make_key_event(
        Key::Digit1,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b"1",
        unshifted_codepoint=b'1'.to_uint(),
      ),
    ) ==
    b"1" else {
    fail("expected ctrl+1 to keep the digit byte")
  }

  guard encoder.encode(
      make_key_event(
        Key::KeyD,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b"d",
        unshifted_codepoint=b'd'.to_uint(),
      ),
    ) ==
    b"\x04" else {
    fail("expected ctrl+d to map to EOT")
  }

  guard encoder.encode(
      make_key_event(
        Key::KeyE,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b"e",
        unshifted_codepoint=b'e'.to_uint(),
      ),
    ) ==
    b"\x05" else {
    fail("expected ctrl+e to map to ENQ")
  }

  guard encoder.encode(
      make_key_event(
        Key::KeyF,
        mods=KeyMods::new().with_ctrl(true),
        utf8=b"f",
        unshifted_codepoint=b'f'.to_uint(),
      ),
    ) ==
    b"\x06" else {
    fail("expected ctrl+f to map to ACK")
  }
}

///|
test "key encoder/legacy function key matrix coverage" {
  let encoder = KeyEncoder::new()

  guard encoder.encode(make_key_event(Key::ArrowDown)) == b"\x1B[B" else {
    fail("expected cursor-down CSI fallback")
  }

  encoder.set_cursor_key_application(true)
  guard encoder.encode(make_key_event(Key::ArrowDown)) == b"\x1BOB" else {
    fail("expected cursor-down SS3 application mode sequence")
  }

  encoder.set_cursor_key_application(false)
  guard encoder.encode(make_key_event(Key::F2)) == b"\x1BOQ" &&
    encoder.encode(make_key_event(Key::F3)) == b"\x1BOR" &&
    encoder.encode(
      make_key_event(Key::F3, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"\x1B[13;2~" &&
    encoder.encode(make_key_event(Key::F4)) == b"\x1BOS" &&
    encoder.encode(make_key_event(Key::F6)) == b"\x1B[17~" &&
    encoder.encode(make_key_event(Key::F7)) == b"\x1B[18~" &&
    encoder.encode(make_key_event(Key::F8)) == b"\x1B[19~" &&
    encoder.encode(
      make_key_event(Key::F1, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"\x1B[1;2P" else {
    fail("expected function-key matrix coverage for F3/F4/F6")
  }

  guard encoder.encode(make_key_event(Key::Numpad2, utf8=b"2")) == b"2" &&
    encoder.encode(make_key_event(Key::Numpad3, utf8=b"3")) == b"3" &&
    encoder.encode(make_key_event(Key::Numpad4, utf8=b"4")) == b"4" &&
    encoder.encode(make_key_event(Key::NumpadUp)) == b"\x1B[A" &&
    encoder.encode(make_key_event(Key::NumpadDown)) == b"\x1B[B" &&
    encoder.encode(make_key_event(Key::NumpadRight)) == b"\x1B[C" else {
    fail("expected numeric keypad fallback coverage")
  }

  guard encoder.encode(make_key_event(Key::ArrowRight)) == b"\x1B[C" else {
    fail("expected cursor-right CSI fallback")
  }

  guard encoder.encode(make_key_event(Key::ArrowLeft)) == b"\x1B[D" else {
    fail("expected cursor-left CSI fallback")
  }

  encoder.set_keypad_key_application(true)
  guard encoder.encode(make_key_event(Key::NumpadEnter)) == b"\x1BOM" &&
    encoder.encode(
      make_key_event(Key::NumpadEnter, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"\x1BO2M" else {
    fail("expected keypad enter application coverage")
  }

  guard encoder.encode(
      make_key_event(Key::Numpad3, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"\x1BO2s" else {
    fail("expected keypad application coverage for modified keypad digits")
  }

  encoder.set_keypad_key_application(false)
  guard encoder.encode(make_key_event(Key::NumpadEnter)) == b"\r" else {
    fail("expected keypad enter to fall back to CR outside application mode")
  }

  guard encoder.encode(
      make_key_event(Key::NumpadEnter, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"" &&
    encoder.encode(
      make_key_event(Key::Numpad2, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"" else {
    fail(
      "expected keypad modifier paths to stay silent outside application mode",
    )
  }

  guard encoder.encode(make_key_event(Key::Tab)) == b"\t" else {
    fail("expected plain tab encoding")
  }

  guard encoder.encode(
      make_key_event(Key::Tab, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"\x1B[Z" &&
    encoder.encode(make_key_event(Key::Tab, mods=KeyMods::new().with_alt(true))) ==
    b"\x1B\t" else {
    fail("expected tab shift/alt fallback coverage")
  }

  encoder.set_modify_other_keys_state_2(true)
  guard encoder.encode(
      make_key_event(Key::Tab, mods=KeyMods::new().with_shift(true)),
    ) ==
    b"\x1B[27;2;9~" &&
    encoder.encode(make_key_event(Key::Tab, mods=KeyMods::new().with_alt(true))) ==
    b"\x1B[27;3;9~" &&
    encoder.encode(
      make_key_event(Key::Tab, mods=KeyMods::new().with_ctrl(true)),
    ) ==
    b"\x1B[27;5;9~" else {
    fail("expected modify-other-keys tab coverage")
  }

  encoder.set_modify_other_keys_state_2(false)
  guard encoder.encode(make_key_event(Key::Enter)) == b"\r" &&
    encoder.encode(
      make_key_event(Key::Enter, mods=KeyMods::new().with_alt(true)),
    ) ==
    b"\x1B\r" else {
    fail("expected enter fallback coverage")
  }

  encoder.set_modify_other_keys_state_2(true)
  guard encoder.encode(
      make_key_event(Key::Enter, mods=KeyMods::new().with_ctrl(true)),
    ) ==
    b"\x1B[27;5;13~" else {
    fail("expected modify-other-keys enter coverage")
  }

  encoder.set_modify_other_keys_state_2(false)
  guard encoder.encode(make_key_event(Key::Escape)) == b"\x1B" &&
    encoder.encode(
      make_key_event(Key::Escape, mods=KeyMods::new().with_alt(true)),
    ) ==
    b"\x1B\x1B" else {
    fail("expected escape fallback coverage")
  }

  encoder.set_modify_other_keys_state_2(true)
  guard encoder.encode(
      make_key_event(Key::Escape, mods=KeyMods::new().with_ctrl(true)),
    ) ==
    b"\x1B[27;5;27~" &&
    encoder.encode(
      make_key_event(Key::Backspace, mods=KeyMods::new().with_alt(true)),
    ) ==
    b"\x1B[27;3;127~" &&
    encoder.encode(
      make_key_event(Key::Backspace, mods=KeyMods::new().with_ctrl(true)),
    ) ==
    b"\x08" else {
    fail("expected modify-other-keys escape and backspace coverage")
  }

  encoder.set_modify_other_keys_state_2(false)
  guard encoder.encode(
      make_key_event(Key::Backspace, mods=KeyMods::new().with_alt(true)),
    ) ==
    b"\x1B\x7F" else {
    fail("expected legacy alt+backspace fallback coverage")
  }
}

///|
test "key encoder/kitty right-option associated-text suppression" {
  let encoder = KeyEncoder::new()
  encoder.set_host_is_macos(true)
  encoder.set_macos_option_as_alt(OptionAsAlt::Right)
  encoder.set_kitty_flags(KittyKeyboardFlags(0x10))

  guard encoder.encode(
      make_key_event(
        Key::KeyW,
        mods=KeyMods::new().with_alt(true).with_alt_side(KeyModSide::Right),
        utf8=b"\xE2\x88\x91",
        unshifted_codepoint=b'w'.to_uint(),
      ),
    ) ==
    b"\x1B[119;3u" else {
    fail("expected right-option-as-alt to suppress kitty associated text")
  }
}
