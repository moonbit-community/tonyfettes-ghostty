///|
priv struct KittyEntry {
  key : Key
  code : UInt
  final_byte : Byte
  modifier : Bool
}

///|
let kitty_entries : ReadOnlyArray[KittyEntry] = [
  { key: Escape, code: 27U, final_byte: b'u', modifier: false },
  { key: Enter, code: 13U, final_byte: b'u', modifier: false },
  { key: Tab, code: 9U, final_byte: b'u', modifier: false },
  { key: Backspace, code: 127U, final_byte: b'u', modifier: false },
  { key: Insert, code: 2U, final_byte: b'~', modifier: false },
  { key: Delete, code: 3U, final_byte: b'~', modifier: false },
  { key: ArrowLeft, code: 1U, final_byte: b'D', modifier: false },
  { key: ArrowRight, code: 1U, final_byte: b'C', modifier: false },
  { key: ArrowUp, code: 1U, final_byte: b'A', modifier: false },
  { key: ArrowDown, code: 1U, final_byte: b'B', modifier: false },
  { key: PageUp, code: 5U, final_byte: b'~', modifier: false },
  { key: PageDown, code: 6U, final_byte: b'~', modifier: false },
  { key: Home, code: 1U, final_byte: b'H', modifier: false },
  { key: End, code: 1U, final_byte: b'F', modifier: false },
  { key: CapsLock, code: 57358U, final_byte: b'u', modifier: true },
  { key: ScrollLock, code: 57359U, final_byte: b'u', modifier: false },
  { key: NumLock, code: 57360U, final_byte: b'u', modifier: true },
  { key: PrintScreen, code: 57361U, final_byte: b'u', modifier: false },
  { key: Pause, code: 57362U, final_byte: b'u', modifier: false },
  { key: F1, code: 1U, final_byte: b'P', modifier: false },
  { key: F2, code: 1U, final_byte: b'Q', modifier: false },
  { key: F3, code: 13U, final_byte: b'~', modifier: false },
  { key: F4, code: 1U, final_byte: b'S', modifier: false },
  { key: F5, code: 15U, final_byte: b'~', modifier: false },
  { key: F6, code: 17U, final_byte: b'~', modifier: false },
  { key: F7, code: 18U, final_byte: b'~', modifier: false },
  { key: F8, code: 19U, final_byte: b'~', modifier: false },
  { key: F9, code: 20U, final_byte: b'~', modifier: false },
  { key: F10, code: 21U, final_byte: b'~', modifier: false },
  { key: F11, code: 23U, final_byte: b'~', modifier: false },
  { key: F12, code: 24U, final_byte: b'~', modifier: false },
  { key: F13, code: 57376U, final_byte: b'u', modifier: false },
  { key: F14, code: 57377U, final_byte: b'u', modifier: false },
  { key: F15, code: 57378U, final_byte: b'u', modifier: false },
  { key: F16, code: 57379U, final_byte: b'u', modifier: false },
  { key: F17, code: 57380U, final_byte: b'u', modifier: false },
  { key: F18, code: 57381U, final_byte: b'u', modifier: false },
  { key: F19, code: 57382U, final_byte: b'u', modifier: false },
  { key: F20, code: 57383U, final_byte: b'u', modifier: false },
  { key: F21, code: 57384U, final_byte: b'u', modifier: false },
  { key: F22, code: 57385U, final_byte: b'u', modifier: false },
  { key: F23, code: 57386U, final_byte: b'u', modifier: false },
  { key: F24, code: 57387U, final_byte: b'u', modifier: false },
  { key: F25, code: 57388U, final_byte: b'u', modifier: false },
  { key: Numpad0, code: 57399U, final_byte: b'u', modifier: false },
  { key: Numpad1, code: 57400U, final_byte: b'u', modifier: false },
  { key: Numpad2, code: 57401U, final_byte: b'u', modifier: false },
  { key: Numpad3, code: 57402U, final_byte: b'u', modifier: false },
  { key: Numpad4, code: 57403U, final_byte: b'u', modifier: false },
  { key: Numpad5, code: 57404U, final_byte: b'u', modifier: false },
  { key: Numpad6, code: 57405U, final_byte: b'u', modifier: false },
  { key: Numpad7, code: 57406U, final_byte: b'u', modifier: false },
  { key: Numpad8, code: 57407U, final_byte: b'u', modifier: false },
  { key: Numpad9, code: 57408U, final_byte: b'u', modifier: false },
  { key: NumpadDecimal, code: 57409U, final_byte: b'u', modifier: false },
  { key: NumpadDivide, code: 57410U, final_byte: b'u', modifier: false },
  { key: NumpadMultiply, code: 57411U, final_byte: b'u', modifier: false },
  { key: NumpadSubtract, code: 57412U, final_byte: b'u', modifier: false },
  { key: NumpadAdd, code: 57413U, final_byte: b'u', modifier: false },
  { key: NumpadEnter, code: 57414U, final_byte: b'u', modifier: false },
  { key: NumpadEqual, code: 57415U, final_byte: b'u', modifier: false },
  { key: NumpadSeparator, code: 57416U, final_byte: b'u', modifier: false },
  { key: NumpadLeft, code: 57417U, final_byte: b'u', modifier: false },
  { key: NumpadRight, code: 57418U, final_byte: b'u', modifier: false },
  { key: NumpadUp, code: 57419U, final_byte: b'u', modifier: false },
  { key: NumpadDown, code: 57420U, final_byte: b'u', modifier: false },
  { key: NumpadPageUp, code: 57421U, final_byte: b'u', modifier: false },
  { key: NumpadPageDown, code: 57422U, final_byte: b'u', modifier: false },
  { key: NumpadHome, code: 57423U, final_byte: b'u', modifier: false },
  { key: NumpadEnd, code: 57424U, final_byte: b'u', modifier: false },
  { key: NumpadInsert, code: 57425U, final_byte: b'u', modifier: false },
  { key: NumpadDelete, code: 57426U, final_byte: b'u', modifier: false },
  { key: NumpadBegin, code: 57427U, final_byte: b'u', modifier: false },
  { key: ShiftLeft, code: 57441U, final_byte: b'u', modifier: true },
  { key: ShiftRight, code: 57447U, final_byte: b'u', modifier: true },
  { key: ControlLeft, code: 57442U, final_byte: b'u', modifier: true },
  { key: ControlRight, code: 57448U, final_byte: b'u', modifier: true },
  { key: MetaLeft, code: 57444U, final_byte: b'u', modifier: true },
  { key: MetaRight, code: 57450U, final_byte: b'u', modifier: true },
  { key: AltLeft, code: 57443U, final_byte: b'u', modifier: true },
  { key: AltRight, code: 57449U, final_byte: b'u', modifier: true },
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
