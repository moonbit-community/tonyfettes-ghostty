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
pub(all) struct CursorPosition {
  row : UInt16
  col : UInt16
} derive(Eq, Debug)

///|
pub(all) struct Margin {
  top_left : UInt16
  bottom_right : UInt16
} derive(Eq, Debug)

///|
pub(all) struct KittyKeyboardFlags(Byte) derive(Eq, Debug)

///|
pub(all) enum StreamAction {
  StreamPrint(UInt)
  StreamPrintRepeat(UInt16)
  StreamBell
  StreamBackspace
  StreamHorizontalTab(UInt16)
  StreamHorizontalTabBack(UInt16)
  StreamLinefeed
  StreamCarriageReturn
  StreamIndex
  StreamNextLine
  StreamReverseIndex
  StreamEnquiry
  StreamInvokeCharset(InvokeCharsetAction)
  StreamConfigureCharset(ConfigureCharsetAction)
  StreamSaveCursor
  StreamRestoreCursor
  StreamDecaln
  StreamFullReset
  StreamSetMode(Mode)
  StreamResetMode(Mode)
  StreamRequestMode(Mode)
  StreamRequestModeUnknown(ModeTag)
  StreamCursorUp(CursorMovement)
  StreamCursorDown(CursorMovement)
  StreamCursorLeft(CursorMovement)
  StreamCursorRight(CursorMovement)
  StreamCursorCol(CursorMovement)
  StreamCursorRow(CursorMovement)
  StreamCursorColRelative(CursorMovement)
  StreamCursorRowRelative(CursorMovement)
  StreamCursorPos(CursorPosition)
  StreamEraseDisplayBelow(Bool)
  StreamEraseDisplayAbove(Bool)
  StreamEraseDisplayComplete(Bool)
  StreamEraseDisplayScrollback(Bool)
  StreamEraseDisplayScrollComplete(Bool)
  StreamEraseLineRight(Bool)
  StreamEraseLineLeft(Bool)
  StreamEraseLineComplete(Bool)
  StreamEraseLineRightUnlessPendingWrap(Bool)
  StreamDeleteChars(UInt16)
  StreamEraseChars(UInt16)
  StreamInsertLines(UInt16)
  StreamSetAttribute(SgrAttribute)
  StreamCursorStyle(CursorStyle)
  StreamTabSet
  StreamTabClearCurrent
  StreamTabClearAll
  StreamTabReset
  StreamInsertBlanks(UInt16)
  StreamDeleteLines(UInt16)
  StreamScrollUp(UInt16)
  StreamScrollDown(UInt16)
  StreamSaveMode(Mode)
  StreamRestoreMode(Mode)
  StreamTopAndBottomMargin(Margin)
  StreamLeftAndRightMargin(Margin)
  StreamLeftAndRightMarginAmbiguous
  StreamModifyKeyFormat(ModifyKeyFormat)
  StreamMouseShiftCapture(Bool)
  StreamProtectedModeOff
  StreamProtectedModeIso
  StreamProtectedModeDec
  StreamSizeReport(SizeReportStyle)
  StreamTitlePush(UInt16)
  StreamTitlePop(UInt16)
  StreamXtversion
  StreamWindowTitle(String)
  StreamReportPwd(String)
  StreamStartHyperlink(HyperlinkStart)
  StreamEndHyperlink
  StreamMouseShape(MouseShape)
  StreamColorOperation(ColorCommand)
  StreamSemanticPrompt(SemanticPrompt)
  StreamDeviceAttributes(DeviceAttributeRequest)
  StreamDeviceStatus(DeviceStatusRequest)
  StreamActiveStatusDisplay(StatusDisplay)
  StreamKittyKeyboardQuery
  StreamKittyKeyboardPush(KittyKeyboardFlags)
  StreamKittyKeyboardPop(UInt16)
  StreamKittyKeyboardSet(KittyKeyboardFlags)
  StreamKittyKeyboardSetOr(KittyKeyboardFlags)
  StreamKittyKeyboardSetNot(KittyKeyboardFlags)
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
fn[H : StreamHandler] Stream::emit_sgr(
  self : Stream[H],
  params : Array[UInt16],
  params_sep : SepList,
) -> Unit {
  let parser : SgrParser = { params, params_sep, idx: 0 }
  while parser.next() is Some(attribute) {
    self.emit(StreamSetAttribute(attribute))
  }
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
    b'A' | b'k' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorUp(CursorMovement(value)))
        }
      }
    b'B' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorDown(CursorMovement(value)))
        }
      }
    b'C' =>
      if _csi.intermediates == [] {
        let value = default_single_param(_csi.params)
        if value is Some(value) {
          self.emit(StreamCursorRight(CursorMovement(value)))
        }
      }
    b'D' | b'j' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorLeft(CursorMovement(value)))
        }
      }
    b'E' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorDown(CursorMovement(value)))
          self.emit(StreamCarriageReturn)
        }
      }
    b'F' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorUp(CursorMovement(value)))
          self.emit(StreamCarriageReturn)
        }
      }
    b'G' | b'`' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorCol(CursorMovement(value)))
        }
      }
    b'H' | b'f' =>
      if _csi.intermediates == [] {
        if cursor_position(_csi.params) is Some(position) {
          self.emit(StreamCursorPos(position))
        }
      }
    b'I' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamHorizontalTab(value))
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
    b'L' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamInsertLines(value))
        }
      }
    b'M' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamDeleteLines(value))
        }
      }
    b'P' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamDeleteChars(value))
        }
      }
    b'S' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamScrollUp(value))
        }
      }
    b'T' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamScrollDown(value))
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
    b'n' =>
      if device_status_request(_csi.intermediates, _csi.params) is Some(request) {
        self.emit(StreamDeviceStatus(request))
      } else if _csi.intermediates == [b'>'] {
        self.emit(
          StreamModifyKeyFormat(ModifyKeyFormat::OtherKeysNumericExcept),
        )
      }
    b'm' =>
      match _csi.intermediates {
        [] => self.emit_sgr(_csi.params, _csi.params_sep)
        [b'>'] =>
          if modify_key_format_action(_csi.params) is Some(format) {
            self.emit(StreamModifyKeyFormat(format))
          }
        _ => ()
      }
    b'p' =>
      if request_mode_tag(_csi.intermediates, _csi.params) is Some(tag) {
        match mode_from_int(tag.value(), tag.ansi()) {
          Some(mode) => self.emit(StreamRequestMode(mode))
          None => self.emit(StreamRequestModeUnknown(tag))
        }
      }
    b'q' =>
      match _csi.intermediates {
        [b' '] =>
          match _csi.params {
            [] => self.emit(StreamCursorStyle(CursorStyle::Default))
            [value] =>
              if cursor_style_from_int(value.to_int()) is Some(style) {
                self.emit(StreamCursorStyle(style))
              }
            _ => ()
          }
        [b'"'] =>
          if protected_mode_action(_csi.params) is Some(action) {
            self.emit(action)
          }
        [b'>'] => self.emit(StreamXtversion)
        _ => ()
      }
    b'r' =>
      match _csi.intermediates {
        [] =>
          if top_and_bottom_margin(_csi.params) is Some(margin) {
            self.emit(StreamTopAndBottomMargin(margin))
          }
        [b'?'] =>
          for value in _csi.params {
            if mode_from_int(value, false) is Some(mode) {
              self.emit(StreamRestoreMode(mode))
            }
          }
        _ => ()
      }
    b'W' =>
      match (_csi.intermediates, _csi.params) {
        ([], []) | ([], [0]) => self.emit(StreamTabSet)
        ([], [2]) => self.emit(StreamTabClearCurrent)
        ([], [5]) => self.emit(StreamTabClearAll)
        ([b'?'], [5]) => self.emit(StreamTabReset)
        _ => ()
      }
    b'X' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamEraseChars(value))
        }
      }
    b'Z' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamHorizontalTabBack(value))
        }
      }
    b'a' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorColRelative(CursorMovement(value)))
        }
      }
    b'b' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamPrintRepeat(value))
        }
      }
    b'c' =>
      if device_attributes_request(_csi.intermediates) is Some(request) {
        self.emit(StreamDeviceAttributes(request))
      }
    b'd' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorRow(CursorMovement(value)))
        }
      }
    b'e' =>
      if _csi.intermediates == [] {
        if default_single_param(_csi.params) is Some(value) {
          self.emit(StreamCursorRowRelative(CursorMovement(value)))
        }
      }
    b'g' =>
      if _csi.intermediates == [] {
        match tab_clear_mode(_csi.params) {
          Some(0) => self.emit(StreamTabClearCurrent)
          Some(3) => self.emit(StreamTabClearAll)
          None => ()
          _ => ()
        }
      }
    b's' =>
      match (_csi.intermediates, _csi.params) {
        ([], []) => self.emit(StreamLeftAndRightMarginAmbiguous)
        ([], [left]) =>
          self.emit(
            StreamLeftAndRightMargin({ top_left: left, bottom_right: 0 }),
          )
        ([], [left, right]) =>
          self.emit(
            StreamLeftAndRightMargin({ top_left: left, bottom_right: right }),
          )
        ([b'?'], _) =>
          for value in _csi.params {
            if mode_from_int(value, false) is Some(mode) {
              self.emit(StreamSaveMode(mode))
            }
          }
        ([b'>'], []) | ([b'>'], [0]) =>
          self.emit(StreamMouseShiftCapture(false))
        ([b'>'], [1]) => self.emit(StreamMouseShiftCapture(true))
        _ => ()
      }
    b't' =>
      if _csi.intermediates == [] {
        match xtwinops_action(_csi.params) {
          Some(StreamSizeReport(style)) => self.emit(StreamSizeReport(style))
          Some(StreamTitlePush(index)) => self.emit(StreamTitlePush(index))
          Some(StreamTitlePop(index)) => self.emit(StreamTitlePop(index))
          _ => ()
        }
      }
    b'u' =>
      match _csi.intermediates {
        [] => self.emit(StreamRestoreCursor)
        [b'?'] => self.emit(StreamKittyKeyboardQuery)
        [b'>'] =>
          if kitty_keyboard_push_flags(_csi.params) is Some(flags) {
            self.emit(StreamKittyKeyboardPush(flags))
          }
        [b'<'] =>
          self.emit(
            StreamKittyKeyboardPop(kitty_keyboard_pop_count(_csi.params)),
          )
        [b'='] =>
          if kitty_keyboard_set_action(_csi.params) is Some(action) {
            self.emit(action)
          }
        _ => ()
      }
    b'@' =>
      if _csi.intermediates == [] {
        match insert_blanks_count(_csi.params) {
          Some(value) => self.emit(StreamInsertBlanks(value))
          None => ()
        }
      }
    b'}' =>
      if _csi.intermediates == [b'$'] {
        if active_status_display(_csi.params) is Some(display) {
          self.emit(StreamActiveStatusDisplay(display))
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
    b'8' =>
      match _esc.intermediates {
        [] => self.emit(StreamRestoreCursor)
        [b'#'] => self.emit(StreamDecaln)
        _ => ()
      }
    b'D' => if _esc.intermediates == [] { self.emit(StreamIndex) }
    b'E' => if _esc.intermediates == [] { self.emit(StreamNextLine) }
    b'H' => if _esc.intermediates == [] { self.emit(StreamTabSet) }
    b'M' => if _esc.intermediates == [] { self.emit(StreamReverseIndex) }
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
    b'V' => if _esc.intermediates == [] { self.emit(StreamProtectedModeIso) }
    b'W' => if _esc.intermediates == [] { self.emit(StreamProtectedModeOff) }
    b'Z' =>
      if _esc.intermediates == [] {
        self.emit(StreamDeviceAttributes(DeviceAttributeRequest::Primary))
      }
    b'c' => if _esc.intermediates == [] { self.emit(StreamFullReset) }
    b'\\' => ()
    _ => ()
  }
}

///|
fn[H : StreamHandler] Stream::osc_dispatch(
  self : Stream[H],
  command : Command,
) -> Unit {
  match command {
    ChangeWindowTitle(title) => self.emit(StreamWindowTitle(title))
    ClipboardContents(_) => ()
    KittyClipboardProtocol(_) => ()
    KittyColorProtocol(_) => ()
    ShowDesktopNotification(_) => ()
    HyperlinkStart(link) => self.emit(StreamStartHyperlink(link))
    HyperlinkEnd => self.emit(StreamEndHyperlink)
    ConEmuSleep(_) => ()
    ConEmuShowMessageBox(_) => ()
    ConEmuChangeTabTitle(_) => ()
    ConEmuProgressReport(_) => ()
    ConEmuWaitInput => ()
    ConEmuGuiMacro(_) => ()
    ConEmuRunProcess(_) => ()
    ConEmuOutputEnvironmentVariable(_) => ()
    ConEmuXtermEmulation(_) => ()
    ConEmuComment(_) => ()
    SemanticPrompt(prompt) => self.emit(StreamSemanticPrompt(prompt))
    ChangeWindowIcon(_) | Invalid => ()
    ReportPwd(url) => self.emit(StreamReportPwd(url))
    MouseShape(value) =>
      match MouseShape::from_string(value) {
        Some(shape) => self.emit(StreamMouseShape(shape))
        None => ()
      }
    ColorOperation(color_command) =>
      self.emit(StreamColorOperation(color_command))
  }
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
fn cursor_position(params : Array[UInt16]) -> CursorPosition? {
  match params {
    [] => Some({ row: 1, col: 1 })
    [row] => Some({ row, col: 1 })
    [row, col] => Some({ row, col })
    _ => None
  }
}

///|
fn top_and_bottom_margin(params : Array[UInt16]) -> Margin? {
  match params {
    [] => Some({ top_left: 0, bottom_right: 0 })
    [top] => Some({ top_left: top, bottom_right: 0 })
    [top, bottom] => Some({ top_left: top, bottom_right: bottom })
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
fn device_attributes_request(
  intermediates : Array[Byte],
) -> DeviceAttributeRequest? {
  match intermediates {
    [] => Some(DeviceAttributeRequest::Primary)
    [b'>'] => Some(DeviceAttributeRequest::Secondary)
    [b'='] => Some(DeviceAttributeRequest::Tertiary)
    _ => None
  }
}

///|
fn device_status_request(
  intermediates : Array[Byte],
  params : Array[UInt16],
) -> DeviceStatusRequest? {
  match (intermediates, params) {
    ([], [value]) => device_status_request_from_int(value, false)
    ([b'?'], [value]) => device_status_request_from_int(value, true)
    _ => None
  }
}

///|
fn request_mode_tag(
  intermediates : Array[Byte],
  params : Array[UInt16],
) -> ModeTag? {
  match (intermediates, params) {
    ([b'$'], [value]) => Some(mode_tag(value, true))
    ([b'?', b'$'], [value]) => Some(mode_tag(value, false))
    _ => None
  }
}

///|
fn modify_key_format_action(params : Array[UInt16]) -> ModifyKeyFormat? {
  match params {
    [] | [0] => Some(ModifyKeyFormat::Legacy)
    [1] => Some(ModifyKeyFormat::CursorKeys)
    [2] => Some(ModifyKeyFormat::FunctionKeys)
    [4] => Some(ModifyKeyFormat::OtherKeysNone)
    [4, 2] => Some(ModifyKeyFormat::OtherKeysNumeric)
    [0, _] => Some(ModifyKeyFormat::Legacy)
    [1, _] => Some(ModifyKeyFormat::CursorKeys)
    [2, _] => Some(ModifyKeyFormat::FunctionKeys)
    _ => None
  }
}

///|
fn kitty_keyboard_flags(value : UInt16) -> KittyKeyboardFlags? {
  if value <= 31 {
    Some(KittyKeyboardFlags(value.to_byte()))
  } else {
    None
  }
}

///|
fn kitty_keyboard_push_flags(params : Array[UInt16]) -> KittyKeyboardFlags? {
  match params {
    [value] => kitty_keyboard_flags(value)
    [] => Some(KittyKeyboardFlags(0))
    _ => Some(KittyKeyboardFlags(0))
  }
}

///|
fn kitty_keyboard_pop_count(params : Array[UInt16]) -> UInt16 {
  match params {
    [value] => value
    _ => 1
  }
}

///|
fn kitty_keyboard_set_action(params : Array[UInt16]) -> StreamAction? {
  let flags = if params.length() >= 1 {
    kitty_keyboard_flags(params[0])
  } else {
    Some(KittyKeyboardFlags(0))
  }
  let number : UInt16 = if params.length() >= 2 { params[1] } else { 1 }
  match (flags, number) {
    (Some(flags), 1) => Some(StreamKittyKeyboardSet(flags))
    (Some(flags), 2) => Some(StreamKittyKeyboardSetOr(flags))
    (Some(flags), 3) => Some(StreamKittyKeyboardSetNot(flags))
    _ => None
  }
}

///|
fn protected_mode_action(params : Array[UInt16]) -> StreamAction? {
  match params {
    [] => Some(StreamProtectedModeOff)
    [0] | [2] => Some(StreamProtectedModeOff)
    [1] => Some(StreamProtectedModeDec)
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
fn tab_clear_mode(params : Array[UInt16]) -> UInt16? {
  match params {
    [value] => Some(value)
    _ => None
  }
}

///|
fn insert_blanks_count(params : Array[UInt16]) -> UInt16? {
  match params {
    [] => Some(1)
    [value] => if value == 0 { Some(1) } else { Some(value) }
    _ => None
  }
}

///|
fn active_status_display(params : Array[UInt16]) -> StatusDisplay? {
  match params {
    [value] => status_display_from_int(value.to_int())
    _ => None
  }
}

///|
fn xtwinops_action(params : Array[UInt16]) -> StreamAction? {
  match params {
    [14] => Some(StreamSizeReport(SizeReportStyle::Csi14t))
    [16] => Some(StreamSizeReport(SizeReportStyle::Csi16t))
    [18] => Some(StreamSizeReport(SizeReportStyle::Csi18t))
    [21] => Some(StreamSizeReport(SizeReportStyle::Csi21t))
    [22, scope] => title_push_action(scope, 0)
    [22, scope, index] => title_push_action(scope, index)
    [23, scope] => title_pop_action(scope, 0)
    [23, scope, index] => title_pop_action(scope, index)
    _ => None
  }
}

///|
fn title_push_action(scope : UInt16, index : UInt16) -> StreamAction? {
  if scope == 0 || scope == 2 {
    Some(StreamTitlePush(index))
  } else {
    None
  }
}

///|
fn title_pop_action(scope : UInt16, index : UInt16) -> StreamAction? {
  if scope == 0 || scope == 2 {
    Some(StreamTitlePop(index))
  } else {
    None
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
