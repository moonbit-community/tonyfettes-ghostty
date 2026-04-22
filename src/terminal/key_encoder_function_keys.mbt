///|
const BackspaceCodepoint : UInt = 127U

///|
const EnterCodepoint : UInt = 13U

///|
const EscapeCodepoint : UInt = 27U

///|
const TabCodepoint : UInt = 9U

///|
let function_key_modifiers : ReadOnlyArray[(KeyMods, Int)] = [
  (KeyMods::new().with_shift(true), 2),
  (KeyMods::new().with_alt(true), 3),
  (KeyMods::new().with_shift(true).with_alt(true), 4),
  (KeyMods::new().with_ctrl(true), 5),
  (KeyMods::new().with_shift(true).with_ctrl(true), 6),
  (KeyMods::new().with_alt(true).with_ctrl(true), 7),
  (KeyMods::new().with_shift(true).with_alt(true).with_ctrl(true), 8),
  (KeyMods::new().with_super_(true), 9),
  (KeyMods::new().with_shift(true).with_super_(true), 10),
  (KeyMods::new().with_alt(true).with_super_(true), 11),
  (KeyMods::new().with_shift(true).with_alt(true).with_super_(true), 12),
  (KeyMods::new().with_ctrl(true).with_super_(true), 13),
  (KeyMods::new().with_shift(true).with_ctrl(true).with_super_(true), 14),
  (KeyMods::new().with_alt(true).with_ctrl(true).with_super_(true), 15),
  (
    KeyMods::new()
    .with_shift(true)
    .with_alt(true)
    .with_ctrl(true)
    .with_super_(true),
    16,
  ),
]

///|
fn function_key_modifier_code(mods : KeyMods) -> Int? {
  let binding = mods.binding()
  for entry in function_key_modifiers {
    if entry.0 == binding {
      return Some(entry.1)
    }
  }
  None
}

///|
fn pc_style_function_key(
  key : Key,
  mods : KeyMods,
  cursor_key_application : Bool,
  keypad_key_application_req : Bool,
  ignore_keypad_with_numlock : Bool,
  modify_other_keys_state_2 : Bool,
  backarrow_key_mode : Bool,
) -> Bytes? {
  let binding = mods.binding()
  let keypad_key_application = if ignore_keypad_with_numlock {
    false
  } else {
    keypad_key_application_req
  }

  match key {
    ArrowUp => cursor_key(binding, cursor_key_application, b'A', b'A')
    ArrowDown => cursor_key(binding, cursor_key_application, b'B', b'B')
    ArrowRight => cursor_key(binding, cursor_key_application, b'C', b'C')
    ArrowLeft => cursor_key(binding, cursor_key_application, b'D', b'D')
    Home => cursor_key(binding, cursor_key_application, b'H', b'H')
    End => cursor_key(binding, cursor_key_application, b'F', b'F')
    Insert => csi_tilde_key(binding, 2)
    Delete => csi_tilde_key(binding, 3)
    PageUp => csi_tilde_key(binding, 5)
    PageDown => csi_tilde_key(binding, 6)
    F1 => ss3_function_key(binding, b'P')
    F2 => ss3_function_key(binding, b'Q')
    F3 =>
      match function_key_modifier_code(binding) {
        Some(code) => Some(csi_tilde_with_code(13, code))
        None => if binding.empty() { Some(b"\x1BOR") } else { None }
      }
    F4 => ss3_function_key(binding, b'S')
    F5 => csi_tilde_key(binding, 15)
    F6 => csi_tilde_key(binding, 17)
    F7 => csi_tilde_key(binding, 18)
    F8 => csi_tilde_key(binding, 19)
    F9 => csi_tilde_key(binding, 20)
    F10 => csi_tilde_key(binding, 21)
    F11 => csi_tilde_key(binding, 23)
    F12 => csi_tilde_key(binding, 24)
    Numpad0 => keypad_key(binding, keypad_key_application, b'p')
    Numpad1 => keypad_key(binding, keypad_key_application, b'q')
    Numpad2 => keypad_key(binding, keypad_key_application, b'r')
    Numpad3 => keypad_key(binding, keypad_key_application, b's')
    Numpad4 => keypad_key(binding, keypad_key_application, b't')
    Numpad5 => keypad_key(binding, keypad_key_application, b'u')
    Numpad6 => keypad_key(binding, keypad_key_application, b'v')
    Numpad7 => keypad_key(binding, keypad_key_application, b'w')
    Numpad8 => keypad_key(binding, keypad_key_application, b'x')
    Numpad9 => keypad_key(binding, keypad_key_application, b'y')
    NumpadDecimal => keypad_key(binding, keypad_key_application, b'n')
    NumpadDivide => keypad_key(binding, keypad_key_application, b'o')
    NumpadMultiply => keypad_key(binding, keypad_key_application, b'j')
    NumpadSubtract => keypad_key(binding, keypad_key_application, b'm')
    NumpadAdd => keypad_key(binding, keypad_key_application, b'k')
    NumpadEnter =>
      match function_key_modifier_code(binding) {
        Some(code) =>
          if keypad_key_application {
            Some(keypad_with_code(code, b'M'))
          } else {
            None
          }
        None =>
          if keypad_key_application {
            Some(b"\x1BOM")
          } else if binding.empty() {
            Some(b"\r")
          } else {
            None
          }
      }
    NumpadUp => cursor_key(binding, cursor_key_application, b'A', b'A')
    NumpadDown => cursor_key(binding, cursor_key_application, b'B', b'B')
    NumpadRight => cursor_key(binding, cursor_key_application, b'C', b'C')
    NumpadLeft => cursor_key(binding, cursor_key_application, b'D', b'D')
    NumpadBegin => cursor_key(binding, cursor_key_application, b'E', b'E')
    NumpadHome => cursor_key(binding, cursor_key_application, b'H', b'H')
    NumpadEnd => cursor_key(binding, cursor_key_application, b'F', b'F')
    NumpadInsert => csi_tilde_key(binding, 2)
    NumpadDelete => csi_tilde_key(binding, 3)
    NumpadPageUp => csi_tilde_key(binding, 5)
    NumpadPageDown => csi_tilde_key(binding, 6)
    Backspace =>
      backspace_key(binding, modify_other_keys_state_2, backarrow_key_mode)
    Tab => tab_key(binding, modify_other_keys_state_2)
    Enter => enter_key(binding, modify_other_keys_state_2)
    Escape => escape_key(binding)
    _ => None
  }
}

///|
fn cursor_key(
  binding : KeyMods,
  cursor_key_application : Bool,
  csi_final : Byte,
  app_final : Byte,
) -> Bytes? {
  match function_key_modifier_code(binding) {
    Some(code) => Some(csi_1_with_code(code, csi_final))
    None =>
      if binding.empty() {
        Some(
          if cursor_key_application {
            ss3_plain(app_final)
          } else {
            csi_plain(csi_final)
          },
        )
      } else {
        None
      }
  }
}

///|
fn csi_tilde_key(binding : KeyMods, number : Int) -> Bytes? {
  match function_key_modifier_code(binding) {
    Some(code) => Some(csi_tilde_with_code(number, code))
    None => if binding.empty() { Some(csi_tilde_plain(number)) } else { None }
  }
}

///|
fn ss3_function_key(binding : KeyMods, final_byte : Byte) -> Bytes? {
  match function_key_modifier_code(binding) {
    Some(code) => Some(csi_1_with_code(code, final_byte))
    None => if binding.empty() { Some(ss3_plain(final_byte)) } else { None }
  }
}

///|
fn keypad_key(
  binding : KeyMods,
  keypad_key_application : Bool,
  suffix : Byte,
) -> Bytes? {
  match function_key_modifier_code(binding) {
    Some(code) =>
      if keypad_key_application {
        Some(keypad_with_code(code, suffix))
      } else {
        None
      }
    None => if keypad_key_application { Some(ss3_plain(suffix)) } else { None }
  }
}

///|
fn backspace_key(
  binding : KeyMods,
  modify_other_keys_state_2 : Bool,
  backarrow_key_mode : Bool,
) -> Bytes? {
  if binding.empty() {
    return Some(if backarrow_key_mode { b"\x08" } else { b"\x7F" })
  }

  if binding == KeyMods::new().with_ctrl(true) {
    return Some(if backarrow_key_mode { b"\x7F" } else { b"\x08" })
  }

  if modify_other_keys_state_2 {
    match function_key_modifier_code(binding) {
      Some(5) | None => ()
      Some(code) =>
        return Some(modify_other_keys_sequence(code, BackspaceCodepoint))
    }
  }

  let buffer = @buffer.new(size_hint=2)
  if binding.alt() {
    buffer.write_byte(0x1B)
  }
  buffer.write_byte(if binding.ctrl() { 0x08 } else { 0x7F })
  Some(buffer.contents())
}

///|
fn tab_key(binding : KeyMods, modify_other_keys_state_2 : Bool) -> Bytes? {
  if binding.empty() {
    return Some(b"\t")
  }

  if binding == KeyMods::new().with_shift(true) {
    return Some(
      if modify_other_keys_state_2 {
        modify_other_keys_sequence(2, TabCodepoint)
      } else {
        b"\x1B[Z"
      },
    )
  }

  if binding == KeyMods::new().with_alt(true) {
    return Some(
      if modify_other_keys_state_2 {
        modify_other_keys_sequence(3, TabCodepoint)
      } else {
        b"\x1B\t"
      },
    )
  }

  match function_key_modifier_code(binding) {
    Some(code) => Some(modify_other_keys_sequence(code, TabCodepoint))
    None => None
  }
}

///|
fn enter_key(binding : KeyMods, modify_other_keys_state_2 : Bool) -> Bytes? {
  if binding.empty() {
    return Some(b"\r")
  }

  if binding == KeyMods::new().with_alt(true) && !modify_other_keys_state_2 {
    return Some(b"\x1B\r")
  }

  match function_key_modifier_code(binding) {
    Some(code) => Some(modify_other_keys_sequence(code, EnterCodepoint))
    None => None
  }
}

///|
fn escape_key(binding : KeyMods) -> Bytes? {
  if binding.empty() {
    return Some(b"\x1B")
  }

  if binding == KeyMods::new().with_alt(true) {
    return Some(b"\x1B\x1B")
  }

  match function_key_modifier_code(binding) {
    Some(code) => Some(modify_other_keys_sequence(code, EscapeCodepoint))
    None => None
  }
}

///|
fn csi_plain(final_byte : Byte) -> Bytes {
  let buffer = @buffer.new(size_hint=3)
  buffer.write_bytes(b"\x1B[")
  buffer.write_byte(final_byte)
  buffer.contents()
}

///|
fn ss3_plain(final_byte : Byte) -> Bytes {
  let buffer = @buffer.new(size_hint=3)
  buffer.write_bytes(b"\x1BO")
  buffer.write_byte(final_byte)
  buffer.contents()
}

///|
fn csi_1_with_code(code : Int, final_byte : Byte) -> Bytes {
  let buffer = @buffer.new(size_hint=8)
  buffer.write_bytes(b"\x1B[1;")
  write_uint_ascii(buffer, code.to_uint64())
  buffer.write_byte(final_byte)
  buffer.contents()
}

///|
fn csi_tilde_plain(number : Int) -> Bytes {
  let buffer = @buffer.new(size_hint=6)
  buffer.write_bytes(b"\x1B[")
  write_uint_ascii(buffer, number.to_uint64())
  buffer.write_byte(b'~')
  buffer.contents()
}

///|
fn csi_tilde_with_code(number : Int, code : Int) -> Bytes {
  let buffer = @buffer.new(size_hint=10)
  buffer.write_bytes(b"\x1B[")
  write_uint_ascii(buffer, number.to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, code.to_uint64())
  buffer.write_byte(b'~')
  buffer.contents()
}

///|
fn keypad_with_code(code : Int, suffix : Byte) -> Bytes {
  let buffer = @buffer.new(size_hint=7)
  buffer.write_bytes(b"\x1BO")
  write_uint_ascii(buffer, code.to_uint64())
  buffer.write_byte(suffix)
  buffer.contents()
}

///|
fn modify_other_keys_sequence(code : Int, codepoint : UInt) -> Bytes {
  let buffer = @buffer.new(size_hint=16)
  buffer.write_bytes(b"\x1B[27;")
  write_uint_ascii(buffer, code.to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, codepoint.to_uint64())
  buffer.write_byte(b'~')
  buffer.contents()
}
