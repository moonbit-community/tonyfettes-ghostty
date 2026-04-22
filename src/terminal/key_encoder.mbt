///|
pub(all) enum OptionAsAlt {
  False
  Left
  Right
  True
} derive(Eq, Debug)

///|
const KittyFlagReportEvents : Byte = 0x02

///|
const KittyFlagReportAlternates : Byte = 0x04

///|
const KittyFlagReportAll : Byte = 0x08

///|
const KittyFlagReportAssociated : Byte = 0x10

///|
struct KeyEncoder {
  mut cursor_key_application : Bool
  mut keypad_key_application : Bool
  mut ignore_keypad_with_numlock : Bool
  mut alt_esc_prefix : Bool
  mut modify_other_keys_state_2 : Bool
  mut kitty_flags : KittyKeyboardFlags
  mut host_is_macos : Bool
  mut macos_option_as_alt : OptionAsAlt
  mut backarrow_key_mode : Bool
} derive(Eq, Debug)

///|
pub fn KeyEncoder::new() -> KeyEncoder {
  {
    cursor_key_application: false,
    keypad_key_application: false,
    ignore_keypad_with_numlock: false,
    alt_esc_prefix: false,
    modify_other_keys_state_2: false,
    kitty_flags: KittyKeyboardFlags(0),
    host_is_macos: false,
    macos_option_as_alt: OptionAsAlt::False,
    backarrow_key_mode: false,
  }
}

///|
pub fn KeyEncoder::cursor_key_application(self : KeyEncoder) -> Bool {
  self.cursor_key_application
}

///|
pub fn KeyEncoder::set_cursor_key_application(
  self : KeyEncoder,
  value : Bool,
) -> Unit {
  self.cursor_key_application = value
}

///|
pub fn KeyEncoder::keypad_key_application(self : KeyEncoder) -> Bool {
  self.keypad_key_application
}

///|
pub fn KeyEncoder::set_keypad_key_application(
  self : KeyEncoder,
  value : Bool,
) -> Unit {
  self.keypad_key_application = value
}

///|
pub fn KeyEncoder::ignore_keypad_with_numlock(self : KeyEncoder) -> Bool {
  self.ignore_keypad_with_numlock
}

///|
pub fn KeyEncoder::set_ignore_keypad_with_numlock(
  self : KeyEncoder,
  value : Bool,
) -> Unit {
  self.ignore_keypad_with_numlock = value
}

///|
pub fn KeyEncoder::alt_esc_prefix(self : KeyEncoder) -> Bool {
  self.alt_esc_prefix
}

///|
pub fn KeyEncoder::set_alt_esc_prefix(self : KeyEncoder, value : Bool) -> Unit {
  self.alt_esc_prefix = value
}

///|
pub fn KeyEncoder::modify_other_keys_state_2(self : KeyEncoder) -> Bool {
  self.modify_other_keys_state_2
}

///|
pub fn KeyEncoder::set_modify_other_keys_state_2(
  self : KeyEncoder,
  value : Bool,
) -> Unit {
  self.modify_other_keys_state_2 = value
}

///|
pub fn KeyEncoder::kitty_flags(self : KeyEncoder) -> KittyKeyboardFlags {
  self.kitty_flags
}

///|
pub fn KeyEncoder::set_kitty_flags(
  self : KeyEncoder,
  value : KittyKeyboardFlags,
) -> Unit {
  self.kitty_flags = KittyKeyboardFlags(value.0 & 0x1F)
}

///|
pub fn KeyEncoder::host_is_macos(self : KeyEncoder) -> Bool {
  self.host_is_macos
}

///|
pub fn KeyEncoder::set_host_is_macos(self : KeyEncoder, value : Bool) -> Unit {
  self.host_is_macos = value
}

///|
pub fn KeyEncoder::macos_option_as_alt(self : KeyEncoder) -> OptionAsAlt {
  self.macos_option_as_alt
}

///|
pub fn KeyEncoder::set_macos_option_as_alt(
  self : KeyEncoder,
  value : OptionAsAlt,
) -> Unit {
  self.macos_option_as_alt = value
}

///|
pub fn KeyEncoder::backarrow_key_mode(self : KeyEncoder) -> Bool {
  self.backarrow_key_mode
}

///|
pub fn KeyEncoder::set_backarrow_key_mode(
  self : KeyEncoder,
  value : Bool,
) -> Unit {
  self.backarrow_key_mode = value
}

///|
pub fn KeyEncoder::sync_from_terminal(
  self : KeyEncoder,
  terminal : StreamTerminal,
) -> Unit {
  let bridge = terminal.bridge()
  self.cursor_key_application = bridge.mode_get(Mode::CursorKeys)
  self.keypad_key_application = bridge.mode_get(Mode::KeypadKeys)
  self.ignore_keypad_with_numlock = bridge.mode_get(
    Mode::IgnoreKeypadWithNumlock,
  )
  self.alt_esc_prefix = bridge.mode_get(Mode::AltEscPrefix)
  self.modify_other_keys_state_2 = bridge.modify_other_keys_2()
  self.kitty_flags = bridge.kitty_keyboard_flags()
  self.macos_option_as_alt = OptionAsAlt::False
  self.backarrow_key_mode = bridge.mode_get(Mode::BackarrowKeyMode)
}

///|
priv struct KittySequence {
  key : UInt
  final_byte : Byte
  mods : KittyMods
  mut event : KittySequenceEvent
  mut alternate_shifted : UInt?
  mut alternate_base : UInt?
  mut text : Bytes
}

///|
priv enum KittySequenceEvent {
  None
  Press
  Repeat
  Release
} derive(Eq)

///|
priv struct CsiUMods {
  mut shift : Bool
  alt : Bool
  ctrl : Bool
}

///|
priv struct KittyMods {
  shift : Bool
  alt : Bool
  ctrl : Bool
  super_ : Bool
  hyper : Bool
  meta : Bool
  caps_lock : Bool
  num_lock : Bool
}

///|
fn KeyEncoder::encode_kitty(self : KeyEncoder, event : KeyEvent) -> Bytes {
  if self.kitty_flags.0 == 0 {
    return self.encode_legacy(event)
  }

  if event.action() == KeyAction::Release {
    if !kitty_flag_enabled(self.kitty_flags, KittyFlagReportEvents) {
      return b""
    }
    if !kitty_flag_enabled(self.kitty_flags, KittyFlagReportAll) {
      match event.key() {
        Key::Enter | Key::Backspace | Key::Tab => return b""
        _ => ()
      }
    }
  }

  let all_mods = event.mods()
  let effective_mods = event.effective_mods()
  let binding_mods = effective_mods.binding()

  let entry = match kitty_entry(event.key()) {
    Some(found) => Some(found)
    None =>
      if event.unshifted_codepoint() > 0U {
        Some({
          key: event.key(),
          code: event.unshifted_codepoint(),
          final_byte: b'u',
          modifier: false,
        })
      } else {
        None
      }
  }

  if event.composing() {
    match entry {
      Some(found) if found.modifier => ()
      _ => return b""
    }
  }

  if event.utf8().length() > 0 {
    match event.key() {
      Key::Enter | Key::Backspace =>
        if is_control_utf8(event.utf8()) {
          ()
        } else if event.key() == Key::Backspace {
          return b""
        } else {
          return event.utf8()
        }
      _ => ()
    }
  }

  if !kitty_flag_enabled(self.kitty_flags, KittyFlagReportAll) {
    if binding_mods.empty() {
      match event.key() {
        Key::Enter => return b"\r"
        Key::Tab => return b"\t"
        Key::Backspace => return b"\x7F"
        _ => ()
      }
    }

    if event.utf8().length() > 0 &&
      binding_mods.empty() &&
      event.action() != KeyAction::Release {
      match utf8_codepoints(event.utf8()) {
        Some(codepoints) => {
          let mut printable = true
          for codepoint in codepoints {
            if is_control(codepoint) {
              printable = false
              break
            }
          }
          if printable {
            return event.utf8()
          }
        }
        None => ()
      }
    }
  }

  guard entry is Some(found) else {
    if event.utf8().length() > 0 {
      return event.utf8()
    }
    return b""
  }

  if found.modifier && !kitty_flag_enabled(self.kitty_flags, KittyFlagReportAll) {
    return b""
  }

  let sequence = {
    key: found.code,
    final_byte: found.final_byte,
    mods: KittyMods::from_input(event.action(), event.key(), all_mods),
    event: KittySequenceEvent::None,
    alternate_shifted: None,
    alternate_base: None,
    text: b"",
  }

  if kitty_flag_enabled(self.kitty_flags, KittyFlagReportEvents) {
    sequence.event = match event.action() {
      KeyAction::Press => KittySequenceEvent::Press
      KeyAction::Release => KittySequenceEvent::Release
      KeyAction::Repeat => KittySequenceEvent::Repeat
    }
  }

  if kitty_flag_enabled(self.kitty_flags, KittyFlagReportAlternates) &&
    !is_control(found.code.reinterpret_as_int()) {
    populate_kitty_alternates(sequence, event)
  }

  if kitty_flag_enabled(self.kitty_flags, KittyFlagReportAssociated) &&
    sequence.event != KittySequenceEvent::Release &&
    !sequence.mods.prevents_text(self.alt_prevents_text(all_mods)) {
    sequence.text = event.utf8()
  }

  sequence.encode()
}

///|
fn KeyEncoder::encode_legacy(self : KeyEncoder, event : KeyEvent) -> Bytes {
  let all_mods = event.mods()
  let effective_mods = event.effective_mods()
  let binding_mods = effective_mods.binding()

  if event.action() != KeyAction::Press && event.action() != KeyAction::Repeat {
    return b""
  }

  if event.composing() {
    return b""
  }

  match
    pc_style_function_key(
      event.key(),
      all_mods,
      self.cursor_key_application,
      self.keypad_key_application,
      self.ignore_keypad_with_numlock,
      self.modify_other_keys_state_2,
      self.backarrow_key_mode,
    ) {
    Some(sequence) =>
      if event.utf8().length() > 0 {
        match event.key() {
          Key::Backspace | Key::Enter | Key::Escape =>
            if !is_control_utf8(event.utf8()) {
              if event.key() == Key::Backspace {
                return b""
              }
            } else {
              return sequence
            }
          _ => return sequence
        }
      } else {
        return sequence
      }
    None => ()
  }

  match
    ctrl_sequence(
      event.key(),
      event.utf8(),
      event.unshifted_codepoint(),
      all_mods,
    ) {
    Some(char) => {
      let buffer = @buffer.new(size_hint=2)
      if binding_mods.alt() {
        buffer.write_byte(0x1B)
      }
      buffer.write_byte(char)
      return buffer.contents()
    }
    None => ()
  }

  if event.utf8().length() == 0 {
    match self.legacy_alt_prefix(event, binding_mods, all_mods) {
      Some(byte) => {
        let buffer = @buffer.new(size_hint=2)
        buffer.write_byte(0x1B)
        buffer.write_byte(byte)
        return buffer.contents()
      }
      None => return b""
    }
  }

  if self.modify_other_keys_state_2 {
    match self.modify_other_keys_sequence_for_event(event) {
      Some(sequence) => return sequence
      None => ()
    }
  }

  if event.mods().ctrl() {
    match csi_u_sequence(event) {
      Some(sequence) => return sequence
      None => ()
    }
  }

  match self.legacy_alt_prefix(event, binding_mods, all_mods) {
    Some(byte) => {
      let buffer = @buffer.new(size_hint=2)
      buffer.write_byte(0x1B)
      buffer.write_byte(byte)
      return buffer.contents()
    }
    None => ()
  }

  if self.host_is_macos && all_mods.super_() {
    return b""
  }

  event.utf8()
}

///|
fn populate_kitty_alternates(
  sequence : KittySequence,
  event : KeyEvent,
) -> Unit {
  match utf8_codepoints(event.utf8()) {
    Some([first, .. rest]) => {
      if first.reinterpret_as_uint() != sequence.key && sequence.mods.shift {
        sequence.alternate_shifted = Some(first.reinterpret_as_uint())
      }

      match event.key().codepoint() {
        Some(base) =>
          if base != sequence.key &&
            rest.length() == 0 &&
            first.reinterpret_as_uint() != base {
            sequence.alternate_base = Some(base)
          }
        None => ()
      }
    }
    Some([]) | None =>
      match event.key().codepoint() {
        Some(base) =>
          if base != sequence.key {
            sequence.alternate_base = Some(base)
          }
        None => ()
      }
  }
}

///|
fn KeyEncoder::modify_other_keys_sequence_for_event(
  self : KeyEncoder,
  event : KeyEvent,
) -> Bytes? {
  let decoded = utf8_codepoints(event.utf8())
  guard decoded is Some([codepoint]) else { return None }

  let mods = {
    let mut binding = event.mods().binding()
    if self.host_is_macos {
      match self.macos_option_as_alt {
        OptionAsAlt::False => binding = binding.with_alt(false)
        OptionAsAlt::True => ()
        OptionAsAlt::Left =>
          if event.mods().alt_side() != KeyModSide::Left {
            binding = binding.with_alt(false)
          }
        OptionAsAlt::Right =>
          if event.mods().alt_side() != KeyModSide::Right {
            binding = binding.with_alt(false)
          }
      }
    }
    binding
  }

  let should_modify = if codepoint >= 0x40 && codepoint <= 0x7F {
    true
  } else {
    let mods_no_shift = mods.with_shift(false)
    if !mods_no_shift.empty() {
      true
    } else {
      codepoint == b' '.to_int()
    }
  }

  if !should_modify {
    return None
  }

  match function_key_modifier_code(mods) {
    Some(code) =>
      Some(modify_other_keys_sequence(code, codepoint.reinterpret_as_uint()))
    None => None
  }
}

///|
fn csi_u_sequence(event : KeyEvent) -> Bytes? {
  let decoded = utf8_codepoints(event.utf8())
  guard decoded is Some([first]) else { return None }

  let mods = CsiUMods::from_input(event.mods())
  let char = {
    let mut value = first
    if value >= b'A'.to_int() && value <= b'Z'.to_int() && mods.shift {
      value = value.to_char().unwrap().to_ascii_lowercase().to_int()
    }
    if event.unshifted_codepoint() != value.reinterpret_as_uint() {
      mods.shift = false
    }
    value
  }

  let buffer = @buffer.new(size_hint=16)
  buffer.write_bytes(b"\x1B[")
  write_uint_ascii(buffer, char.to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, mods.seq_int().to_uint64())
  buffer.write_byte(b'u')
  Some(buffer.contents())
}

///|
fn KeyEncoder::legacy_alt_prefix(
  self : KeyEncoder,
  event : KeyEvent,
  binding_mods : KeyMods,
  mods : KeyMods,
) -> Byte? {
  if !binding_mods.alt() || !self.alt_esc_prefix {
    return None
  }

  if self.host_is_macos {
    match self.macos_option_as_alt {
      OptionAsAlt::False => return None
      OptionAsAlt::Left =>
        if mods.alt_side() == KeyModSide::Right {
          return None
        }
      OptionAsAlt::Right =>
        if mods.alt_side() == KeyModSide::Left {
          return None
        }
      OptionAsAlt::True => ()
    }
  }

  if event.utf8().length() == 1 {
    return Some(event.utf8()[0])
  }

  if event.unshifted_codepoint() <= 0xFFU {
    return Some(event.unshifted_codepoint().to_byte())
  }

  None
}

///|
fn ctrl_sequence(
  logical_key : Key,
  utf8 : Bytes,
  unshifted_codepoint : UInt,
  mods : KeyMods,
) -> Byte? {
  let ctrl_only = KeyMods::new().with_ctrl(true)
  if !mods.ctrl() {
    return None
  }

  let (char, unset_mods) = {
    let mut current_mods = mods.binding().with_alt(false)
    let current_char = if utf8.length() == 1 {
      Some(utf8[0])
    } else {
      match logical_key.codepoint() {
        Some(codepoint) =>
          if codepoint <= 0xFFU && current_mods == ctrl_only {
            Some(codepoint.to_byte())
          } else {
            None
          }
        None => None
      }
    }
    guard current_char is Some(value) else { return None }

    let mut char = value
    if current_mods.shift() && (char < b'A' || char > b'Z') && char != b'@' {
      current_mods = current_mods.with_shift(false)
    }

    if char >= b'A' &&
      char <= b'Z' &&
      unshifted_codepoint > 0U &&
      unshifted_codepoint <= 0xFFU {
      char = unshifted_codepoint.to_byte()
    }

    (char, current_mods)
  }

  if unset_mods != ctrl_only {
    return None
  }

  match char {
    b' ' => Some(0x00)
    b'/' => Some(0x1F)
    b'0' => Some(48)
    b'1' => Some(49)
    b'2' => Some(0x00)
    b'3' => Some(0x1B)
    b'4' => Some(0x1C)
    b'5' => Some(0x1D)
    b'6' => Some(0x1E)
    b'7' => Some(0x1F)
    b'8' => Some(0x7F)
    b'9' => Some(57)
    b'?' => Some(0x7F)
    b'@' => Some(0x00)
    b'\\' => Some(0x1C)
    b']' => Some(0x1D)
    b'^' => Some(0x1E)
    b'_' => Some(0x1F)
    b'a' => Some(0x01)
    b'b' => Some(0x02)
    b'c' => Some(0x03)
    b'd' => Some(0x04)
    b'e' => Some(0x05)
    b'f' => Some(0x06)
    b'g' => Some(0x07)
    b'h' => Some(0x08)
    b'j' => Some(0x0A)
    b'k' => Some(0x0B)
    b'l' => Some(0x0C)
    b'n' => Some(0x0E)
    b'o' => Some(0x0F)
    b'p' => Some(0x10)
    b'q' => Some(0x11)
    b'r' => Some(0x12)
    b's' => Some(0x13)
    b't' => Some(0x14)
    b'u' => Some(0x15)
    b'v' => Some(0x16)
    b'w' => Some(0x17)
    b'x' => Some(0x18)
    b'y' => Some(0x19)
    b'z' => Some(0x1A)
    b'~' => Some(0x1E)
    _ => None
  }
}

///|
fn KeyEncoder::alt_prevents_text(self : KeyEncoder, mods : KeyMods) -> Bool {
  if !self.host_is_macos {
    return true
  }

  match self.macos_option_as_alt {
    OptionAsAlt::Left => mods.alt_side() == KeyModSide::Left
    OptionAsAlt::Right => mods.alt_side() == KeyModSide::Right
    OptionAsAlt::True => true
    OptionAsAlt::False => false
  }
}

///|
fn kitty_flag_enabled(flags : KittyKeyboardFlags, mask : Byte) -> Bool {
  (flags.0 & mask) != 0
}

///|
fn is_control(codepoint : Int) -> Bool {
  codepoint < 0x20 || codepoint == 0x7F
}

///|
fn is_control_utf8(bytes : Bytes) -> Bool {
  bytes.length() == 1 && is_control(bytes[0].to_int())
}

///|
fn utf8_codepoints(bytes : Bytes) -> Array[Int]? {
  let decoded : Result[String, @utf8.Malformed] = try? @utf8.decode(bytes[:])
  guard decoded is Ok(text) else { return None }
  let result : Array[Int] = []
  for char in text {
    result.push(char.to_int())
  }
  Some(result)
}

///|
fn KittySequence::encode(self : KittySequence) -> Bytes {
  match self.final_byte {
    b'u' | b'~' => self.encode_full()
    _ => self.encode_special()
  }
}

///|
fn KittySequence::encode_full(self : KittySequence) -> Bytes {
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[")
  write_uint_ascii(buffer, self.key.to_uint64())
  match self.alternate_shifted {
    Some(shifted) => {
      buffer.write_byte(b':')
      write_uint_ascii(buffer, shifted.to_uint64())
    }
    None => ()
  }
  match self.alternate_base {
    Some(base) => {
      buffer.write_byte(b':')
      if self.alternate_shifted == None {
        buffer.write_byte(b':')
      }
      write_uint_ascii(buffer, base.to_uint64())
    }
    None => ()
  }

  let mods = self.mods.seq_int()
  let emitted_mods = if self.event != KittySequenceEvent::None &&
    self.event != KittySequenceEvent::Press {
    buffer.write_byte(b';')
    write_uint_ascii(buffer, mods.to_uint64())
    buffer.write_byte(b':')
    write_uint_ascii(buffer, kitty_sequence_event_code(self.event).to_uint64())
    true
  } else if mods > 1U {
    buffer.write_byte(b';')
    write_uint_ascii(buffer, mods.to_uint64())
    true
  } else {
    false
  }

  if self.text.length() > 0 {
    match utf8_codepoints(self.text) {
      Some(codepoints) => {
        let mut count = 0
        for codepoint in codepoints {
          if is_control(codepoint) {
            continue
          }
          if count == 0 {
            if !emitted_mods {
              buffer.write_byte(b';')
            }
            buffer.write_byte(b';')
          } else {
            buffer.write_byte(b':')
          }
          write_uint_ascii(buffer, codepoint.to_uint64())
          count += 1
        }
      }
      None => ()
    }
  }

  buffer.write_byte(self.final_byte)
  buffer.contents()
}

///|
fn KittySequence::encode_special(self : KittySequence) -> Bytes {
  let buffer = @buffer.new(size_hint=12)
  let mods = self.mods.seq_int()
  if self.event != KittySequenceEvent::None {
    buffer.write_bytes(b"\x1B[1;")
    write_uint_ascii(buffer, mods.to_uint64())
    buffer.write_byte(b':')
    write_uint_ascii(buffer, kitty_sequence_event_code(self.event).to_uint64())
    buffer.write_byte(self.final_byte)
    return buffer.contents()
  }

  if mods > 1U {
    buffer.write_bytes(b"\x1B[1;")
    write_uint_ascii(buffer, mods.to_uint64())
    buffer.write_byte(self.final_byte)
    return buffer.contents()
  }

  buffer.write_bytes(b"\x1B[")
  buffer.write_byte(self.final_byte)
  buffer.contents()
}

///|
fn kitty_sequence_event_code(event : KittySequenceEvent) -> UInt {
  match event {
    KittySequenceEvent::None => 0U
    KittySequenceEvent::Press => 1U
    KittySequenceEvent::Repeat => 2U
    KittySequenceEvent::Release => 3U
  }
}

///|
fn CsiUMods::from_input(mods : KeyMods) -> CsiUMods {
  { shift: mods.shift(), alt: mods.alt(), ctrl: mods.ctrl() }
}

///|
fn CsiUMods::int(self : CsiUMods) -> UInt {
  self.shift.to_uint() | (self.alt.to_uint() << 1) | (self.ctrl.to_uint() << 2)
}

///|
fn CsiUMods::seq_int(self : CsiUMods) -> UInt {
  self.int() + 1U
}

///|
fn KittyMods::from_input(
  _action : KeyAction,
  _key : Key,
  mods : KeyMods,
) -> KittyMods {
  {
    shift: mods.shift(),
    alt: mods.alt(),
    ctrl: mods.ctrl(),
    super_: mods.super_(),
    hyper: false,
    meta: false,
    caps_lock: mods.caps_lock(),
    num_lock: mods.num_lock(),
  }
}

///|
fn KittyMods::prevents_text(self : KittyMods, alt_prevents_text : Bool) -> Bool {
  (self.alt && alt_prevents_text) ||
  self.ctrl ||
  self.super_ ||
  self.hyper ||
  self.meta
}

///|
fn KittyMods::int(self : KittyMods) -> UInt {
  self.shift.to_uint() |
  (self.alt.to_uint() << 1) |
  (self.ctrl.to_uint() << 2) |
  (self.super_.to_uint() << 3) |
  (self.hyper.to_uint() << 4) |
  (self.meta.to_uint() << 5) |
  (self.caps_lock.to_uint() << 6) |
  (self.num_lock.to_uint() << 7)
}

///|
fn KittyMods::seq_int(self : KittyMods) -> UInt {
  self.int() + 1U
}

///|
pub fn KeyEncoder::encode(self : KeyEncoder, event : KeyEvent) -> Bytes {
  if self.kitty_flags.0 != 0 {
    self.encode_kitty(event)
  } else {
    self.encode_legacy(event)
  }
}
