// Shared low-level ASCII/byte parsing helpers used by the control-string
// decoders (osc, apc, kitty graphics). Core-only; no terminal dependencies.

///|
pub fn find_byte(
  bytes : Array[Byte],
  start : Int,
  end_ : Int,
  needle : Byte,
) -> Int? {
  let mut index = start
  while index < end_ {
    if bytes[index] == needle {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
pub fn slice_equals_ascii(
  bytes : Array[Byte],
  start : Int,
  end_ : Int,
  expected : String,
) -> Bool {
  if end_ - start != expected.length() {
    return false
  }
  let mut index = 0
  while start + index < end_ {
    if bytes[start + index] != expected[index].to_byte() {
      return false
    }
    index += 1
  }
  true
}

///|
pub fn parse_u32_ascii(bytes : Array[Byte], start : Int, end_ : Int) -> UInt? {
  if start >= end_ {
    return None
  }
  let segment : Array[Byte] = []
  let mut index = start
  while index < end_ {
    segment.push(bytes[index])
    index += 1
  }
  parse_kitty_graphics_u32(segment)
}

///|
pub fn parse_i32_ascii(bytes : Array[Byte], start : Int, end_ : Int) -> Int? {
  if start >= end_ {
    return None
  }
  let segment : Array[Byte] = []
  let mut index = start
  while index < end_ {
    segment.push(bytes[index])
    index += 1
  }
  parse_kitty_graphics_i32(segment)
}

///|
pub fn parse_kitty_graphics_u32(bytes : Array[Byte]) -> UInt? {
  if bytes.length() == 0 {
    return None
  }
  let mut value : UInt = 0U
  let limit = 4294967295U
  let mut index = 0
  while index < bytes.length() {
    let byte = bytes[index]
    if byte < b'0' || byte > b'9' {
      return None
    }
    let digit = (byte.to_int() - b'0'.to_int()).reinterpret_as_uint()
    if value > limit / 10U || (value == limit / 10U && digit > limit % 10U) {
      return None
    }
    value = value * 10U + digit
    index += 1
  }
  Some(value)
}

///|
pub fn parse_kitty_graphics_i32(bytes : Array[Byte]) -> Int? {
  if bytes.length() == 0 {
    return None
  }
  let negative = bytes[0] == b'-'
  let start = if negative { 1 } else { 0 }
  if start >= bytes.length() {
    return None
  }
  let mut value : UInt = 0U
  let limit = if negative { 2147483648U } else { 2147483647U }
  let mut index = start
  while index < bytes.length() {
    let byte = bytes[index]
    if byte < b'0' || byte > b'9' {
      return None
    }
    let digit = (byte.to_int() - b'0'.to_int()).reinterpret_as_uint()
    if value > limit / 10U || (value == limit / 10U && digit > limit % 10U) {
      return None
    }
    value = value * 10U + digit
    index += 1
  }
  if negative {
    if value == 2147483648U {
      Some(-2147483648)
    } else {
      Some(-value.reinterpret_as_int())
    }
  } else {
    Some(value.reinterpret_as_int())
  }
}
