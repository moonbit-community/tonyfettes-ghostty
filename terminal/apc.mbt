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
