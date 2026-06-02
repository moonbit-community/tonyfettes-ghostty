///|
priv enum ApcState {
  Inactive
  Ignore
  Identify
  Kitty(KittyGraphicsParser)
}

///|
priv enum ApcCommand {
  Kitty(KittyGraphicsCommand)
}

///|
priv struct KittyGraphicsParser {
  bytes : Array[Byte]
}

///|
priv struct ApcHandler {
  mut state : ApcState
}

///|
fn ApcHandler::new() -> ApcHandler {
  { state: Inactive }
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
    Kitty(parser) =>
      match parse_kitty_graphics_command_bytes(parser.bytes) {
        Some(command) => Some(Kitty(command))
        None => None
      }
  }
  self.state = Inactive
  result
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
  let segment : Array[Byte] = []
  let mut index = start
  while index < end_ {
    segment.push(bytes[index])
    index += 1
  }
  parse_kitty_graphics_u32(segment)
}

///|
fn parse_i32_ascii(bytes : Array[Byte], start : Int, end_ : Int) -> Int? {
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
