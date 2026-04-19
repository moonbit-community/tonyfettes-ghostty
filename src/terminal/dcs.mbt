///|
const DefaultMaxBytes : Int = 1024 * 1024

///|
priv struct DcsHandler {
  mut state : DcsState
  mut max_bytes : Int
} derive(Debug)

///|
priv enum DcsCommand {
  XtGetTCap(XtGetTCapCommand)
  Decrqss(DecrqssRequest)
} derive(Eq, Debug)

///|
priv struct XtGetTCapCommand {
  data : Array[Byte]
  mut index : Int
} derive(Eq, Debug)

///|
priv enum DecrqssRequest {
  Unrecognized
  Sgr
  Decscusr
  Decstbm
  Decslrm
} derive(Eq, Debug)

///|
priv enum DcsState {
  Inactive
  Ignore
  XtGetTCap(Array[Byte])
  Decrqss(Array[Byte])
} derive(Eq, Debug)

///|
priv struct HookResult {
  state : DcsState
  command : DcsCommand?
}

///|
fn DcsHandler::new() -> DcsHandler {
  { state: Inactive, max_bytes: DefaultMaxBytes }
}

///|
fn DcsHandler::set_max_bytes(self : DcsHandler, value : Int) -> Unit {
  self.max_bytes = value
}

///|
fn DcsHandler::deinit(self : DcsHandler) -> Unit {
  self.discard()
}

///|
fn DcsHandler::hook(self : DcsHandler, dcs : Dcs) -> DcsCommand? {
  guard self.state == Inactive else {
    abort("DCS hook requires inactive state")
  }

  self.state = Ignore
  match self.try_hook(dcs) {
    Some(result) => {
      self.state = result.state
      result.command
    }
    None => None
  }
}

///|
fn DcsHandler::put(self : DcsHandler, byte : Byte) -> DcsCommand? {
  match self.state {
    Inactive | Ignore => None
    XtGetTCap(buffer) =>
      if buffer.length() >= self.max_bytes {
        self.discard()
        self.state = Ignore
        None
      } else {
        buffer.push(byte)
        None
      }
    Decrqss(buffer) =>
      if buffer.length() >= 2 {
        self.discard()
        self.state = Ignore
        None
      } else {
        buffer.push(byte)
        None
      }
  }
}

///|
fn DcsHandler::unhook(self : DcsHandler) -> DcsCommand? {
  let command = match self.state {
    Inactive | Ignore => no_dcs_command()
    XtGetTCap(buffer) =>
      Some(DcsCommand::XtGetTCap({ data: uppercased_ascii(buffer), index: 0 }))
    Decrqss(buffer) => Some(DcsCommand::Decrqss(classify_decrqss(buffer)))
  }
  self.state = Inactive
  command
}

///|
fn DcsHandler::discard(self : DcsHandler) -> Unit {
  self.state = Inactive
}

///|
fn DcsHandler::try_hook(self : DcsHandler, dcs : Dcs) -> HookResult? {
  match dcs.intermediates.length() {
    0 =>
      match dcs.final_byte {
        // Tmux control mode is deferred for this slice.
        b'p' => None
        _ => None
      }
    1 =>
      match dcs.intermediates[0] {
        b'+' =>
          if dcs.final_byte == b'q' {
            Some({ state: XtGetTCap([]), command: None })
          } else {
            None
          }
        b'$' =>
          if dcs.final_byte == b'q' {
            Some({ state: Decrqss([]), command: None })
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn no_dcs_command() -> DcsCommand? {
  None
}

///|
fn XtGetTCapCommand::next(self : XtGetTCapCommand) -> Array[Byte]? {
  if self.index >= self.data.length() {
    return None
  }

  let item : Array[Byte] = []
  let mut i = self.index
  while i < self.data.length() && self.data[i] != b';' {
    item.push(self.data[i])
    i += 1
  }

  self.index = i + 1
  Some(item)
}

///|
fn classify_decrqss(buffer : Array[Byte]) -> DecrqssRequest {
  match buffer.length() {
    0 => Unrecognized
    1 =>
      match buffer[0] {
        b'm' => Sgr
        b'r' => Decstbm
        b's' => Decslrm
        _ => Unrecognized
      }
    2 =>
      if buffer[0] == b' ' && buffer[1] == b'q' {
        Decscusr
      } else {
        Unrecognized
      }
    _ => abort("DECRQSS buffer overflowed its fixed limit")
  }
}

///|
fn uppercased_ascii(source : Array[Byte]) -> Array[Byte] {
  let result : Array[Byte] = []
  for value in source {
    result.push(to_upper_ascii(value))
  }
  result
}

///|
fn to_upper_ascii(value : Byte) -> Byte {
  if value >= b'a' && value <= b'z' {
    (value.to_int() - 32).to_byte()
  } else {
    value
  }
}
