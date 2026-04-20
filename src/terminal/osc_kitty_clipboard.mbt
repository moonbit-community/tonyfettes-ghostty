///|
pub(all) enum KittyClipboardLocation {
  KittyClipboardPrimary
} derive(Eq, Debug)

///|
pub(all) enum KittyClipboardOperation {
  KittyClipboardRead
  KittyClipboardWalias
  KittyClipboardWdata
  KittyClipboardWrite
} derive(Eq, Debug)

///|
pub(all) enum KittyClipboardStatus {
  KittyClipboardData
  KittyClipboardDone
  KittyClipboardEbusy
  KittyClipboardEinval
  KittyClipboardEio
  KittyClipboardEnosys
  KittyClipboardEperm
  KittyClipboardOk
} derive(Eq, Debug)

///|
struct KittyClipboardOsc {
  metadata_unvalidated : Array[Byte]
  payload_unvalidated : Array[Byte]?
  terminator : Terminator
} derive(Eq, Debug)

///|
fn KittyClipboardOsc::new(
  metadata_unvalidated : Array[Byte],
  payload_unvalidated : Array[Byte]?,
  terminator : Terminator,
) -> KittyClipboardOsc {
  { metadata_unvalidated, payload_unvalidated, terminator }
}

///|
pub fn KittyClipboardOsc::metadata(self : KittyClipboardOsc) -> String {
  captured_string(self.metadata_unvalidated)
}

///|
pub fn KittyClipboardOsc::payload(self : KittyClipboardOsc) -> String? {
  match self.payload_unvalidated {
    Some(payload) => Some(captured_string(payload))
    None => None
  }
}

///|
pub fn KittyClipboardOsc::terminator(self : KittyClipboardOsc) -> Terminator {
  self.terminator
}

///|
pub fn KittyClipboardOsc::id(self : KittyClipboardOsc) -> String? {
  match kitty_clipboard_option_value(self.metadata_unvalidated, b"id") {
    Some(value) =>
      if kitty_clipboard_identifier_is_valid(value) {
        Some(captured_string(value))
      } else {
        None
      }
    None => None
  }
}

///|
pub fn KittyClipboardOsc::location(
  self : KittyClipboardOsc,
) -> KittyClipboardLocation? {
  match kitty_clipboard_option_value(self.metadata_unvalidated, b"loc") {
    Some(value) => kitty_clipboard_location_from_bytes(value)
    None => None
  }
}

///|
pub fn KittyClipboardOsc::mime(self : KittyClipboardOsc) -> String? {
  kitty_clipboard_option_string(self.metadata_unvalidated, b"mime")
}

///|
pub fn KittyClipboardOsc::name(self : KittyClipboardOsc) -> String? {
  kitty_clipboard_option_string(self.metadata_unvalidated, b"name")
}

///|
pub fn KittyClipboardOsc::password(self : KittyClipboardOsc) -> String? {
  kitty_clipboard_option_string(self.metadata_unvalidated, b"password")
}

///|
pub fn KittyClipboardOsc::pw(self : KittyClipboardOsc) -> String? {
  kitty_clipboard_option_string(self.metadata_unvalidated, b"pw")
}

///|
pub fn KittyClipboardOsc::status(
  self : KittyClipboardOsc,
) -> KittyClipboardStatus? {
  match kitty_clipboard_option_value(self.metadata_unvalidated, b"status") {
    Some(value) => kitty_clipboard_status_from_bytes(value)
    None => None
  }
}

///|
pub fn KittyClipboardOsc::operation(
  self : KittyClipboardOsc,
) -> KittyClipboardOperation? {
  match kitty_clipboard_option_value(self.metadata_unvalidated, b"type") {
    Some(value) => kitty_clipboard_operation_from_bytes(value)
    None => None
  }
}

///|
fn parse_kitty_clipboard_command(
  buffer : Array[Byte],
  terminator_ch : Byte?,
) -> Command {
  let separator = find_byte(buffer, 0, buffer.length(), b';')
  let metadata_end = match separator {
    Some(index) => index
    None => buffer.length()
  }
  let metadata = copy_bytes_range(buffer, 0, metadata_end)
  let payload = match separator {
    Some(index) => Some(copy_bytes_range(buffer, index + 1, buffer.length()))
    None => None
  }
  KittyClipboardProtocol(
    KittyClipboardOsc::new(metadata, payload, terminator_init(terminator_ch)),
  )
}

///|
fn kitty_clipboard_option_string(
  metadata : Array[Byte],
  key : Bytes,
) -> String? {
  match kitty_clipboard_option_value(metadata, key) {
    Some(value) => Some(captured_string(value))
    None => None
  }
}

///|
fn kitty_clipboard_option_value(
  metadata : Array[Byte],
  key : Bytes,
) -> Array[Byte]? {
  let mut pos = 0
  while pos < metadata.length() {
    while pos < metadata.length() &&
          kitty_clipboard_is_whitespace(metadata[pos]) {
      pos += 1
    }
    if pos >= metadata.length() {
      return None
    }

    if !slice_starts_with_bytes(metadata, pos, key) {
      pos = match find_byte(metadata, pos, metadata.length(), b':') {
        Some(index) => index + 1
        None => return None
      }
      continue
    }

    pos += key.length()
    while pos < metadata.length() &&
          kitty_clipboard_is_whitespace(metadata[pos]) {
      pos += 1
    }
    if pos >= metadata.length() || metadata[pos] != b'=' {
      return None
    }

    let value_end = match find_byte(metadata, pos, metadata.length(), b':') {
      Some(index) => index
      None => metadata.length()
    }
    let (trimmed_start, trimmed_end) = trim_ascii_spaces(
      metadata,
      pos + 1,
      value_end,
    )
    return Some(copy_bytes_range(metadata, trimmed_start, trimmed_end))
  }

  None
}

///|
fn kitty_clipboard_location_from_bytes(
  value : Array[Byte],
) -> KittyClipboardLocation? {
  if slice_equals_ascii(value, 0, value.length(), "primary") {
    Some(KittyClipboardPrimary)
  } else {
    None
  }
}

///|
fn kitty_clipboard_operation_from_bytes(
  value : Array[Byte],
) -> KittyClipboardOperation? {
  if slice_equals_ascii(value, 0, value.length(), "read") {
    return Some(KittyClipboardRead)
  }
  if slice_equals_ascii(value, 0, value.length(), "walias") {
    return Some(KittyClipboardWalias)
  }
  if slice_equals_ascii(value, 0, value.length(), "wdata") {
    return Some(KittyClipboardWdata)
  }
  if slice_equals_ascii(value, 0, value.length(), "write") {
    return Some(KittyClipboardWrite)
  }
  None
}

///|
fn kitty_clipboard_status_from_bytes(
  value : Array[Byte],
) -> KittyClipboardStatus? {
  if slice_equals_ascii(value, 0, value.length(), "DATA") {
    return Some(KittyClipboardData)
  }
  if slice_equals_ascii(value, 0, value.length(), "DONE") {
    return Some(KittyClipboardDone)
  }
  if slice_equals_ascii(value, 0, value.length(), "EBUSY") {
    return Some(KittyClipboardEbusy)
  }
  if slice_equals_ascii(value, 0, value.length(), "EINVAL") {
    return Some(KittyClipboardEinval)
  }
  if slice_equals_ascii(value, 0, value.length(), "EIO") {
    return Some(KittyClipboardEio)
  }
  if slice_equals_ascii(value, 0, value.length(), "ENOSYS") {
    return Some(KittyClipboardEnosys)
  }
  if slice_equals_ascii(value, 0, value.length(), "EPERM") {
    return Some(KittyClipboardEperm)
  }
  if slice_equals_ascii(value, 0, value.length(), "OK") {
    return Some(KittyClipboardOk)
  }
  None
}

///|
const KittyClipboardIdentifierChars : Bytes = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_+."

///|
fn kitty_clipboard_identifier_is_valid(value : Array[Byte]) -> Bool {
  if value.length() == 0 {
    return false
  }

  for byte in value {
    if !kitty_clipboard_identifier_byte_allowed(byte) {
      return false
    }
  }
  true
}

///|
fn kitty_clipboard_identifier_byte_allowed(value : Byte) -> Bool {
  for allowed in KittyClipboardIdentifierChars {
    if value == allowed {
      return true
    }
  }
  false
}

///|
fn slice_starts_with_bytes(
  bytes : Array[Byte],
  start : Int,
  expected : Bytes,
) -> Bool {
  if start + expected.length() > bytes.length() {
    return false
  }

  let mut index = 0
  while index < expected.length() {
    if bytes[start + index] != expected[index] {
      return false
    }
    index += 1
  }

  true
}

///|
fn kitty_clipboard_is_whitespace(value : Byte) -> Bool {
  value == b' ' ||
  value == b'\t' ||
  value == b'\n' ||
  value == b'\r' ||
  value == 0x0B ||
  value == 0x0C
}
