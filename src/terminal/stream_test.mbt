///|
struct Recorder {
  actions : Array[StreamAction]
  deinitialized : Array[Bool]
}

///|
impl StreamHandler for Recorder with vt(self, action) {
  self.actions.push(action)
}

///|
impl StreamHandler for Recorder with deinit(self) {
  self.deinitialized.push(true)
}

///|
fn new_stream() -> (Stream[Recorder], Array[StreamAction], Array[Bool]) {
  let actions : Array[StreamAction] = []
  let deinitialized : Array[Bool] = []
  (Stream::new({ actions, deinitialized }), actions, deinitialized)
}

///|
test "stream/print ascii" {
  let (stream, actions, _) = new_stream()
  stream.next(b'x')
  guard actions == [StreamPrint(b'x'.to_uint())] else {
    fail("expected ASCII print action")
  }
}

///|
test "stream/invalid utf8 emits replacement char" {
  let (stream, actions, _) = new_stream()
  stream.next_slice([0xFF])
  guard actions == [StreamPrint(0xFFFDU)] else {
    fail("expected replacement character action")
  }
}

///|
test "stream/incomplete utf8 completes across slices" {
  let (stream, actions, _) = new_stream()
  let expected_empty : Array[StreamAction] = []
  stream.next_slice([0xE0])
  guard actions == expected_empty else {
    fail("expected decoder to hold incomplete prefix")
  }

  stream.next_slice([0xA0])
  guard actions == expected_empty else {
    fail("expected decoder to keep waiting for final byte")
  }

  stream.next_slice([0x80])
  guard actions == [StreamPrint(0x800U)] else {
    fail("expected completed UTF-8 codepoint")
  }
}

///|
test "stream/c0 controls map to base actions" {
  let (stream, actions, _) = new_stream()
  let bytes : Bytes = [0x05, 0x07, 0x08, 0x09, 0x0A, 0x0D, 0x0E, 0x0F]
  for byte in bytes {
    stream.next(byte)
  }

  guard actions ==
    [
      StreamEnquiry,
      StreamBell,
      StreamBackspace,
      StreamHorizontalTab(1),
      StreamLinefeed,
      StreamCarriageReturn,
      StreamInvokeCharset({
        bank: ActiveSlot::Gl,
        charset: Slots::G1,
        locking: false,
      }),
      StreamInvokeCharset({
        bank: ActiveSlot::Gl,
        charset: Slots::G0,
        locking: false,
      }),
    ] else {
    fail("expected C0 controls to map to stream actions")
  }
}

///|
test "stream/ignored escape sequence does not block later text" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B(Bz")
  guard actions ==
    [
      StreamConfigureCharset({ slot: Slots::G0, charset: Charset::Ascii }),
      StreamPrint(b'z'.to_uint()),
    ] else {
    fail("expected configured charset before later text")
  }
}

///|
test "stream/next handles escape state incrementally" {
  let (stream, actions, _) = new_stream()
  stream.next(0x1B)
  stream.next(b'[')
  stream.next(b'm')
  stream.next(b'z')
  guard actions == [StreamPrint(b'z'.to_uint())] else {
    fail("expected printable text after incremental CSI")
  }
}

///|
test "stream/invalid continuation retries same byte as ascii" {
  let (stream, actions, _) = new_stream()
  stream.next_slice([0xE2])
  stream.next_slice(b"A")
  guard actions == [StreamPrint(0xFFFDU), StreamPrint(b'A'.to_uint())] else {
    fail("expected replacement plus retried ASCII byte")
  }
}

///|
test "stream/incomplete escape at slice end leaves no actions" {
  let (stream, actions, _) = new_stream()
  stream.next(0x1B)
  stream.next_slice(b"[")
  let expected_empty : Array[StreamAction] = []
  guard actions == expected_empty else {
    fail("expected no actions for incomplete CSI slice")
  }
}

///|
test "stream/slice fast path can enter escape after printable text" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"a\x1B[")
  guard actions == [StreamPrint(b'a'.to_uint())] else {
    fail("expected printable prefix before incomplete CSI")
  }
}

///|
test "stream/ignored c0 and parser execute fallback stay silent" {
  let (stream, actions, _) = new_stream()
  stream.next(0x00)
  stream.next(0x01)
  stream.next(0x02)
  stream.next(0x1B)
  stream.next(0x18)
  let expected_empty : Array[StreamAction] = []
  guard actions == expected_empty else {
    fail("expected ignored control path to stay silent")
  }
}

///|
test "stream/csi placeholder returns to ground" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[1Hz")
  guard actions == [StreamPrint(b'z'.to_uint())] else {
    fail("expected text after CSI placeholder dispatch")
  }
}

///|
test "stream/osc placeholder returns to ground" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B]0;hi\x07z")
  guard actions == [StreamPrint(b'z'.to_uint())] else {
    fail("expected text after OSC placeholder dispatch")
  }
}

///|
test "stream/dcs placeholder returns to ground" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1BP+qa\x1B\\z")
  guard actions == [StreamPrint(b'z'.to_uint())] else {
    fail("expected text after DCS placeholder dispatch")
  }
}

///|
test "stream/apc placeholder returns to ground" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B_a\x1B\\z")
  guard actions == [StreamPrint(b'z'.to_uint())] else {
    fail("expected text after APC placeholder dispatch")
  }
}

///|
test "stream/esc configure charset subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B(B\x1B)A\x1B*0\x1B+B\x1B-B")
  guard actions ==
    [
      StreamConfigureCharset({ slot: Slots::G0, charset: Charset::Ascii }),
      StreamConfigureCharset({ slot: Slots::G1, charset: Charset::British }),
      StreamConfigureCharset({ slot: Slots::G2, charset: Charset::DecSpecial }),
      StreamConfigureCharset({ slot: Slots::G3, charset: Charset::Ascii }),
    ] else {
    fail("expected charset configuration subset")
  }
}

///|
test "stream/esc save restore and keypad mode" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B7\x1B8\x1B=\x1B>\x1B(7")
  guard actions ==
    [
      StreamSaveCursor,
      StreamRestoreCursor,
      StreamSetMode(Mode::KeypadKeys),
      StreamResetMode(Mode::KeypadKeys),
    ] else {
    fail("expected save/restore cursor and keypad mode actions")
  }
}

///|
test "stream/esc invoke charset subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1BN\x1BO\x1Bn\x1Bo\x1B~\x1B}\x1B|")
  guard actions ==
    [
      StreamInvokeCharset({
        bank: ActiveSlot::Gl,
        charset: Slots::G2,
        locking: true,
      }),
      StreamInvokeCharset({
        bank: ActiveSlot::Gl,
        charset: Slots::G3,
        locking: true,
      }),
      StreamInvokeCharset({
        bank: ActiveSlot::Gl,
        charset: Slots::G2,
        locking: false,
      }),
      StreamInvokeCharset({
        bank: ActiveSlot::Gl,
        charset: Slots::G3,
        locking: false,
      }),
      StreamInvokeCharset({
        bank: ActiveSlot::Gr,
        charset: Slots::G1,
        locking: false,
      }),
      StreamInvokeCharset({
        bank: ActiveSlot::Gr,
        charset: Slots::G2,
        locking: false,
      }),
      StreamInvokeCharset({
        bank: ActiveSlot::Gr,
        charset: Slots::G3,
        locking: false,
      }),
    ] else {
    fail("expected ESC invoke-charset subset")
  }
}

///|
test "stream/c1 execute delegates through esc dispatch" {
  let (stream, actions, _) = new_stream()
  stream.next_slice([0x8E])
  guard actions ==
    [
      StreamInvokeCharset({
        bank: ActiveSlot::Gl,
        charset: Slots::G2,
        locking: true,
      }),
    ] else {
    fail("expected C1 byte to route through ESC dispatch")
  }
}

///|
test "stream/unknown escape still returns to ground" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B%Gz")
  guard actions == [StreamPrint(b'z'.to_uint())] else {
    fail("expected printable text after unknown escape")
  }
}

///|
test "stream/csi cursor right subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[C\x1B[5C\x1B[5;4C\x1B[?3C")
  guard actions ==
    [StreamCursorRight(CursorMovement(1)), StreamCursorRight(CursorMovement(5))] else {
    fail("expected cursor-right subset")
  }
}

///|
test "stream/csi set and reset mode subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[?6h\x1B[?6l\x1B[4h\x1B[4l\x1B[>5h")
  guard actions ==
    [
      StreamSetMode(Mode::Origin),
      StreamResetMode(Mode::Origin),
      StreamSetMode(Mode::Insert),
      StreamResetMode(Mode::Insert),
    ] else {
    fail("expected SM/RM subset")
  }
}

///|
test "stream/csi erase display subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(
    b"\x1B[?J\x1B[?1J\x1B[?2J\x1B[?3J\x1B[J\x1B[22J\x1B[99J\x1B[>0J\x1B[1;2J",
  )
  guard actions ==
    [
      StreamEraseDisplayBelow(true),
      StreamEraseDisplayAbove(true),
      StreamEraseDisplayComplete(true),
      StreamEraseDisplayScrollback(true),
      StreamEraseDisplayBelow(false),
      StreamEraseDisplayScrollComplete(false),
    ] else {
    fail("expected erase-display subset")
  }
}

///|
test "stream/csi erase line subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(
    b"\x1B[?K\x1B[?1K\x1B[K\x1B[2K\x1B[4K\x1B[99K\x1B[<1K\x1B[1;2K",
  )
  guard actions ==
    [
      StreamEraseLineRight(true),
      StreamEraseLineLeft(true),
      StreamEraseLineRight(false),
      StreamEraseLineComplete(false),
      StreamEraseLineRightUnlessPendingWrap(false),
    ] else {
    fail("expected erase-line subset")
  }
}

///|
test "stream/csi cursor style subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[ q\x1B[1 q\x1B[?0 q\x1B[q\x1B[1;2 q")
  guard actions ==
    [
      StreamCursorStyle(CursorStyle::Default),
      StreamCursorStyle(CursorStyle::BlinkingBlock),
    ] else {
    fail("expected cursor-style subset")
  }
}

///|
test "stream/csi tab control subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[W\x1B[0W\x1B[2W\x1B[5W\x1B[?2W\x1B[?5W\x1B[?1;2;3W")
  guard actions ==
    [
      StreamTabSet,
      StreamTabSet,
      StreamTabClearCurrent,
      StreamTabClearAll,
      StreamTabReset,
    ] else {
    fail("expected tab-control subset")
  }
}

///|
test "stream/csi tab clear subset and overflow regression" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[0g\x1B[3g\x1B[388888888888888888888888888888888888g")
  guard actions == [StreamTabClearCurrent, StreamTabClearAll] else {
    fail("expected tab-clear subset")
  }
}

///|
test "stream/csi tab clear ignores empty and multi-param forms" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[g\x1B[1;2g\x1B[0g")
  guard actions == [StreamTabClearCurrent] else {
    fail("expected unsupported tab-clear forms to stay silent")
  }
}

///|
test "stream/csi insert blanks subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[42@\x1B[0@\x1B[?42@")
  guard actions == [StreamInsertBlanks(42), StreamInsertBlanks(1)] else {
    fail("expected insert-blanks subset")
  }
}

///|
test "stream/csi insert blanks defaults and ignores multi-param forms" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[@\x1B[1;2@\x1B[3@")
  guard actions == [StreamInsertBlanks(1), StreamInsertBlanks(3)] else {
    fail("expected default insert-blanks and ignored multi-param form")
  }
}

///|
test "stream/csi shift escape subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[>s\x1B[>0s\x1B[>1s\x1B[>2s\x1B[1 s")
  guard actions ==
    [
      StreamMouseShiftCapture(false),
      StreamMouseShiftCapture(false),
      StreamMouseShiftCapture(true),
    ] else {
    fail("expected shift-escape subset")
  }
}

///|
test "stream/csi save and restore cursor controls" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[s\x1B[u\x1B[1s")
  guard actions == [StreamLeftAndRightMarginAmbiguous, StreamRestoreCursor] else {
    fail("expected save/restore cursor control subset")
  }
}

///|
test "stream/csi size report subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[14t\x1B[16t\x1B[18t\x1B[21t")
  guard actions ==
    [
      StreamSizeReport(SizeReportStyle::Csi14t),
      StreamSizeReport(SizeReportStyle::Csi16t),
      StreamSizeReport(SizeReportStyle::Csi18t),
      StreamSizeReport(SizeReportStyle::Csi21t),
    ] else {
    fail("expected XTWINOPS size-report subset")
  }
}

///|
test "stream/csi invalid size report forms stay silent" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[19t\x1B[14;1t\x1B[21;2t\x1B[>14t")
  let expected_empty : Array[StreamAction] = []
  guard actions == expected_empty else {
    fail("expected invalid CSI t size-report forms to stay silent")
  }
}

///|
test "stream/csi title stack subset" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(
    b"\x1B[22;0t\x1B[22;2t\x1B[22;0;5t\x1B[23;0t\x1B[23;2t\x1B[23;0;5t",
  )
  guard actions ==
    [
      StreamTitlePush(0),
      StreamTitlePush(0),
      StreamTitlePush(5),
      StreamTitlePop(0),
      StreamTitlePop(0),
      StreamTitlePop(5),
    ] else {
    fail("expected title push/pop subset")
  }
}

///|
test "stream/csi title stack rejects unsupported scopes and arity" {
  let (stream, actions, _) = new_stream()
  stream.next_slice(b"\x1B[22;1t\x1B[23;1t\x1B[22t\x1B[23t\x1B[22;0;5;9t")
  let expected_empty : Array[StreamAction] = []
  guard actions == expected_empty else {
    fail("expected invalid title stack forms to stay silent")
  }
}

///|
test "stream/deinit delegates to handler" {
  let (stream, _, deinitialized) = new_stream()
  stream.deinit()
  assert_true(deinitialized == [true])
}
