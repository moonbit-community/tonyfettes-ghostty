///|
test "terminal input flags/defaults and full reset" {
  let state = TerminalInputFlags::new()
  guard state.mouse_shift_capture() == None && !state.modify_other_keys_2() else {
    fail("expected terminal input flag defaults")
  }

  state.set_mouse_shift_capture(true)
  state.apply_modify_key_format(OtherKeysNumeric)
  state.full_reset()
  guard state.mouse_shift_capture() == None && !state.modify_other_keys_2() else {
    fail("expected terminal input flag full reset")
  }
}

///|
test "terminal input flags/mouse shift capture and modify other keys" {
  let state = TerminalInputFlags::new()
  state.set_mouse_shift_capture(true)
  guard state.mouse_shift_capture() == Some(true) else {
    fail("expected enabled mouse shift capture")
  }

  state.set_mouse_shift_capture(false)
  guard state.mouse_shift_capture() == Some(false) else {
    fail("expected disabled mouse shift capture")
  }

  state.apply_modify_key_format(OtherKeysNumeric)
  guard state.modify_other_keys_2() else {
    fail("expected numeric other-keys mode to enable modify_other_keys_2")
  }

  state.apply_modify_key_format(CursorKeys)
  guard !state.modify_other_keys_2() else {
    fail("expected non-numeric key format to disable modify_other_keys_2")
  }
}

///|
test "kitty keyboard state/current set and bit operations" {
  let state = KittyKeyboardState::new()
  guard state.current() == KittyKeyboardFlags(0) else {
    fail("expected kitty keyboard defaults")
  }

  state.set(KittyKeyboardFlags(0x01))
  state.set_or(KittyKeyboardFlags(0x02))
  guard state.current() == KittyKeyboardFlags(0x03) else {
    fail("expected kitty keyboard set-or semantics")
  }

  state.set_not(KittyKeyboardFlags(0x01))
  guard state.current() == KittyKeyboardFlags(0x02) else {
    fail("expected kitty keyboard set-not semantics")
  }
}

///|
test "kitty keyboard state/push and pop follow stack order" {
  let state = KittyKeyboardState::new()
  state.push(KittyKeyboardFlags(0x01))
  state.push(KittyKeyboardFlags(0x02))
  guard state.current() == KittyKeyboardFlags(0x02) else {
    fail("expected last pushed kitty keyboard flags")
  }

  state.pop(1)
  guard state.current() == KittyKeyboardFlags(0x01) else {
    fail("expected kitty keyboard pop to reveal prior flags")
  }

  state.pop(1)
  guard state.current() == KittyKeyboardFlags(0x00) else {
    fail("expected kitty keyboard pop to restore disabled flags")
  }
}

///|
test "kitty keyboard state/push wraps and large pop resets" {
  let state = KittyKeyboardState::new()
  for i in 1..<9 {
    state.push(KittyKeyboardFlags(i.to_byte()))
  }
  guard state.current() == KittyKeyboardFlags(0x08) else {
    fail("expected kitty keyboard ring wrap to preserve latest flags")
  }

  state.pop(1)
  guard state.current() == KittyKeyboardFlags(0x07) else {
    fail("expected kitty keyboard wraparound pop to reveal prior slot")
  }

  state.pop(8)
  guard state.current() == KittyKeyboardFlags(0x00) else {
    fail("expected large kitty keyboard pop to reset the stack")
  }
}
