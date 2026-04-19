///|
priv enum ApcState {
  Inactive
  Ignore
  Identify
  Kitty(KittyGraphicsParser)
} derive(Debug)

///|
priv enum ApcCommand {
  Kitty(KittyGraphicsCommand)
} derive(Eq, Debug)

///|
priv struct KittyGraphicsCommand {
  payload : String
} derive(Eq, Debug)

///|
priv struct KittyGraphicsParser {
  bytes : Array[Byte]
} derive(Debug)

///|
priv struct ApcHandler {
  mut state : ApcState
} derive(Debug)

///|
fn ApcHandler::new() -> ApcHandler {
  { state: Inactive }
}

///|
fn ApcHandler::deinit(self : ApcHandler) -> Unit {
  self.state = Inactive
}

///|
fn ApcHandler::start(self : ApcHandler) -> Unit {
  self.state = Identify
}

///|
fn ApcHandler::feed(self : ApcHandler, byte : Byte) -> Unit {
  match self.state {
    Inactive => ()
    Ignore => ()
    Identify =>
      if byte == b'G' {
        self.state = Kitty({ bytes: [] })
      } else {
        self.state = Ignore
      }
    Kitty(parser) => {
      parser.bytes.push(byte)
      self.state = Kitty(parser)
    }
  }
}

///|
fn ApcHandler::end(self : ApcHandler) -> ApcCommand? {
  let result : ApcCommand? = match self.state {
    Inactive => None
    Ignore => None
    Identify => None
    Kitty(parser) => parse_kitty_graphics_command(parser)
  }
  self.state = Inactive
  result
}

///|
fn parse_kitty_graphics_command(parser : KittyGraphicsParser) -> ApcCommand? {
  if !validate_kitty_graphics_payload(parser.bytes) {
    return None
  }
  Some(Kitty({ payload: apc_captured_string(parser.bytes) }))
}

///|
fn validate_kitty_graphics_payload(bytes : Array[Byte]) -> Bool {
  if bytes.length() == 0 {
    return false
  }

  let mut saw_segment = false
  let mut start = 0
  let mut index = 0
  while index <= bytes.length() {
    if index == bytes.length() || bytes[index] == b',' {
      if index == start {
        return false
      }
      if !validate_kitty_graphics_segment(bytes, start, index) {
        return false
      }
      saw_segment = true
      start = index + 1
    }
    index += 1
  }

  saw_segment
}

///|
fn validate_kitty_graphics_segment(
  bytes : Array[Byte],
  start : Int,
  end_ : Int,
) -> Bool {
  let separator = find_byte(bytes, start, end_, b'=')
  guard separator is Some(eq_index) else { return false }
  guard eq_index > start && eq_index + 1 < end_ else { return false }

  if slice_equals_ascii(bytes, start, eq_index, "i") {
    return parse_u32_ascii(bytes, eq_index + 1, end_) is Some(_)
  }

  if slice_equals_ascii(bytes, start, eq_index, "f") ||
    slice_equals_ascii(bytes, start, eq_index, "s") ||
    slice_equals_ascii(bytes, start, eq_index, "v") {
    return parse_u32_ascii(bytes, eq_index + 1, end_) is Some(_)
  }

  if slice_equals_ascii(bytes, start, eq_index, "z") {
    return parse_i32_ascii(bytes, eq_index + 1, end_) is Some(_)
  }

  true
}

///|
fn find_byte(
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
fn slice_equals_ascii(
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
fn parse_u32_ascii(bytes : Array[Byte], start : Int, end_ : Int) -> UInt? {
  if start >= end_ {
    return None
  }

  let mut value : UInt = 0U
  let limit = 4294967295U
  let mut index = start
  while index < end_ {
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
fn parse_i32_ascii(bytes : Array[Byte], start : Int, end_ : Int) -> Int? {
  if start >= end_ {
    return None
  }

  let negative = bytes[start] == b'-'
  let digits_start = if negative { start + 1 } else { start }
  if digits_start >= end_ {
    return None
  }

  let mut value : UInt = 0U
  let limit = if negative { 2147483648U } else { 2147483647U }
  let mut index = digits_start
  while index < end_ {
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

///|
fn apc_captured_string(buffer : Array[Byte]) -> String {
  let decoder = Utf8Decoder::new()
  let builder = StringBuilder::new(size_hint=buffer.length())
  for byte in buffer {
    let mut consumed = false
    while !consumed {
      let (value, did_consume) = decoder.next(byte)
      consumed = did_consume
      if value is Some(codepoint) {
        builder.write_char(codepoint.reinterpret_as_int().unsafe_to_char())
      }
    }
  }
  builder.to_string()
}
