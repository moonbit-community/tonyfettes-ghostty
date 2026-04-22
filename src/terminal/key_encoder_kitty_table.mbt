///|
priv struct KittyEntry {
  key : Key
  code : UInt
  final_byte : Byte
  modifier : Bool
}

///|
let kitty_entries : ReadOnlyArray[KittyEntry] = [
  { key: Key::Escape, code: 27U, final_byte: b'u', modifier: false },
  { key: Key::Enter, code: 13U, final_byte: b'u', modifier: false },
  { key: Key::Tab, code: 9U, final_byte: b'u', modifier: false },
  { key: Key::Backspace, code: 127U, final_byte: b'u', modifier: false },
  { key: Key::Insert, code: 2U, final_byte: b'~', modifier: false },
  { key: Key::Delete, code: 3U, final_byte: b'~', modifier: false },
  { key: Key::ArrowLeft, code: 1U, final_byte: b'D', modifier: false },
  { key: Key::ArrowRight, code: 1U, final_byte: b'C', modifier: false },
  { key: Key::ArrowUp, code: 1U, final_byte: b'A', modifier: false },
  { key: Key::ArrowDown, code: 1U, final_byte: b'B', modifier: false },
  { key: Key::PageUp, code: 5U, final_byte: b'~', modifier: false },
  { key: Key::PageDown, code: 6U, final_byte: b'~', modifier: false },
  { key: Key::Home, code: 1U, final_byte: b'H', modifier: false },
  { key: Key::End, code: 1U, final_byte: b'F', modifier: false },
  { key: Key::CapsLock, code: 57358U, final_byte: b'u', modifier: true },
  { key: Key::ScrollLock, code: 57359U, final_byte: b'u', modifier: false },
  { key: Key::NumLock, code: 57360U, final_byte: b'u', modifier: true },
  { key: Key::PrintScreen, code: 57361U, final_byte: b'u', modifier: false },
  { key: Key::Pause, code: 57362U, final_byte: b'u', modifier: false },
  { key: Key::F1, code: 1U, final_byte: b'P', modifier: false },
  { key: Key::F2, code: 1U, final_byte: b'Q', modifier: false },
  { key: Key::F3, code: 13U, final_byte: b'~', modifier: false },
  { key: Key::F4, code: 1U, final_byte: b'S', modifier: false },
  { key: Key::F5, code: 15U, final_byte: b'~', modifier: false },
  { key: Key::F6, code: 17U, final_byte: b'~', modifier: false },
  { key: Key::F7, code: 18U, final_byte: b'~', modifier: false },
  { key: Key::F8, code: 19U, final_byte: b'~', modifier: false },
  { key: Key::F9, code: 20U, final_byte: b'~', modifier: false },
  { key: Key::F10, code: 21U, final_byte: b'~', modifier: false },
  { key: Key::F11, code: 23U, final_byte: b'~', modifier: false },
  { key: Key::F12, code: 24U, final_byte: b'~', modifier: false },
  { key: Key::F13, code: 57376U, final_byte: b'u', modifier: false },
  { key: Key::F14, code: 57377U, final_byte: b'u', modifier: false },
  { key: Key::F15, code: 57378U, final_byte: b'u', modifier: false },
  { key: Key::F16, code: 57379U, final_byte: b'u', modifier: false },
  { key: Key::F17, code: 57380U, final_byte: b'u', modifier: false },
  { key: Key::F18, code: 57381U, final_byte: b'u', modifier: false },
  { key: Key::F19, code: 57382U, final_byte: b'u', modifier: false },
  { key: Key::F20, code: 57383U, final_byte: b'u', modifier: false },
  { key: Key::F21, code: 57384U, final_byte: b'u', modifier: false },
  { key: Key::F22, code: 57385U, final_byte: b'u', modifier: false },
  { key: Key::F23, code: 57386U, final_byte: b'u', modifier: false },
  { key: Key::F24, code: 57387U, final_byte: b'u', modifier: false },
  { key: Key::F25, code: 57388U, final_byte: b'u', modifier: false },
  { key: Key::Numpad0, code: 57399U, final_byte: b'u', modifier: false },
  { key: Key::Numpad1, code: 57400U, final_byte: b'u', modifier: false },
  { key: Key::Numpad2, code: 57401U, final_byte: b'u', modifier: false },
  { key: Key::Numpad3, code: 57402U, final_byte: b'u', modifier: false },
  { key: Key::Numpad4, code: 57403U, final_byte: b'u', modifier: false },
  { key: Key::Numpad5, code: 57404U, final_byte: b'u', modifier: false },
  { key: Key::Numpad6, code: 57405U, final_byte: b'u', modifier: false },
  { key: Key::Numpad7, code: 57406U, final_byte: b'u', modifier: false },
  { key: Key::Numpad8, code: 57407U, final_byte: b'u', modifier: false },
  { key: Key::Numpad9, code: 57408U, final_byte: b'u', modifier: false },
  { key: Key::NumpadDecimal, code: 57409U, final_byte: b'u', modifier: false },
  { key: Key::NumpadDivide, code: 57410U, final_byte: b'u', modifier: false },
  { key: Key::NumpadMultiply, code: 57411U, final_byte: b'u', modifier: false },
  { key: Key::NumpadSubtract, code: 57412U, final_byte: b'u', modifier: false },
  { key: Key::NumpadAdd, code: 57413U, final_byte: b'u', modifier: false },
  { key: Key::NumpadEnter, code: 57414U, final_byte: b'u', modifier: false },
  { key: Key::NumpadEqual, code: 57415U, final_byte: b'u', modifier: false },
  { key: Key::NumpadSeparator, code: 57416U, final_byte: b'u', modifier: false },
  { key: Key::NumpadLeft, code: 57417U, final_byte: b'u', modifier: false },
  { key: Key::NumpadRight, code: 57418U, final_byte: b'u', modifier: false },
  { key: Key::NumpadUp, code: 57419U, final_byte: b'u', modifier: false },
  { key: Key::NumpadDown, code: 57420U, final_byte: b'u', modifier: false },
  { key: Key::NumpadPageUp, code: 57421U, final_byte: b'u', modifier: false },
  { key: Key::NumpadPageDown, code: 57422U, final_byte: b'u', modifier: false },
  { key: Key::NumpadHome, code: 57423U, final_byte: b'u', modifier: false },
  { key: Key::NumpadEnd, code: 57424U, final_byte: b'u', modifier: false },
  { key: Key::NumpadInsert, code: 57425U, final_byte: b'u', modifier: false },
  { key: Key::NumpadDelete, code: 57426U, final_byte: b'u', modifier: false },
  { key: Key::NumpadBegin, code: 57427U, final_byte: b'u', modifier: false },
  { key: Key::ShiftLeft, code: 57441U, final_byte: b'u', modifier: true },
  { key: Key::ShiftRight, code: 57447U, final_byte: b'u', modifier: true },
  { key: Key::ControlLeft, code: 57442U, final_byte: b'u', modifier: true },
  { key: Key::ControlRight, code: 57448U, final_byte: b'u', modifier: true },
  { key: Key::MetaLeft, code: 57444U, final_byte: b'u', modifier: true },
  { key: Key::MetaRight, code: 57450U, final_byte: b'u', modifier: true },
  { key: Key::AltLeft, code: 57443U, final_byte: b'u', modifier: true },
  { key: Key::AltRight, code: 57449U, final_byte: b'u', modifier: true },
]

///|
fn kitty_entry(key : Key) -> KittyEntry? {
  for entry in kitty_entries {
    if entry.key == key {
      return Some(entry)
    }
  }
  None
}
