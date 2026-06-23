///|
pub(all) struct InvokeCharsetAction {
  bank : @charsets.ActiveSlot
  charset : @charsets.Slots
  locking : Bool
} derive(Eq, Debug)

///|
pub(all) struct ConfigureCharsetAction {
  slot : @charsets.Slots
  charset : @charsets.Charset
} derive(Eq, Debug)

///|
pub(all) struct CursorMovement(UInt16) derive(Eq, Debug)

///|
#valtype
pub(all) struct CursorPosition {
  row : UInt16
  col : UInt16
} derive(Eq, Debug)

///|
#valtype
pub(all) struct Margin {
  top_left : UInt16
  bottom_right : UInt16
} derive(Eq, Debug)

///|
pub(all) struct KittyKeyboardFlags(Byte) derive(Eq, Debug)

///|
/// Owned DCS-hook payload. The `@parser.Dcs` it is built from borrows the
/// parser's reused buffers, but the hook crosses the public `StreamHandler`
/// boundary and a handler typically keeps DCS state across the following
/// `dcs_put` / `dcs_unhook` bytes (which rewind those buffers), so the views are
/// copied into owned storage here — mirroring upstream `dcs.zig` copying the
/// slices into its stored Command. DCS hooks are rare, so this is off the hot
/// path.
struct DcsHookPayload {
  intermediates : Bytes
  params : ReadOnlyArray[UInt16]
  final_byte : Byte
} derive(Eq, Debug)

///|
fn DcsHookPayload::from_dcs(dcs : @parser.Dcs) -> DcsHookPayload {
  {
    intermediates: Bytes::from_array(dcs.intermediates.to_owned()),
    params: ReadOnlyArray::from_array(dcs.params.to_owned()),
    final_byte: dcs.final_byte,
  }
}

///|
pub fn DcsHookPayload::intermediates(self : DcsHookPayload) -> Bytes {
  self.intermediates
}

///|
pub fn DcsHookPayload::params(self : DcsHookPayload) -> ReadOnlyArray[UInt16] {
  self.params
}

///|
pub fn DcsHookPayload::final_byte(self : DcsHookPayload) -> Byte {
  self.final_byte
}

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
  StreamSetMode(@mode.Mode)
  StreamResetMode(@mode.Mode)
  StreamRequestMode(@mode.Mode)
  StreamRequestModeUnknown(@mode.ModeTag)
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
  StreamSetAttribute(@sgr.SgrAttribute)
  StreamCursorStyle(@ansi.CursorStyle)
  StreamTabSet
  StreamTabClearCurrent
  StreamTabClearAll
  StreamTabReset
  StreamInsertBlanks(UInt16)
  StreamDeleteLines(UInt16)
  StreamScrollUp(UInt16)
  StreamScrollDown(UInt16)
  StreamSaveMode(@mode.Mode)
  StreamRestoreMode(@mode.Mode)
  StreamTopAndBottomMargin(Margin)
  StreamLeftAndRightMargin(Margin)
  StreamLeftAndRightMarginAmbiguous
  StreamModifyKeyFormat(@ansi.ModifyKeyFormat)
  StreamMouseShiftCapture(Bool)
  StreamProtectedModeOff
  StreamProtectedModeIso
  StreamProtectedModeDec
  StreamSizeReport(@csi.SizeReportStyle)
  StreamTitlePush(UInt16)
  StreamTitlePop(UInt16)
  StreamXtversion
  StreamWindowTitle(String)
  StreamClipboardContents(@osc.ClipboardContents)
  StreamReportPwd(String)
  StreamShowDesktopNotification(@osc.DesktopNotification)
  StreamProgressReport(@osc.ConEmuProgressReport)
  StreamStartHyperlink(@osc.HyperlinkStart)
  StreamEndHyperlink
  StreamMouseShape(@input.MouseShape)
  StreamKittyColorReport(@osc.KittyColorOsc)
  StreamColorOperation(@osc.ColorCommand)
  StreamSemanticPrompt(@osc.SemanticPrompt)
  StreamDeviceAttributes(@device.DeviceAttributeRequest)
  StreamDeviceStatus(@device.DeviceStatusRequest)
  StreamActiveStatusDisplay(@ansi.StatusDisplay)
  StreamKittyKeyboardQuery
  StreamKittyKeyboardPush(KittyKeyboardFlags)
  StreamKittyKeyboardPop(UInt16)
  StreamKittyKeyboardSet(KittyKeyboardFlags)
  StreamKittyKeyboardSetOr(KittyKeyboardFlags)
  StreamKittyKeyboardSetNot(KittyKeyboardFlags)
  StreamDcsHook(DcsHookPayload)
  StreamDcsPut(Byte)
  StreamDcsUnhook
  StreamApcStart
  StreamApcPut(Byte)
  StreamApcEnd
} derive(Eq, Debug)

///|
pub(open) trait StreamHandler {
  fn vt(Self, StreamAction) -> Unit
  // Print hot-path fast lane: the single most frequent action (one call per
  // printable codepoint) bypasses the boxed `StreamAction` union. Routing it
  // through a dedicated typed method avoids allocating + dropping a
  // `StreamPrint` box per character (the generic `vt` path boxes; this does
  // not). Mirrors upstream's comptime-specialized `vt(.print, …)`.
  fn print(Self, UInt) -> Unit
  fn deinit(Self) -> Unit
}

///|
// Maximum codepoints decoded per `next_slice_capped` call. Mirrors upstream's
// `cp_buf: [4096]u32` in `nextSlice` (src/terminal/stream.zig) — somewhat
// arbitrary; `next_slice` chunks the input so each capped call's plain-text run
// fits, letting the ground decode reuse one buffer with no per-call allocation.
const CP_BUF_LEN = 4096

///|
struct Stream[H] {
  handler : H
  parser : @parser.Parser
  utf8decoder : @utf8_decoder.Utf8Decoder
  // Reused UTF-32 scratch for the ground-state bulk decode
  // (`decode_utf8_until_control_seq`). Allocated once; never escapes the stream.
  cp_buf : FixedArray[UInt]
}

///|
pub fn[H] Stream::new(handler : H) -> Stream[H] {
  {
    handler,
    parser: @parser.Parser::new(),
    utf8decoder: @utf8_decoder.Utf8Decoder::new(),
    cp_buf: FixedArray::make(CP_BUF_LEN, 0U),
  }
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
  // Split the input into chunks that fit `cp_buf`, exactly like upstream's
  // `nextSlice`. Each chunk's ground run decodes into the reused `cp_buf`
  // (one codepoint per input byte at most), so it must not exceed `CP_BUF_LEN`.
  // Partial UTF-8 / escape state straddling a chunk boundary is carried in the
  // decoder/parser and resolved by the next chunk's prologue.
  let total = input.length()
  let mut i = 0
  while i < total {
    let len = if total - i < CP_BUF_LEN { total - i } else { CP_BUF_LEN }
    self.next_slice_capped(input[i:i + len])
    i += len
  }
}

///|
fn[H : StreamHandler] Stream::next_slice_capped(
  self : Stream[H],
  input : BytesView,
) -> Unit {
  let len = input.length()
  let mut offset = 0

  while !self.utf8decoder.is_accept_state() {
    if offset >= len {
      return
    }
    self.next_utf8(input[offset])
    offset += 1
  }
  if offset >= len {
    return
  }

  offset += self.consume_until_ground(input, offset)
  if offset >= len {
    return
  }

  offset += self.consume_all_escapes(input, offset)

  // Ground-state fast path, mirroring upstream's `nextSliceCapped` loop: the
  // fused `decode_utf8_until_control_seq` scans to the next ESC and bulk-decodes
  // the plain-text run before it into `cp_buf` in a single pass, then we drain
  // the escapes. The parser is always in the ground state at the top here —
  // `consume_all_escapes` only stops on a non-ESC byte or on exhaustion, and the
  // print/execute path never leaves it non-ground.
  while offset < len {
    let res = @utf8_decoder.decode_utf8_until_control_seq(
      input[offset:],
      self.cp_buf,
    )
    for i in 0..<res.decoded {
      let cp = self.cp_buf[i]
      // C0 controls <= 0x0F execute; everything else (incl. 0x10-0x1F and
      // ill-formed U+FFFD) prints. Matches upstream's `cp <= 0xF` dispatch.
      if cp <= 0x0FU {
        self.execute(cp.to_byte())
      } else {
        self.print(cp)
      }
    }
    offset += res.consumed
    if offset >= len {
      break
    }

    // The decoder stopped before ESC: a partial UTF-8 sequence at the chunk's
    // tail. Hand the remainder to the scalar decoder, which buffers it so the
    // next chunk's prologue completes it. (Matches upstream.)
    if input[offset] != 0x1B {
      for b in input[offset:] {
        self.next_utf8(b)
      }
      break
    }
    offset += self.consume_all_escapes(input, offset)
  }
}

///|
fn[H : StreamHandler] Stream::consume_all_escapes(
  self : Stream[H],
  input : BytesView,
  start : Int,
) -> Int {
  let mut offset = start
  while offset < input.length() && input[offset] == 0x1B {
    self.parser.enter_escape()
    offset += 1
    offset += self.consume_until_ground(input, offset)
  }
  offset - start
}

///|
fn[H : StreamHandler] Stream::consume_until_ground(
  self : Stream[H],
  input : BytesView,
  start : Int,
) -> Int {
  // Iterate the tail view rather than indexing `input[offset]`: the view
  // iterator carries its own bound, so the byte load is emitted without a
  // per-byte bounds check (an `input[offset]` index re-checks `offset` against
  // the length and panics on every byte). `consumed` counts only bytes actually
  // fed, so it is the single return value whether we stop at ground or run out.
  let mut consumed = 0
  for b in input[start:] {
    if self.parser.is_ground() {
      break
    }
    self.next_non_utf8(b)
    consumed = consumed + 1
  }
  consumed
}

///|
pub fn[H : StreamHandler] Stream::next(self : Stream[H], byte : Byte) -> Unit {
  if self.parser.is_ground() {
    self.next_utf8(byte)
  } else {
    self.next_non_utf8(byte)
  }
}

///|
fn[H : StreamHandler] Stream::next_utf8(self : Stream[H], byte : Byte) -> Unit {
  // No special case for 8-bit C1 controls (0x80-0x9F): in a UTF-8 stream those
  // bytes are continuation bytes, so a standalone one is ill-formed UTF-8. We
  // match upstream's `nextUtf8` (src/terminal/stream.zig) and feed every
  // ground-state byte to the decoder, which yields U+FFFD for the lone C1 and
  // `handle_codepoint` prints it. C1 controls only execute via the parser
  // (non-ground) path; the 7-bit `ESC <final>` form is how a UTF-8 stream
  // invokes them.
  let decoded = self.utf8decoder.next(byte)
  if decoded.value is Some(codepoint) {
    self.handle_codepoint(codepoint)
  }
  if !decoded.consumed {
    let retry = self.utf8decoder.next(byte)
    if retry.consumed && retry.value is Some(codepoint) {
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
    self.parser.enter_escape()
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
  self.dispatch_action(actions[0])
  self.dispatch_action(actions[1])
  self.dispatch_action(actions[2])
}

///|
fn[H : StreamHandler] Stream::dispatch_action(
  self : Stream[H],
  action : @parser.Action?,
) -> Unit {
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

///|
fn[H : StreamHandler] Stream::emit(
  self : Stream[H],
  action : StreamAction,
) -> Unit {
  H::vt(self.handler, action)
}

///|
fn[H : StreamHandler] Stream::print(self : Stream[H], codepoint : UInt) -> Unit {
  // Fast lane: call the handler's typed `print` directly instead of
  // `emit(StreamPrint(codepoint))`, which would box the action. Both the
  // ground-state codepoint path (`handle_codepoint`) and the parser-dispatched
  // `Print` action (`dispatch_action`) funnel through here, so both stop
  // allocating a per-character `StreamPrint`.
  H::print(self.handler, codepoint)
}

///|
fn[H : StreamHandler] Stream::emit_sgr(
  self : Stream[H],
  params : ArrayView[UInt16],
  params_sep : @parser.SepList,
) -> Unit {
  let parser = @sgr.SgrParser::from_params(params, params_sep)
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

  match @ansi.c0_from_byte(byte) {
    Some(Nul) | Some(Soh) | Some(Stx) => ()
    Some(Enq) => self.emit(StreamEnquiry)
    Some(Bel) => self.emit(StreamBell)
    Some(Bs) => self.emit(StreamBackspace)
    Some(Ht) => self.emit(StreamHorizontalTab(1))
    Some(Lf) | Some(Vt) | Some(Ff) => self.emit(StreamLinefeed)
    Some(Cr) => self.emit(StreamCarriageReturn)
    Some(So) =>
      self.emit(StreamInvokeCharset({ bank: Gl, charset: G1, locking: false }))
    Some(Si) =>
      self.emit(StreamInvokeCharset({ bank: Gl, charset: G0, locking: false }))
    None => ()
  }
}

///|
fn[H : StreamHandler] Stream::csi_dispatch(
  self : Stream[H],
  csi : @parser.Csi,
) -> Unit {
  match csi.final_byte {
    b'A' | b'k' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorUp(CursorMovement(value)))
        }
      }
    b'B' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorDown(CursorMovement(value)))
        }
      }
    b'C' =>
      if csi.intermediates is [] {
        let value = default_single_param(csi.params)
        if value is Some(value) {
          self.emit(StreamCursorRight(CursorMovement(value)))
        }
      }
    b'D' | b'j' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorLeft(CursorMovement(value)))
        }
      }
    b'E' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorDown(CursorMovement(value)))
          self.emit(StreamCarriageReturn)
        }
      }
    b'F' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorUp(CursorMovement(value)))
          self.emit(StreamCarriageReturn)
        }
      }
    b'G' | b'`' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorCol(CursorMovement(value)))
        }
      }
    b'H' | b'f' =>
      if csi.intermediates is [] {
        if cursor_position(csi.params) is Some(position) {
          self.emit(StreamCursorPos(position))
        }
      }
    b'I' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamHorizontalTab(value))
        }
      }
    b'J' =>
      if erase_protected(csi.intermediates) is Some(is_protected) {
        match erase_display_mode(csi.params) {
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
      if erase_protected(csi.intermediates) is Some(is_protected) {
        match erase_line_mode(csi.params) {
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
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamInsertLines(value))
        }
      }
    b'M' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamDeleteLines(value))
        }
      }
    b'P' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamDeleteChars(value))
        }
      }
    b'S' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamScrollUp(value))
        }
      }
    b'T' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamScrollDown(value))
        }
      }
    b'h' =>
      if mode_ansi(csi.intermediates) is Some(ansi_mode) {
        for value in csi.params {
          if @mode.mode_from_int(value, ansi_mode) is Some(mode) {
            self.emit(StreamSetMode(mode))
          }
        }
      }
    b'l' =>
      if mode_ansi(csi.intermediates) is Some(ansi_mode) {
        for value in csi.params {
          if @mode.mode_from_int(value, ansi_mode) is Some(mode) {
            self.emit(StreamResetMode(mode))
          }
        }
      }
    b'n' =>
      if device_status_request(csi.intermediates, csi.params) is Some(request) {
        self.emit(StreamDeviceStatus(request))
      } else if csi.intermediates is [b'>'] {
        self.emit(StreamModifyKeyFormat(OtherKeysNumericExcept))
      }
    b'm' =>
      match csi.intermediates {
        [] => self.emit_sgr(csi.params, csi.params_sep)
        [b'>'] =>
          if modify_key_format_action(csi.params) is Some(format) {
            self.emit(StreamModifyKeyFormat(format))
          }
        _ => ()
      }
    b'p' =>
      if request_mode_tag(csi.intermediates, csi.params) is Some(tag) {
        match @mode.mode_from_int(tag.value(), tag.ansi()) {
          Some(mode) => self.emit(StreamRequestMode(mode))
          None => self.emit(StreamRequestModeUnknown(tag))
        }
      }
    b'q' =>
      match csi.intermediates {
        [b' '] =>
          match csi.params {
            [] => self.emit(StreamCursorStyle(Default))
            [value] =>
              if @ansi.cursor_style_from_int(value.to_int()) is Some(style) {
                self.emit(StreamCursorStyle(style))
              }
            _ => ()
          }
        [b'"'] =>
          if protected_mode_action(csi.params) is Some(action) {
            self.emit(action)
          }
        [b'>'] => self.emit(StreamXtversion)
        _ => ()
      }
    b'r' =>
      match csi.intermediates {
        [] =>
          if top_and_bottom_margin(csi.params) is Some(margin) {
            self.emit(StreamTopAndBottomMargin(margin))
          }
        [b'?'] =>
          for value in csi.params {
            if @mode.mode_from_int(value, false) is Some(mode) {
              self.emit(StreamRestoreMode(mode))
            }
          }
        _ => ()
      }
    b'W' =>
      match (csi.intermediates, csi.params) {
        ([], []) | ([], [0]) => self.emit(StreamTabSet)
        ([], [2]) => self.emit(StreamTabClearCurrent)
        ([], [5]) => self.emit(StreamTabClearAll)
        ([b'?'], [5]) => self.emit(StreamTabReset)
        _ => ()
      }
    b'X' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamEraseChars(value))
        }
      }
    b'Z' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamHorizontalTabBack(value))
        }
      }
    b'a' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorColRelative(CursorMovement(value)))
        }
      }
    b'b' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamPrintRepeat(value))
        }
      }
    b'c' =>
      if device_attributes_request(csi.intermediates) is Some(request) {
        self.emit(StreamDeviceAttributes(request))
      }
    b'd' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorRow(CursorMovement(value)))
        }
      }
    b'e' =>
      if csi.intermediates is [] {
        if default_single_param(csi.params) is Some(value) {
          self.emit(StreamCursorRowRelative(CursorMovement(value)))
        }
      }
    b'g' =>
      if csi.intermediates is [] {
        match tab_clear_mode(csi.params) {
          Some(0) => self.emit(StreamTabClearCurrent)
          Some(3) => self.emit(StreamTabClearAll)
          None => ()
          _ => ()
        }
      }
    b's' =>
      match (csi.intermediates, csi.params) {
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
          for value in csi.params {
            if @mode.mode_from_int(value, false) is Some(mode) {
              self.emit(StreamSaveMode(mode))
            }
          }
        ([b'>'], []) | ([b'>'], [0]) =>
          self.emit(StreamMouseShiftCapture(false))
        ([b'>'], [1]) => self.emit(StreamMouseShiftCapture(true))
        _ => ()
      }
    b't' =>
      if csi.intermediates is [] {
        match xtwinops_action(csi.params) {
          Some(StreamSizeReport(style)) => self.emit(StreamSizeReport(style))
          Some(StreamTitlePush(index)) => self.emit(StreamTitlePush(index))
          Some(StreamTitlePop(index)) => self.emit(StreamTitlePop(index))
          _ => ()
        }
      }
    b'u' =>
      match csi.intermediates {
        [] => self.emit(StreamRestoreCursor)
        [b'?'] => self.emit(StreamKittyKeyboardQuery)
        [b'>'] =>
          if kitty_keyboard_push_flags(csi.params) is Some(flags) {
            self.emit(StreamKittyKeyboardPush(flags))
          }
        [b'<'] =>
          self.emit(
            StreamKittyKeyboardPop(kitty_keyboard_pop_count(csi.params)),
          )
        [b'='] =>
          if kitty_keyboard_set_action(csi.params) is Some(action) {
            self.emit(action)
          }
        _ => ()
      }
    b'@' =>
      if csi.intermediates is [] {
        match insert_blanks_count(csi.params) {
          Some(value) => self.emit(StreamInsertBlanks(value))
          None => ()
        }
      }
    b'}' =>
      if csi.intermediates is [b'$'] {
        if active_status_display(csi.params) is Some(display) {
          self.emit(StreamActiveStatusDisplay(display))
        }
      }
    _ => ()
  }
}

///|
fn[H : StreamHandler] Stream::esc_dispatch(
  self : Stream[H],
  esc : @parser.Esc,
) -> Unit {
  match esc.final_byte {
    b'B' => self.configure_charset(esc.intermediates, Ascii)
    b'A' => self.configure_charset(esc.intermediates, British)
    b'0' => self.configure_charset(esc.intermediates, DecSpecial)
    b'7' => if esc.intermediates is [] { self.emit(StreamSaveCursor) }
    b'8' =>
      match esc.intermediates {
        [] => self.emit(StreamRestoreCursor)
        [b'#'] => self.emit(StreamDecaln)
        _ => ()
      }
    b'D' => if esc.intermediates is [] { self.emit(StreamIndex) }
    b'E' => if esc.intermediates is [] { self.emit(StreamNextLine) }
    b'H' => if esc.intermediates is [] { self.emit(StreamTabSet) }
    b'M' => if esc.intermediates is [] { self.emit(StreamReverseIndex) }
    b'N' =>
      if esc.intermediates is [] {
        self.emit_invoke_charset(Gl, G2, true)
      }
    b'O' =>
      if esc.intermediates is [] {
        self.emit_invoke_charset(Gl, G3, true)
      }
    b'n' =>
      if esc.intermediates is [] {
        self.emit_invoke_charset(Gl, G2, false)
      }
    b'o' =>
      if esc.intermediates is [] {
        self.emit_invoke_charset(Gl, G3, false)
      }
    b'~' =>
      if esc.intermediates is [] {
        self.emit_invoke_charset(Gr, G1, false)
      }
    b'}' =>
      if esc.intermediates is [] {
        self.emit_invoke_charset(Gr, G2, false)
      }
    b'|' =>
      if esc.intermediates is [] {
        self.emit_invoke_charset(Gr, G3, false)
      }
    b'=' => if esc.intermediates is [] { self.emit(StreamSetMode(KeypadKeys)) }
    b'>' =>
      if esc.intermediates is [] {
        self.emit(StreamResetMode(KeypadKeys))
      }
    b'V' => if esc.intermediates is [] { self.emit(StreamProtectedModeIso) }
    b'W' => if esc.intermediates is [] { self.emit(StreamProtectedModeOff) }
    b'Z' =>
      if esc.intermediates is [] {
        self.emit(StreamDeviceAttributes(Primary))
      }
    b'c' => if esc.intermediates is [] { self.emit(StreamFullReset) }
    b'\\' => ()
    _ => ()
  }
}

///|
fn[H : StreamHandler] Stream::osc_dispatch(
  self : Stream[H],
  command : @osc.Command,
) -> Unit {
  match command {
    ChangeWindowTitle(title) => self.emit(StreamWindowTitle(title))
    ClipboardContents(contents) => self.emit(StreamClipboardContents(contents))
    KittyClipboardProtocol(_) => ()
    KittyColorProtocol(command) => self.emit(StreamKittyColorReport(command))
    KittyTextSizing(_) => ()
    ShowDesktopNotification(notification) =>
      self.emit(StreamShowDesktopNotification(notification))
    HyperlinkStart(link) => self.emit(StreamStartHyperlink(link))
    HyperlinkEnd => self.emit(StreamEndHyperlink)
    ConEmuSleep(_) => ()
    ConEmuShowMessageBox(_) => ()
    ConEmuChangeTabTitle(_) => ()
    ConEmuProgressReport(report) => self.emit(StreamProgressReport(report))
    ConEmuWaitInput => ()
    ConEmuGuiMacro(_) => ()
    ConEmuRunProcess(_) => ()
    ConEmuOutputEnvironmentVariable(_) => ()
    ConEmuXtermEmulation(_) => ()
    ConEmuComment(_) => ()
    ContextSignal(_) => ()
    SemanticPrompt(prompt) => self.emit(StreamSemanticPrompt(prompt))
    ChangeWindowIcon(_) | Invalid => ()
    ReportPwd(url) => self.emit(StreamReportPwd(url))
    MouseShape(value) =>
      match @input.MouseShape::from_string(value) {
        Some(shape) => self.emit(StreamMouseShape(shape))
        None => ()
      }
    ColorOperation(color_command) =>
      self.emit(StreamColorOperation(color_command))
  }
}

///|
fn[H : StreamHandler] Stream::dcs_hook(
  self : Stream[H],
  dcs : @parser.Dcs,
) -> Unit {
  self.emit(StreamDcsHook(DcsHookPayload::from_dcs(dcs)))
}

///|
fn[H : StreamHandler] Stream::dcs_put(self : Stream[H], value : Byte) -> Unit {
  self.emit(StreamDcsPut(value))
}

///|
fn[H : StreamHandler] Stream::dcs_unhook(self : Stream[H]) -> Unit {
  self.emit(StreamDcsUnhook)
}

///|
fn[H : StreamHandler] Stream::apc_start(self : Stream[H]) -> Unit {
  self.emit(StreamApcStart)
}

///|
fn[H : StreamHandler] Stream::apc_put(self : Stream[H], value : Byte) -> Unit {
  self.emit(StreamApcPut(value))
}

///|
fn[H : StreamHandler] Stream::apc_end(self : Stream[H]) -> Unit {
  self.emit(StreamApcEnd)
}

///|
fn[H : StreamHandler] Stream::emit_invoke_charset(
  self : Stream[H],
  bank : @charsets.ActiveSlot,
  charset : @charsets.Slots,
  locking : Bool,
) -> Unit {
  self.emit(StreamInvokeCharset({ bank, charset, locking }))
}

///|
fn[H : StreamHandler] Stream::configure_charset(
  self : Stream[H],
  intermediates : ArrayView[Byte],
  charset : @charsets.Charset,
) -> Unit {
  match intermediates {
    [b'('] => self.emit(StreamConfigureCharset({ slot: G0, charset }))
    [b')'] => self.emit(StreamConfigureCharset({ slot: G1, charset }))
    [b'*'] => self.emit(StreamConfigureCharset({ slot: G2, charset }))
    [b'+'] => self.emit(StreamConfigureCharset({ slot: G3, charset }))
    _ => ()
  }
}

///|
fn default_single_param(params : ArrayView[UInt16]) -> UInt16? {
  match params {
    [] => Some(1)
    [value] => Some(value)
    _ => None
  }
}

///|
fn cursor_position(params : ArrayView[UInt16]) -> CursorPosition? {
  match params {
    [] => Some({ row: 1, col: 1 })
    [row] => Some({ row, col: 1 })
    [row, col] => Some({ row, col })
    _ => None
  }
}

///|
fn top_and_bottom_margin(params : ArrayView[UInt16]) -> Margin? {
  match params {
    [] => Some({ top_left: 0, bottom_right: 0 })
    [top] => Some({ top_left: top, bottom_right: 0 })
    [top, bottom] => Some({ top_left: top, bottom_right: bottom })
    _ => None
  }
}

///|
fn erase_protected(intermediates : ArrayView[Byte]) -> Bool? {
  match intermediates {
    [] => Some(false)
    [b'?'] => Some(true)
    _ => None
  }
}

///|
fn erase_display_mode(params : ArrayView[UInt16]) -> UInt16? {
  match params {
    [] => Some(0)
    [value] => Some(value)
    _ => None
  }
}

///|
fn device_attributes_request(
  intermediates : ArrayView[Byte],
) -> @device.DeviceAttributeRequest? {
  match intermediates {
    [] => Some(Primary)
    [b'>'] => Some(Secondary)
    [b'='] => Some(Tertiary)
    _ => None
  }
}

///|
fn device_status_request(
  intermediates : ArrayView[Byte],
  params : ArrayView[UInt16],
) -> @device.DeviceStatusRequest? {
  match (intermediates, params) {
    ([], [value]) => @device.device_status_request_from_int(value, false)
    ([b'?'], [value]) => @device.device_status_request_from_int(value, true)
    _ => None
  }
}

///|
fn request_mode_tag(
  intermediates : ArrayView[Byte],
  params : ArrayView[UInt16],
) -> @mode.ModeTag? {
  match (intermediates, params) {
    ([b'$'], [value]) => Some(@mode.mode_tag(value, true))
    ([b'?', b'$'], [value]) => Some(@mode.mode_tag(value, false))
    _ => None
  }
}

///|
fn modify_key_format_action(
  params : ArrayView[UInt16],
) -> @ansi.ModifyKeyFormat? {
  match params {
    [] | [0] => Some(Legacy)
    [1] => Some(CursorKeys)
    [2] => Some(FunctionKeys)
    [4] => Some(OtherKeysNone)
    [4, 2] => Some(OtherKeysNumeric)
    [0, _] => Some(Legacy)
    [1, _] => Some(CursorKeys)
    [2, _] => Some(FunctionKeys)
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
fn kitty_keyboard_push_flags(params : ArrayView[UInt16]) -> KittyKeyboardFlags? {
  match params {
    [value] => kitty_keyboard_flags(value)
    [] => Some(KittyKeyboardFlags(0))
    _ => Some(KittyKeyboardFlags(0))
  }
}

///|
fn kitty_keyboard_pop_count(params : ArrayView[UInt16]) -> UInt16 {
  match params {
    [value] => value
    _ => 1
  }
}

///|
fn kitty_keyboard_set_action(params : ArrayView[UInt16]) -> StreamAction? {
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
fn protected_mode_action(params : ArrayView[UInt16]) -> StreamAction? {
  match params {
    [] => Some(StreamProtectedModeOff)
    [0] | [2] => Some(StreamProtectedModeOff)
    [1] => Some(StreamProtectedModeDec)
    _ => None
  }
}

///|
fn erase_line_mode(params : ArrayView[UInt16]) -> UInt16? {
  match params {
    [] => Some(0)
    [value] => Some(value)
    _ => None
  }
}

///|
fn tab_clear_mode(params : ArrayView[UInt16]) -> UInt16? {
  match params {
    [value] => Some(value)
    _ => None
  }
}

///|
fn insert_blanks_count(params : ArrayView[UInt16]) -> UInt16? {
  match params {
    [] => Some(1)
    [value] => if value == 0 { Some(1) } else { Some(value) }
    _ => None
  }
}

///|
fn active_status_display(params : ArrayView[UInt16]) -> @ansi.StatusDisplay? {
  match params {
    [value] => @ansi.status_display_from_int(value.to_int())
    _ => None
  }
}

///|
fn xtwinops_action(params : ArrayView[UInt16]) -> StreamAction? {
  match params {
    [14] => Some(StreamSizeReport(Csi14t))
    [16] => Some(StreamSizeReport(Csi16t))
    [18] => Some(StreamSizeReport(Csi18t))
    [21] => Some(StreamSizeReport(Csi21t))
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
fn mode_ansi(intermediates : ArrayView[Byte]) -> Bool? {
  match intermediates {
    [] => Some(true)
    [b'?'] => Some(false)
    _ => None
  }
}
