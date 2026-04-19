///|
pub(all) struct InvokeCharsetAction {
  bank : ActiveSlot
  charset : Slots
  locking : Bool
} derive(Eq, Debug)

///|
pub(all) enum StreamAction {
  StreamPrint(UInt)
  StreamBell
  StreamBackspace
  StreamHorizontalTab(UInt16)
  StreamLinefeed
  StreamCarriageReturn
  StreamEnquiry
  StreamInvokeCharset(InvokeCharsetAction)
} derive(Eq, Debug)

///|
pub(open) trait StreamHandler {
  vt(Self, StreamAction) -> Unit
  deinit(Self) -> Unit
}

///|
struct Stream[H] {
  handler : H
  parser : Parser
  utf8decoder : Utf8Decoder
}

///|
pub fn[H] Stream::new(handler : H) -> Stream[H] {
  { handler, parser: Parser::new(), utf8decoder: Utf8Decoder::new() }
}

///|
pub fn[H : StreamHandler] Stream::deinit(self : Stream[H]) -> Unit {
  self.parser.deinit()
  H::deinit(self.handler)
}

///|
pub fn[H : StreamHandler] Stream::next_slice(
  self : Stream[H],
  input : Bytes,
) -> Unit {
  self.next_slice_capped(input)
}

///|
fn[H : StreamHandler] Stream::next_slice_capped(
  self : Stream[H],
  input : Bytes,
) -> Unit {
  let mut offset = 0

  while self.utf8decoder.state != AcceptState {
    if offset >= input.length() {
      return
    }
    self.next_utf8(input[offset])
    offset += 1
  }
  if offset >= input.length() {
    return
  }

  offset += self.consume_until_ground(input, offset)
  if offset >= input.length() {
    return
  }

  offset += self.consume_all_escapes(input, offset)

  while offset < input.length() {
    if self.parser.state == Ground {
      self.next_utf8(input[offset])
      offset += 1
    } else {
      offset += self.consume_until_ground(input, offset)
    }

    if offset < input.length() && self.parser.state == Ground {
      offset += self.consume_all_escapes(input, offset)
    }
  }
}

///|
fn[H : StreamHandler] Stream::consume_all_escapes(
  self : Stream[H],
  input : Bytes,
  start : Int,
) -> Int {
  let mut offset = start
  while offset < input.length() && input[offset] == 0x1B {
    self.parser.state = Escape
    self.parser.clear()
    offset += 1
    offset += self.consume_until_ground(input, offset)
  }
  offset - start
}

///|
fn[H : StreamHandler] Stream::consume_until_ground(
  self : Stream[H],
  input : Bytes,
  start : Int,
) -> Int {
  let mut offset = start
  while self.parser.state != Ground {
    if offset >= input.length() {
      return input.length() - start
    }
    self.next_non_utf8(input[offset])
    offset += 1
  }
  offset - start
}

///|
pub fn[H : StreamHandler] Stream::next(self : Stream[H], byte : Byte) -> Unit {
  if self.parser.state == Ground {
    self.next_utf8(byte)
  } else {
    self.next_non_utf8(byte)
  }
}

///|
fn[H : StreamHandler] Stream::next_utf8(self : Stream[H], byte : Byte) -> Unit {
  let (value, consumed) = self.utf8decoder.next(byte)
  if value is Some(codepoint) {
    self.handle_codepoint(codepoint)
  }
  if !consumed {
    let (retry, retry_consumed) = self.utf8decoder.next(byte)
    if retry_consumed && retry is Some(codepoint) {
      self.handle_codepoint(codepoint)
    }
  }
}

///|
fn[H : StreamHandler] Stream::handle_codepoint(
  self : Stream[H],
  codepoint : UInt,
) -> Unit {
  if codepoint <= 0x0FU {
    self.execute(codepoint.to_byte())
    return
  }

  if codepoint == 0x1BU {
    self.parser.state = Escape
    self.parser.clear()
    return
  }

  self.print(codepoint)
}

///|
fn[H : StreamHandler] Stream::next_non_utf8(
  self : Stream[H],
  byte : Byte,
) -> Unit {
  let actions = self.parser.next(byte)
  for action in actions {
    match action {
      Some(Print(codepoint)) => self.print(codepoint)
      Some(Execute(value)) => self.execute(value)
      Some(CsiDispatch(csi)) => self.csi_dispatch(csi)
      Some(EscDispatch(esc)) => self.esc_dispatch(esc)
      Some(OscDispatch(command)) => self.osc_dispatch(command)
      Some(DcsHook(dcs)) => self.dcs_hook(dcs)
      Some(DcsPut(value)) => self.dcs_put(value)
      Some(DcsUnhook) => self.dcs_unhook()
      Some(ApcStart) => self.apc_start()
      Some(ApcPut(value)) => self.apc_put(value)
      Some(ApcEnd) => self.apc_end()
      None => ()
    }
  }
}

///|
fn[H : StreamHandler] Stream::emit(
  self : Stream[H],
  action : StreamAction,
) -> Unit {
  H::vt(self.handler, action)
}

///|
fn[H : StreamHandler] Stream::print(self : Stream[H], codepoint : UInt) -> Unit {
  self.emit(StreamPrint(codepoint))
}

///|
fn[H : StreamHandler] Stream::execute(self : Stream[H], byte : Byte) -> Unit {
  match c0_from_byte(byte) {
    Some(Nul) | Some(Soh) | Some(Stx) => ()
    Some(Enq) => self.emit(StreamEnquiry)
    Some(Bel) => self.emit(StreamBell)
    Some(Bs) => self.emit(StreamBackspace)
    Some(Ht) => self.emit(StreamHorizontalTab(1))
    Some(Lf) | Some(Vt) | Some(Ff) => self.emit(StreamLinefeed)
    Some(Cr) => self.emit(StreamCarriageReturn)
    Some(So) =>
      self.emit(
        StreamInvokeCharset({
          bank: ActiveSlot::Gl,
          charset: Slots::G1,
          locking: false,
        }),
      )
    Some(Si) =>
      self.emit(
        StreamInvokeCharset({
          bank: ActiveSlot::Gl,
          charset: Slots::G0,
          locking: false,
        }),
      )
    None => ()
  }
}

///|
fn[H] Stream::csi_dispatch(self : Stream[H], _csi : Csi) -> Unit {
  ignore(self)
}

///|
fn[H] Stream::esc_dispatch(self : Stream[H], _esc : Esc) -> Unit {
  ignore(self)
}

///|
fn[H] Stream::osc_dispatch(self : Stream[H], _command : Command) -> Unit {
  ignore(self)
}

///|
fn[H] Stream::dcs_hook(self : Stream[H], _dcs : Dcs) -> Unit {
  ignore(self)
}

///|
fn[H] Stream::dcs_put(self : Stream[H], _value : Byte) -> Unit {
  ignore(self)
}

///|
fn[H] Stream::dcs_unhook(self : Stream[H]) -> Unit {
  ignore(self)
}

///|
fn[H] Stream::apc_start(self : Stream[H]) -> Unit {
  ignore(self)
}

///|
fn[H] Stream::apc_put(self : Stream[H], _value : Byte) -> Unit {
  ignore(self)
}

///|
fn[H] Stream::apc_end(self : Stream[H]) -> Unit {
  ignore(self)
}
