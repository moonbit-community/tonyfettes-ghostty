///|
const DefaultMaxBytes : Int = 1024 * 1024

///|
priv struct DcsHandler {
  mut state : DcsState
  mut max_bytes : Int
}

///|
priv enum DcsCommand {
  XtGetTCap(XtGetTCapCommand)
  Decrqss(DecrqssRequest)
} derive(Eq)

///|
priv struct XtGetTCapCommand {
  data : Array[Byte]
  mut index : Int
} derive(Eq)

///|
priv enum DecrqssRequest {
  Unrecognized
  Sgr
  Decscusr
  Decstbm
  Decslrm
} derive(Eq)

///|
priv enum DcsState {
  Inactive
  Ignore
  XtGetTCap(Array[Byte])
  Decrqss(Array[Byte])
} derive(Eq)

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
fn DcsHandler::try_hook(_self : DcsHandler, dcs : Dcs) -> HookResult? {
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

///|
fn make_plain_dcs(final_byte : Byte) -> Dcs {
  let intermediates : Array[Byte] = []
  let params : Array[UInt16] = []
  { intermediates, params, final_byte }
}

///|
fn make_intermediate_dcs(intermediates : Array[Byte], final_byte : Byte) -> Dcs {
  let params : Array[UInt16] = []
  { intermediates, params, final_byte }
}

///|
fn feed_dcs(handler : DcsHandler, bytes : Bytes) -> Unit {
  for byte in bytes {
    ignore(handler.put(byte))
  }
}

///|
fn expect_item(command : XtGetTCapCommand, expected : Bytes) -> Unit raise {
  guard command.next() is Some(actual) else { fail("expected XTGETTCAP item") }
  guard actual.length() == expected.length() else {
    fail("unexpected XTGETTCAP item length")
  }
  for i in 0..<expected.length() {
    guard actual[i] == expected[i] else {
      fail("unexpected XTGETTCAP item contents")
    }
  }
}

///|
test "dcs/unknown command enters ignore and unhooks cleanly" {
  let handler = DcsHandler::new()
  guard handler.hook(make_plain_dcs(b'A')) == None else {
    fail("expected unknown DCS hook to be ignored")
  }
  guard handler.state == Ignore else { fail("expected ignore state") }
  guard handler.unhook() == None else { fail("expected empty unhook") }
  guard handler.state == Inactive else { fail("expected inactive state") }
}

///|
test "dcs/xtgettcap basics" {
  let handler = DcsHandler::new()
  guard handler.hook(make_intermediate_dcs([b'+'], b'q')) == None else {
    fail("expected XTGETTCAP hook to defer command")
  }
  feed_dcs(handler, b"536D756C78")

  guard handler.unhook() is Some(XtGetTCap(command)) else {
    fail("expected XTGETTCAP command")
  }
  expect_item(command, b"536D756C78")
  guard command.next() == None else { fail("expected one XTGETTCAP item") }
  guard handler.state == Inactive else { fail("expected inactive state") }
}

///|
test "dcs/xtgettcap multiple keys" {
  let handler = DcsHandler::new()
  guard handler.hook(make_intermediate_dcs([b'+'], b'q')) == None else {
    fail("expected XTGETTCAP hook to defer command")
  }
  feed_dcs(handler, b"536D756C78;637570")

  guard handler.unhook() is Some(XtGetTCap(command)) else {
    fail("expected XTGETTCAP command")
  }
  expect_item(command, b"536D756C78")
  expect_item(command, b"637570")
  guard command.next() == None else { fail("expected two XTGETTCAP items") }
}

///|
test "dcs/xtgettcap preserves invalid data and uppercases ascii" {
  let handler = DcsHandler::new()
  guard handler.hook(make_intermediate_dcs([b'+'], b'q')) == None else {
    fail("expected XTGETTCAP hook to defer command")
  }
  feed_dcs(handler, b"who;536D756C78")

  guard handler.unhook() is Some(XtGetTCap(command)) else {
    fail("expected XTGETTCAP command")
  }
  expect_item(command, b"WHO")
  expect_item(command, b"536D756C78")
  guard command.next() == None else { fail("expected two XTGETTCAP items") }
}

///|
test "dcs/decrqss recognizes supported requests" {
  let cases : Array[(Bytes, DecrqssRequest)] = [
    (b"m", Sgr),
    (b"r", Decstbm),
    (b"s", Decslrm),
    (b" q", Decscusr),
  ]

  for entry in cases {
    let handler = DcsHandler::new()
    guard handler.hook(make_intermediate_dcs([b'$'], b'q')) == None else {
      fail("expected DECRQSS hook to defer command")
    }
    feed_dcs(handler, entry.0)
    guard handler.unhook() == Some(Decrqss(entry.1)) else {
      fail("unexpected DECRQSS classification")
    }
  }
}

///|
test "dcs/decrqss invalid and overflow requests are dropped appropriately" {
  let invalid_handler = DcsHandler::new()
  guard invalid_handler.hook(make_intermediate_dcs([b'$'], b'q')) == None else {
    fail("expected DECRQSS hook to defer command")
  }
  feed_dcs(invalid_handler, b"z")
  guard invalid_handler.unhook() == Some(Decrqss(Unrecognized)) else {
    fail("expected invalid DECRQSS request to classify as none")
  }

  let overflow_handler = DcsHandler::new()
  guard overflow_handler.hook(make_intermediate_dcs([b'$'], b'q')) == None else {
    fail("expected DECRQSS hook to defer command")
  }
  feed_dcs(overflow_handler, b"\" q")
  guard overflow_handler.state == Ignore else {
    fail("expected DECRQSS overflow to enter ignore state")
  }
  guard overflow_handler.unhook() == None else {
    fail("expected overflowed DECRQSS to drop command")
  }
}

///|
test "dcs/xtgettcap respects max bytes" {
  let handler = DcsHandler::new()
  handler.set_max_bytes(3)
  guard handler.hook(make_intermediate_dcs([b'+'], b'q')) == None else {
    fail("expected XTGETTCAP hook to defer command")
  }

  feed_dcs(handler, b"ABC")
  guard handler.state == XtGetTCap([b'A', b'B', b'C']) else {
    fail("expected XTGETTCAP buffer to fill to max bytes")
  }

  guard handler.put(b'D') == None else {
    fail("expected overflow put to emit no command")
  }
  guard handler.state == Ignore else {
    fail("expected XTGETTCAP overflow to ignore")
  }
  guard handler.unhook() == None else {
    fail("expected overflowed XTGETTCAP to drop command")
  }
}

///|
test "dcs/private helper and deferred branches" {
  let handler = DcsHandler::new()
  handler.deinit()
  guard handler.state == Inactive else {
    fail("expected deinit to discard state")
  }

  guard handler.put(b'A') == None else {
    fail("expected inactive put to emit no command")
  }
  handler.state = Ignore
  guard handler.put(b'B') == None else {
    fail("expected ignore put to emit no command")
  }

  guard handler.try_hook(make_plain_dcs(b'p')) is None else {
    fail("expected tmux lane to remain deferred")
  }
  guard handler.try_hook(make_intermediate_dcs([b'+'], b'p')) is None else {
    fail("expected invalid XTGETTCAP final to be ignored")
  }
  guard handler.try_hook(make_intermediate_dcs([b'$'], b'p')) is None else {
    fail("expected invalid DECRQSS final to be ignored")
  }
  guard handler.try_hook(make_intermediate_dcs([b'!'], b'q')) is None else {
    fail("expected unknown intermediate to be ignored")
  }
  guard handler.try_hook({
      intermediates: [b'+', b'$'],
      params: [],
      final_byte: b'q',
    })
    is None else {
    fail("expected multi-intermediate dcs to be ignored")
  }

  guard classify_decrqss([]) == Unrecognized else {
    fail("expected empty decrqss to be unrecognized")
  }
  guard classify_decrqss([b' ', b'p']) == Unrecognized else {
    fail("expected invalid two-byte decrqss to be unrecognized")
  }
}

///|
test "panic dcs/hook requires inactive state" {
  let handler = DcsHandler::new()
  handler.state = Ignore
  ignore(handler.hook(make_plain_dcs(b'A')))
}

///|
test "panic dcs/decrqss overflow helper aborts" {
  ignore(classify_decrqss([b'a', b'b', b'c']))
}
