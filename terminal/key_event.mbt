///|
const KeyModsShiftMask : UInt16 = 0x0001

///|
const KeyModsCtrlMask : UInt16 = 0x0002

///|
const KeyModsAltMask : UInt16 = 0x0004

///|
const KeyModsSuperMask : UInt16 = 0x0008

///|
const KeyModsCapsLockMask : UInt16 = 0x0010

///|
const KeyModsNumLockMask : UInt16 = 0x0020

///|
const KeyModsShiftSideMask : UInt16 = 0x0040

///|
const KeyModsCtrlSideMask : UInt16 = 0x0080

///|
const KeyModsAltSideMask : UInt16 = 0x0100

///|
const KeyModsSuperSideMask : UInt16 = 0x0200

///|
const KeyModsBindingMask : UInt16 = 0x000F

///|
const KeyModsAllMask : UInt16 = 0xFFFF

///|
pub(all) enum KeyAction {
  Release
  Press
  Repeat
} derive(Eq, Debug)

///|
pub(all) enum KeyModSide {
  Left
  Right
} derive(Eq, Debug)

///|
struct KeyMods(UInt16) derive(Eq, Debug)

///|
pub(all) enum Key {
  Unidentified
  Backquote
  Backslash
  BracketLeft
  BracketRight
  Comma
  Digit0
  Digit1
  Digit2
  Digit3
  Digit4
  Digit5
  Digit6
  Digit7
  Digit8
  Digit9
  Equal
  IntlBackslash
  IntlRo
  IntlYen
  KeyA
  KeyB
  KeyC
  KeyD
  KeyE
  KeyF
  KeyG
  KeyH
  KeyI
  KeyJ
  KeyK
  KeyL
  KeyM
  KeyN
  KeyO
  KeyP
  KeyQ
  KeyR
  KeyS
  KeyT
  KeyU
  KeyV
  KeyW
  KeyX
  KeyY
  KeyZ
  Minus
  Period
  Quote
  Semicolon
  Slash
  AltLeft
  AltRight
  Backspace
  CapsLock
  ContextMenu
  ControlLeft
  ControlRight
  Enter
  MetaLeft
  MetaRight
  ShiftLeft
  ShiftRight
  Space
  Tab
  Convert
  KanaMode
  NonConvert
  Delete
  End
  Help
  Home
  Insert
  PageDown
  PageUp
  ArrowDown
  ArrowLeft
  ArrowRight
  ArrowUp
  NumLock
  Numpad0
  Numpad1
  Numpad2
  Numpad3
  Numpad4
  Numpad5
  Numpad6
  Numpad7
  Numpad8
  Numpad9
  NumpadAdd
  NumpadBackspace
  NumpadClear
  NumpadClearEntry
  NumpadComma
  NumpadDecimal
  NumpadDivide
  NumpadEnter
  NumpadEqual
  NumpadMemoryAdd
  NumpadMemoryClear
  NumpadMemoryRecall
  NumpadMemoryStore
  NumpadMemorySubtract
  NumpadMultiply
  NumpadParenLeft
  NumpadParenRight
  NumpadSubtract
  NumpadSeparator
  NumpadUp
  NumpadDown
  NumpadRight
  NumpadLeft
  NumpadBegin
  NumpadHome
  NumpadEnd
  NumpadInsert
  NumpadDelete
  NumpadPageUp
  NumpadPageDown
  Escape
  F1
  F2
  F3
  F4
  F5
  F6
  F7
  F8
  F9
  F10
  F11
  F12
  F13
  F14
  F15
  F16
  F17
  F18
  F19
  F20
  F21
  F22
  F23
  F24
  F25
  Fn
  FnLock
  PrintScreen
  ScrollLock
  Pause
  BrowserBack
  BrowserFavorites
  BrowserForward
  BrowserHome
  BrowserRefresh
  BrowserSearch
  BrowserStop
  Eject
  LaunchApp1
  LaunchApp2
  LaunchMail
  MediaPlayPause
  MediaSelect
  MediaStop
  MediaTrackNext
  MediaTrackPrevious
  Power
  Sleep
  AudioVolumeDown
  AudioVolumeMute
  AudioVolumeUp
  WakeUp
  Copy
  Cut
  Paste
} derive(Eq, Debug)

///|
struct KeyEvent {
  mut action : KeyAction
  mut key : Key
  mut mods : KeyMods
  mut consumed_mods : KeyMods
  mut composing : Bool
  mut utf8 : Bytes
  mut unshifted_codepoint : UInt
} derive(Eq, Debug)

///|
let key_codepoint_map : ReadOnlyArray[(UInt, Key)] = [
  (b'a'.to_uint(), KeyA),
  (b'b'.to_uint(), KeyB),
  (b'c'.to_uint(), KeyC),
  (b'd'.to_uint(), KeyD),
  (b'e'.to_uint(), KeyE),
  (b'f'.to_uint(), KeyF),
  (b'g'.to_uint(), KeyG),
  (b'h'.to_uint(), KeyH),
  (b'i'.to_uint(), KeyI),
  (b'j'.to_uint(), KeyJ),
  (b'k'.to_uint(), KeyK),
  (b'l'.to_uint(), KeyL),
  (b'm'.to_uint(), KeyM),
  (b'n'.to_uint(), KeyN),
  (b'o'.to_uint(), KeyO),
  (b'p'.to_uint(), KeyP),
  (b'q'.to_uint(), KeyQ),
  (b'r'.to_uint(), KeyR),
  (b's'.to_uint(), KeyS),
  (b't'.to_uint(), KeyT),
  (b'u'.to_uint(), KeyU),
  (b'v'.to_uint(), KeyV),
  (b'w'.to_uint(), KeyW),
  (b'x'.to_uint(), KeyX),
  (b'y'.to_uint(), KeyY),
  (b'z'.to_uint(), KeyZ),
  (b'0'.to_uint(), Digit0),
  (b'1'.to_uint(), Digit1),
  (b'2'.to_uint(), Digit2),
  (b'3'.to_uint(), Digit3),
  (b'4'.to_uint(), Digit4),
  (b'5'.to_uint(), Digit5),
  (b'6'.to_uint(), Digit6),
  (b'7'.to_uint(), Digit7),
  (b'8'.to_uint(), Digit8),
  (b'9'.to_uint(), Digit9),
  (b';'.to_uint(), Semicolon),
  (b' '.to_uint(), Space),
  (b'\''.to_uint(), Quote),
  (b','.to_uint(), Comma),
  (b'`'.to_uint(), Backquote),
  (b'.'.to_uint(), Period),
  (b'/'.to_uint(), Slash),
  (b'-'.to_uint(), Minus),
  (b'='.to_uint(), Equal),
  (b'['.to_uint(), BracketLeft),
  (b']'.to_uint(), BracketRight),
  (b'\\'.to_uint(), Backslash),
  (0x09U, Tab),
  (b'0'.to_uint(), Numpad0),
  (b'1'.to_uint(), Numpad1),
  (b'2'.to_uint(), Numpad2),
  (b'3'.to_uint(), Numpad3),
  (b'4'.to_uint(), Numpad4),
  (b'5'.to_uint(), Numpad5),
  (b'6'.to_uint(), Numpad6),
  (b'7'.to_uint(), Numpad7),
  (b'8'.to_uint(), Numpad8),
  (b'9'.to_uint(), Numpad9),
  (b'.'.to_uint(), NumpadDecimal),
  (b'/'.to_uint(), NumpadDivide),
  (b'*'.to_uint(), NumpadMultiply),
  (b'-'.to_uint(), NumpadSubtract),
  (b'+'.to_uint(), NumpadAdd),
  (b'='.to_uint(), NumpadEqual),
]

///|
pub fn KeyMods::new() -> KeyMods {
  KeyMods(0)
}

///|
pub fn KeyMods::shift(self : KeyMods) -> Bool {
  (self.0 & KeyModsShiftMask) != 0
}

///|
pub fn KeyMods::ctrl(self : KeyMods) -> Bool {
  (self.0 & KeyModsCtrlMask) != 0
}

///|
pub fn KeyMods::alt(self : KeyMods) -> Bool {
  (self.0 & KeyModsAltMask) != 0
}

///|
pub fn KeyMods::super_(self : KeyMods) -> Bool {
  (self.0 & KeyModsSuperMask) != 0
}

///|
pub fn KeyMods::caps_lock(self : KeyMods) -> Bool {
  (self.0 & KeyModsCapsLockMask) != 0
}

///|
pub fn KeyMods::num_lock(self : KeyMods) -> Bool {
  (self.0 & KeyModsNumLockMask) != 0
}

///|
pub fn KeyMods::shift_side(self : KeyMods) -> KeyModSide {
  key_mod_side(self.0, KeyModsShiftSideMask)
}

///|
pub fn KeyMods::ctrl_side(self : KeyMods) -> KeyModSide {
  key_mod_side(self.0, KeyModsCtrlSideMask)
}

///|
pub fn KeyMods::alt_side(self : KeyMods) -> KeyModSide {
  key_mod_side(self.0, KeyModsAltSideMask)
}

///|
pub fn KeyMods::super_side(self : KeyMods) -> KeyModSide {
  key_mod_side(self.0, KeyModsSuperSideMask)
}

///|
pub fn KeyMods::with_shift(self : KeyMods, value : Bool) -> KeyMods {
  KeyMods(key_mods_with_mask(self.0, KeyModsShiftMask, value))
}

///|
pub fn KeyMods::with_ctrl(self : KeyMods, value : Bool) -> KeyMods {
  KeyMods(key_mods_with_mask(self.0, KeyModsCtrlMask, value))
}

///|
pub fn KeyMods::with_alt(self : KeyMods, value : Bool) -> KeyMods {
  KeyMods(key_mods_with_mask(self.0, KeyModsAltMask, value))
}

///|
pub fn KeyMods::with_super_(self : KeyMods, value : Bool) -> KeyMods {
  KeyMods(key_mods_with_mask(self.0, KeyModsSuperMask, value))
}

///|
pub fn KeyMods::with_caps_lock(self : KeyMods, value : Bool) -> KeyMods {
  KeyMods(key_mods_with_mask(self.0, KeyModsCapsLockMask, value))
}

///|
pub fn KeyMods::with_num_lock(self : KeyMods, value : Bool) -> KeyMods {
  KeyMods(key_mods_with_mask(self.0, KeyModsNumLockMask, value))
}

///|
pub fn KeyMods::with_shift_side(self : KeyMods, side : KeyModSide) -> KeyMods {
  KeyMods(key_mods_with_side(self.0, KeyModsShiftSideMask, side))
}

///|
pub fn KeyMods::with_ctrl_side(self : KeyMods, side : KeyModSide) -> KeyMods {
  KeyMods(key_mods_with_side(self.0, KeyModsCtrlSideMask, side))
}

///|
pub fn KeyMods::with_alt_side(self : KeyMods, side : KeyModSide) -> KeyMods {
  KeyMods(key_mods_with_side(self.0, KeyModsAltSideMask, side))
}

///|
pub fn KeyMods::with_super_side(self : KeyMods, side : KeyModSide) -> KeyMods {
  KeyMods(key_mods_with_side(self.0, KeyModsSuperSideMask, side))
}

///|
pub fn KeyMods::empty(self : KeyMods) -> Bool {
  self.0 == 0
}

///|
pub fn KeyMods::binding(self : KeyMods) -> KeyMods {
  KeyMods(self.0 & KeyModsBindingMask)
}

///|
pub fn KeyMods::unset(self : KeyMods, other : KeyMods) -> KeyMods {
  KeyMods(self.0 & (other.0 ^ KeyModsAllMask))
}

///|
pub fn KeyMods::without_locks(self : KeyMods) -> KeyMods {
  KeyMods(self.0 & 0xFFCF)
}

///|
pub fn Key::codepoint(self : Key) -> UInt? {
  for entry in key_codepoint_map {
    if entry.1 == self {
      return Some(entry.0)
    }
  }
  None
}

///|
pub fn KeyEvent::new() -> KeyEvent {
  {
    action: Press,
    key: Unidentified,
    mods: KeyMods::new(),
    consumed_mods: KeyMods::new(),
    composing: false,
    utf8: b"",
    unshifted_codepoint: 0U,
  }
}

///|
pub fn KeyEvent::action(self : KeyEvent) -> KeyAction {
  self.action
}

///|
pub fn KeyEvent::set_action(self : KeyEvent, value : KeyAction) -> Unit {
  self.action = value
}

///|
pub fn KeyEvent::key(self : KeyEvent) -> Key {
  self.key
}

///|
pub fn KeyEvent::set_key(self : KeyEvent, value : Key) -> Unit {
  self.key = value
}

///|
pub fn KeyEvent::mods(self : KeyEvent) -> KeyMods {
  self.mods
}

///|
pub fn KeyEvent::set_mods(self : KeyEvent, value : KeyMods) -> Unit {
  self.mods = value
}

///|
pub fn KeyEvent::consumed_mods(self : KeyEvent) -> KeyMods {
  self.consumed_mods
}

///|
pub fn KeyEvent::set_consumed_mods(self : KeyEvent, value : KeyMods) -> Unit {
  self.consumed_mods = value
}

///|
pub fn KeyEvent::composing(self : KeyEvent) -> Bool {
  self.composing
}

///|
pub fn KeyEvent::set_composing(self : KeyEvent, value : Bool) -> Unit {
  self.composing = value
}

///|
pub fn KeyEvent::utf8(self : KeyEvent) -> Bytes {
  self.utf8
}

///|
pub fn KeyEvent::set_utf8(self : KeyEvent, value : Bytes) -> Unit {
  self.utf8 = value
}

///|
pub fn KeyEvent::unshifted_codepoint(self : KeyEvent) -> UInt {
  self.unshifted_codepoint
}

///|
pub fn KeyEvent::set_unshifted_codepoint(self : KeyEvent, value : UInt) -> Unit {
  self.unshifted_codepoint = value
}

///|
pub fn KeyEvent::effective_mods(self : KeyEvent) -> KeyMods {
  if self.utf8.length() == 0 {
    self.mods
  } else {
    self.mods.unset(self.consumed_mods)
  }
}

///|
fn key_mod_side(raw : UInt16, mask : UInt16) -> KeyModSide {
  if (raw & mask) == 0 {
    Left
  } else {
    Right
  }
}

///|
fn key_mods_with_mask(raw : UInt16, mask : UInt16, value : Bool) -> UInt16 {
  if value {
    raw | mask
  } else {
    raw & (KeyModsAllMask ^ mask)
  }
}

///|
fn key_mods_with_side(raw : UInt16, mask : UInt16, side : KeyModSide) -> UInt16 {
  key_mods_with_mask(raw, mask, side == Right)
}
