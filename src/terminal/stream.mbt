///|
pub(all) struct InvokeCharsetAction {
  bank : ActiveSlot
  charset : Slots
  locking : Bool
} derive(Eq, Debug)

///|
pub(all) struct ConfigureCharsetAction {
  slot : Slots
  charset : Charset
} derive(Eq, Debug)

///|
pub(all) struct CursorMovement(UInt16) derive(Eq, Debug)

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
  StreamConfigureCharset(ConfigureCharsetAction)
  StreamSaveCursor
  StreamRestoreCursor
  StreamSetMode(Mode)
  StreamResetMode(Mode)
  StreamCursorRight(CursorMovement)
  StreamEraseDisplayBelow(Bool)
  StreamEraseDisplayAbove(Bool)
  StreamEraseDisplayComplete(Bool)
  StreamEraseDisplayScrollback(Bool)
  StreamEraseDisplayScrollComplete(Bool)
  StreamEraseLineRight(Bool)
  StreamEraseLineLeft(Bool)
  StreamEraseLineComplete(Bool)
  StreamEraseLineRightUnlessPendingWrap(Bool)
  StreamCursorStyle(CursorStyle)
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
  if self.utf8decoder.state == AcceptState && byte >= 0x80 && byte <= 0x9F {
    self.execute(byte)
    return
  }

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
  if byte > 0x7F {
    self.esc_dispatch({ intermediates: [], final_byte: byte - 0x40 })
    return
  }

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
fn[H : StreamHandler] Stream::csi_dispatch(
  self : Stream[H],
  _csi : Csi,
) -> Unit {
  match _csi.final_byte {
    b'C' =>
      if _csi.intermediates == [] {
        let value = default_single_param(_csi.params)
        if value is Some(value) {
          self.emit(StreamCursorRight(CursorMovement(value)))
        }
      }
    b'J' =>
      if erase_protected(_csi.intermediates) is Some(is_protected) {
        match erase_display_mode(_csi.params) {
          Some(0) => self.emit(StreamEraseDisplayBelow(is_protected))
          Some(1) => self.emit(StreamEraseDisplayAbove(is_protected))
          Some(2) => self.emit(StreamEraseDisplayComplete(is_protected))
          Some(3) => self.emit(StreamEraseDisplayScrollback(is_protected))
          Some(22) => self.emit(StreamEraseDisplayScrollComplete(is_protected))
          None => ()
          _ => ()
        }
      }
    b'K' =>
      if erase_protected(_csi.intermediates) is Some(is_protected) {
        match erase_line_mode(_csi.params) {
          Some(0) => self.emit(StreamEraseLineRight(is_protected))
          Some(1) => self.emit(StreamEraseLineLeft(is_protected))
          Some(2) => self.emit(StreamEraseLineComplete(is_protected))
          Some(4) =>
            self.emit(StreamEraseLineRightUnlessPendingWrap(is_protected))
          None => ()
          _ => ()
        }
      }
    b'h' =>
      if mode_ansi(_csi.intermediates) is Some(ansi_mode) {
        for value in _csi.params {
          if mode_from_int(value, ansi_mode) is Some(mode) {
            self.emit(StreamSetMode(mode))
          }
        }
      }
    b'l' =>
      if mode_ansi(_csi.intermediates) is Some(ansi_mode) {
        for value in _csi.params {
          if mode_from_int(value, ansi_mode) is Some(mode) {
            self.emit(StreamResetMode(mode))
          }
        }
      }
    b'q' =>
      if _csi.intermediates == [b' '] {
        match _csi.params {
          [] => self.emit(StreamCursorStyle(CursorStyle::Default))
          [value] =>
            if cursor_style_from_int(value.to_int()) is Some(style) {
              self.emit(StreamCursorStyle(style))
            }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn[H : StreamHandler] Stream::esc_dispatch(
  self : Stream[H],
  _esc : Esc,
) -> Unit {
  match _esc.final_byte {
    b'B' => self.configure_charset(_esc.intermediates, Charset::Ascii)
    b'A' => self.configure_charset(_esc.intermediates, Charset::British)
    b'0' => self.configure_charset(_esc.intermediates, Charset::DecSpecial)
    b'7' => if _esc.intermediates == [] { self.emit(StreamSaveCursor) }
    b'8' => if _esc.intermediates == [] { self.emit(StreamRestoreCursor) }
    b'N' =>
      if _esc.intermediates == [] {
        self.emit_invoke_charset(ActiveSlot::Gl, Slots::G2, true)
      }
    b'O' =>
      if _esc.intermediates == [] {
        self.emit_invoke_charset(ActiveSlot::Gl, Slots::G3, true)
      }
    b'n' =>
      if _esc.intermediates == [] {
        self.emit_invoke_charset(ActiveSlot::Gl, Slots::G2, false)
      }
    b'o' =>
      if _esc.intermediates == [] {
        self.emit_invoke_charset(ActiveSlot::Gl, Slots::G3, false)
      }
    b'~' =>
      if _esc.intermediates == [] {
        self.emit_invoke_charset(ActiveSlot::Gr, Slots::G1, false)
      }
    b'}' =>
      if _esc.intermediates == [] {
        self.emit_invoke_charset(ActiveSlot::Gr, Slots::G2, false)
      }
    b'|' =>
      if _esc.intermediates == [] {
        self.emit_invoke_charset(ActiveSlot::Gr, Slots::G3, false)
      }
    b'=' =>
      if _esc.intermediates == [] {
        self.emit(StreamSetMode(Mode::KeypadKeys))
      }
    b'>' =>
      if _esc.intermediates == [] {
        self.emit(StreamResetMode(Mode::KeypadKeys))
      }
    b'\\' => ()
    _ => ()
  }
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

///|
fn[H : StreamHandler] Stream::emit_invoke_charset(
  self : Stream[H],
  bank : ActiveSlot,
  charset : Slots,
  locking : Bool,
) -> Unit {
  self.emit(StreamInvokeCharset({ bank, charset, locking }))
}

///|
fn[H : StreamHandler] Stream::configure_charset(
  self : Stream[H],
  intermediates : Array[Byte],
  charset : Charset,
) -> Unit {
  match intermediates {
    [b'('] => self.emit(StreamConfigureCharset({ slot: Slots::G0, charset }))
    [b')'] => self.emit(StreamConfigureCharset({ slot: Slots::G1, charset }))
    [b'*'] => self.emit(StreamConfigureCharset({ slot: Slots::G2, charset }))
    [b'+'] => self.emit(StreamConfigureCharset({ slot: Slots::G3, charset }))
    _ => ()
  }
}

///|
fn default_single_param(params : Array[UInt16]) -> UInt16? {
  match params {
    [] => Some(1)
    [value] => Some(value)
    _ => None
  }
}

///|
fn erase_protected(intermediates : Array[Byte]) -> Bool? {
  match intermediates {
    [] => Some(false)
    [b'?'] => Some(true)
    _ => None
  }
}

///|
fn erase_display_mode(params : Array[UInt16]) -> UInt16? {
  match params {
    [] => Some(0)
    [value] => Some(value)
    _ => None
  }
}

///|
fn erase_line_mode(params : Array[UInt16]) -> UInt16? {
  match params {
    [] => Some(0)
    [value] => Some(value)
    _ => None
  }
}

///|
fn mode_ansi(intermediates : Array[Byte]) -> Bool? {
  match intermediates {
    [] => Some(true)
    [b'?'] => Some(false)
    _ => None
  }
}
