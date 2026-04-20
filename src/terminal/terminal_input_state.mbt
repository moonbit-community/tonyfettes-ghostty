///|
const KittyKeyboardStackLen : Int = 8

///|
const KittyKeyboardFlagsMask : Byte = 0x1F

///|
struct TerminalInputFlags {
  mut mouse_shift_capture : Bool?
  mut modify_other_keys_2 : Bool
} derive(Eq, Debug)

///|
pub fn TerminalInputFlags::new() -> TerminalInputFlags {
  { mouse_shift_capture: None, modify_other_keys_2: false }
}

///|
pub fn TerminalInputFlags::mouse_shift_capture(
  self : TerminalInputFlags,
) -> Bool? {
  self.mouse_shift_capture
}

///|
pub fn TerminalInputFlags::modify_other_keys_2(
  self : TerminalInputFlags,
) -> Bool {
  self.modify_other_keys_2
}

///|
pub fn TerminalInputFlags::set_mouse_shift_capture(
  self : TerminalInputFlags,
  enabled : Bool,
) -> Unit {
  self.mouse_shift_capture = Some(enabled)
}

///|
pub fn TerminalInputFlags::apply_modify_key_format(
  self : TerminalInputFlags,
  format : ModifyKeyFormat,
) -> Unit {
  self.modify_other_keys_2 = false
  match format {
    OtherKeysNumeric => self.modify_other_keys_2 = true
    Legacy
    | CursorKeys
    | FunctionKeys
    | OtherKeysNone
    | OtherKeysNumericExcept => ()
  }
}

///|
pub fn TerminalInputFlags::full_reset(self : TerminalInputFlags) -> Unit {
  self.mouse_shift_capture = None
  self.modify_other_keys_2 = false
}

///|
struct KittyKeyboardState {
  mut flags : Array[KittyKeyboardFlags]
  mut idx : Int
} derive(Eq, Debug)

///|
pub fn KittyKeyboardState::new() -> KittyKeyboardState {
  { flags: empty_kitty_keyboard_stack(), idx: 0 }
}

///|
pub fn KittyKeyboardState::current(
  self : KittyKeyboardState,
) -> KittyKeyboardFlags {
  self.flags[self.idx]
}

///|
pub fn KittyKeyboardState::set(
  self : KittyKeyboardState,
  flags : KittyKeyboardFlags,
) -> Unit {
  self.flags[self.idx] = flags
}

///|
pub fn KittyKeyboardState::set_or(
  self : KittyKeyboardState,
  flags : KittyKeyboardFlags,
) -> Unit {
  self.flags[self.idx] = KittyKeyboardFlags(
    (self.current().0 | flags.0) & KittyKeyboardFlagsMask,
  )
}

///|
pub fn KittyKeyboardState::set_not(
  self : KittyKeyboardState,
  flags : KittyKeyboardFlags,
) -> Unit {
  self.flags[self.idx] = KittyKeyboardFlags(
    clear_kitty_keyboard_flags(self.current().0, flags.0),
  )
}

///|
pub fn KittyKeyboardState::push(
  self : KittyKeyboardState,
  flags : KittyKeyboardFlags,
) -> Unit {
  self.idx = wrapped_kitty_keyboard_index(self.idx + 1)
  self.flags[self.idx] = flags
}

///|
pub fn KittyKeyboardState::pop(
  self : KittyKeyboardState,
  count : UInt16,
) -> Unit {
  if count.to_int() >= KittyKeyboardStackLen {
    self.reset()
    return
  }

  let mut remaining = count.to_int()
  while remaining > 0 {
    self.flags[self.idx] = KittyKeyboardFlags(0)
    self.idx = wrapped_kitty_keyboard_index(self.idx - 1)
    remaining -= 1
  }
}

///|
pub fn KittyKeyboardState::reset(self : KittyKeyboardState) -> Unit {
  self.flags = empty_kitty_keyboard_stack()
  self.idx = 0
}

///|
fn empty_kitty_keyboard_stack() -> Array[KittyKeyboardFlags] {
  let result : Array[KittyKeyboardFlags] = [
    KittyKeyboardFlags(0),
    KittyKeyboardFlags(0),
    KittyKeyboardFlags(0),
    KittyKeyboardFlags(0),
    KittyKeyboardFlags(0),
    KittyKeyboardFlags(0),
    KittyKeyboardFlags(0),
    KittyKeyboardFlags(0),
  ]
  result
}

///|
fn clear_kitty_keyboard_flags(current : Byte, mask : Byte) -> Byte {
  let mut result = current
  let mut bit_index = 0
  while bit_index < 5 {
    let bit = (1 << bit_index).to_byte()
    if (mask & bit) != 0 && (result & bit) != 0 {
      result = result ^ bit
    }
    bit_index += 1
  }
  result
}

///|
fn wrapped_kitty_keyboard_index(index : Int) -> Int {
  if index < 0 {
    KittyKeyboardStackLen - 1
  } else if index >= KittyKeyboardStackLen {
    0
  } else {
    index
  }
}
