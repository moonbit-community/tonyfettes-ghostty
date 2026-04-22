///|
test "key mods/builders and helpers preserve the upstream bit semantics" {
  let mods = KeyMods::new()
    .with_shift(true)
    .with_ctrl(true)
    .with_alt(true)
    .with_super_(true)
    .with_caps_lock(true)
    .with_num_lock(true)
    .with_shift_side(KeyModSide::Right)
    .with_ctrl_side(KeyModSide::Right)
    .with_alt_side(KeyModSide::Right)
    .with_super_side(KeyModSide::Right)

  guard mods.shift() && mods.ctrl() && mods.alt() && mods.super_() else {
    fail("expected primary modifier bits to be set")
  }
  guard mods.caps_lock() && mods.num_lock() else {
    fail("expected lock modifiers to be set")
  }
  guard mods.shift_side() == KeyModSide::Right else {
    fail("expected right shift side")
  }
  guard mods.ctrl_side() == KeyModSide::Right else {
    fail("expected right ctrl side")
  }
  guard mods.alt_side() == KeyModSide::Right else {
    fail("expected right alt side")
  }
  guard mods.super_side() == KeyModSide::Right else {
    fail("expected right super side")
  }
  guard !mods.empty() else { fail("expected non-empty modifier set") }

  let binding = mods.binding()
  guard binding.shift() && binding.ctrl() && binding.alt() && binding.super_() else {
    fail("expected binding modifiers to keep the bindable bits")
  }
  guard !binding.caps_lock() && !binding.num_lock() else {
    fail("binding modifiers should drop lock bits")
  }
  guard binding.shift_side() == KeyModSide::Left else {
    fail("binding modifiers should clear side metadata")
  }

  let cleared = mods.unset(KeyMods::new().with_shift(true).with_alt(true))
  guard !cleared.shift() && !cleared.alt() else {
    fail("unset should clear requested modifier bits")
  }
  guard cleared.ctrl() && cleared.super_() else {
    fail("unset should preserve unrelated bits")
  }

  let unlocked = mods.without_locks()
  guard !unlocked.caps_lock() && !unlocked.num_lock() else {
    fail("without_locks should clear lock bits")
  }
  guard unlocked.shift() &&
    unlocked.ctrl() &&
    unlocked.alt() &&
    unlocked.super_() else {
    fail("without_locks should keep the primary modifiers")
  }

  let toggled_off = mods.with_shift(false)
  guard !toggled_off.shift() else {
    fail("with_shift(false) should clear the shift bit")
  }
}

///|
test "key/codepoint covers printable and non-printable keys" {
  assert_eq(Key::KeyA.codepoint(), Some(b'a'.to_uint()))
  assert_eq(Key::KeyB.codepoint(), Some(b'b'.to_uint()))
  assert_eq(Key::KeyC.codepoint(), Some(b'c'.to_uint()))
  assert_eq(Key::KeyD.codepoint(), Some(b'd'.to_uint()))
  assert_eq(Key::Digit7.codepoint(), Some(b'7'.to_uint()))
  assert_eq(Key::Digit8.codepoint(), Some(b'8'.to_uint()))
  assert_eq(Key::Digit9.codepoint(), Some(b'9'.to_uint()))
  assert_eq(Key::Semicolon.codepoint(), Some(b';'.to_uint()))
  assert_eq(Key::Tab.codepoint(), Some(0x09U))
  assert_eq(Key::NumpadEqual.codepoint(), Some(b'='.to_uint()))
  assert_eq(Key::BracketLeft.codepoint(), Some(b'['.to_uint()))
  assert_eq(Key::BracketRight.codepoint(), Some(b']'.to_uint()))
  assert_eq(Key::Backslash.codepoint(), Some(b'\\'.to_uint()))
  assert_eq(Key::NumpadDecimal.codepoint(), Some(b'.'.to_uint()))
  assert_eq(Key::NumpadDivide.codepoint(), Some(b'/'.to_uint()))
  assert_eq(Key::NumpadMultiply.codepoint(), Some(b'*'.to_uint()))
  assert_eq(Key::Enter.codepoint(), None)
}

///|
test "key event/defaults and setters roundtrip" {
  let event = KeyEvent::new()
  guard event.action() == KeyAction::Press else {
    fail("new key events should default to press")
  }
  guard event.key() == Key::Unidentified else {
    fail("new key events should default to unidentified")
  }
  guard event.mods() == KeyMods::new() else {
    fail("new key events should start with empty modifiers")
  }
  guard event.consumed_mods() == KeyMods::new() else {
    fail("new key events should start with empty consumed modifiers")
  }
  guard !event.composing() else { fail("new key events should not compose") }
  assert_eq(event.utf8(), b"")
  assert_eq(event.unshifted_codepoint(), 0U)

  let mods = KeyMods::new().with_alt(true).with_super_(true)
  let consumed = KeyMods::new().with_alt(true)
  event.set_action(KeyAction::Repeat)
  event.set_key(Key::KeyZ)
  event.set_mods(mods)
  event.set_consumed_mods(consumed)
  event.set_composing(true)
  event.set_utf8(b"test")
  event.set_unshifted_codepoint(b'z'.to_uint())

  guard event.action() == KeyAction::Repeat else {
    fail("expected repeat action")
  }
  guard event.key() == Key::KeyZ else { fail("expected key z") }
  guard event.mods() == mods else { fail("expected stored modifier set") }
  guard event.consumed_mods() == consumed else {
    fail("expected stored consumed modifier set")
  }
  guard event.composing() else { fail("expected composing key event") }
  assert_eq(event.utf8(), b"test")
  assert_eq(event.unshifted_codepoint(), b'z'.to_uint())
}

///|
test "key event/effective mods only remove consumed text modifiers" {
  let event = KeyEvent::new()
  let mods = KeyMods::new().with_shift(true).with_ctrl(true)
  event.set_mods(mods)
  event.set_consumed_mods(KeyMods::new().with_shift(true))

  guard event.effective_mods() == mods else {
    fail("empty utf8 should preserve the original modifier set")
  }

  event.set_utf8(b"A")
  let effective = event.effective_mods()
  guard !effective.shift() else {
    fail("expected consumed shift to be removed once utf8 text exists")
  }
  guard effective.ctrl() else { fail("expected ctrl to remain active") }
}
