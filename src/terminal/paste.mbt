///|
const BracketedPasteStart : Bytes = b"\x1B[200~"

///|
const BracketedPasteEnd : Bytes = b"\x1B[201~"

///|
const PasteSanitizedSpace : Byte = b' '

///|
const PasteNewline : Byte = b'\n'

///|
const PasteCarriageReturn : Byte = b'\r'

///|
struct PasteOptions {
  bracketed : Bool
} derive(Eq, Debug)

///|
pub fn PasteOptions::new(bracketed : Bool) -> PasteOptions {
  { bracketed, }
}

///|
pub fn PasteOptions::encode(self : PasteOptions, data : Bytes) -> Bytes {
  let buffer = @buffer.new()
  if self.bracketed {
    buffer.write_bytes(BracketedPasteStart)
  }
  for byte in data {
    buffer.write_byte(encoded_paste_byte(byte, self.bracketed))
  }
  if self.bracketed {
    buffer.write_bytes(BracketedPasteEnd)
  }
  buffer.contents()
}

///|
pub fn paste_is_safe(data : Bytes) -> Bool {
  !contains_byte(data, PasteNewline) && !contains_bracketed_paste_end(data)
}

///|
fn encoded_paste_byte(byte : Byte, bracketed : Bool) -> Byte {
  if should_strip_paste_byte(byte) {
    PasteSanitizedSpace
  } else if !bracketed && byte == PasteNewline {
    PasteCarriageReturn
  } else {
    byte
  }
}

///|
fn should_strip_paste_byte(byte : Byte) -> Bool {
  match byte {
    0x00
    | 0x03
    | 0x04
    | 0x05
    | 0x08
    | 0x0F
    | 0x11
    | 0x12
    | 0x13
    | 0x15
    | 0x16
    | 0x17
    | 0x1A
    | 0x1B
    | 0x1C
    | 0x7F => true
    _ => false
  }
}

///|
fn contains_byte(data : Bytes, needle : Byte) -> Bool {
  for byte in data {
    if byte == needle {
      return true
    }
  }
  false
}

///|
fn contains_bracketed_paste_end(data : Bytes) -> Bool {
  let needle_length = BracketedPasteEnd.length()
  if data.length() < needle_length {
    return false
  }

  let limit = data.length() - needle_length
  let mut start = 0
  while start <= limit {
    if bytes_equal_at(data, start, BracketedPasteEnd) {
      return true
    }
    start += 1
  }

  false
}

///|
fn bytes_equal_at(haystack : Bytes, start : Int, needle : Bytes) -> Bool {
  let mut index = 0
  while index < needle.length() {
    if haystack[start + index] != needle[index] {
      return false
    }
    index += 1
  }
  true
}
