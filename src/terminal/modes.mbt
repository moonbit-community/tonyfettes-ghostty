///|
pub enum Mode {
  DisableKeyboard
  Insert
  SendReceiveMode
  Linefeed
  CursorKeys
  Mode132Column
  SlowScroll
  ReverseColors
  Origin
  Wraparound
  Autorepeat
  MouseEventX10
  CursorBlinking
  CursorVisible
  EnableMode3
  ReverseWrap
  AltScreenLegacy
  KeypadKeys
  BackarrowKeyMode
  EnableLeftAndRightMargin
  MouseEventNormal
  MouseEventButton
  MouseEventAny
  FocusEvent
  MouseFormatUtf8
  MouseFormatSgr
  MouseAlternateScroll
  MouseFormatUrxvt
  MouseFormatSgrPixels
  IgnoreKeypadWithNumlock
  AltEscPrefix
  AltSendsEscape
  ReverseWrapExtended
  AltScreen
  SaveCursor
  AltScreenSaveCursorClearEnter
  BracketedPaste
  SynchronizedOutput
  GraphemeCluster
  ReportColorScheme
  InBandSizeReports
} derive(Eq, Debug)

///|
pub struct ModeTag {
  raw : UInt16
} derive(Eq, Debug)

///|
const ModeTagValueMask : UInt16 = 0x7FFF

///|
const ModeTagAnsiMask : UInt16 = 0x8000

///|
pub fn ModeTag::raw(self : ModeTag) -> UInt16 {
  self.raw
}

///|
pub fn ModeTag::value(self : ModeTag) -> UInt16 {
  self.raw & ModeTagValueMask
}

///|
pub fn ModeTag::ansi(self : ModeTag) -> Bool {
  (self.raw & ModeTagAnsiMask) != 0
}

///|
pub fn mode_tag(value : UInt16, ansi : Bool) -> ModeTag {
  { raw: (value & ModeTagValueMask) | (if ansi { ModeTagAnsiMask } else { 0 }) }
}

///|
pub fn mode_tag_from_raw(raw : UInt16) -> ModeTag {
  { raw, }
}

///|
pub fn Mode::tag(self : Mode) -> ModeTag {
  match self {
    DisableKeyboard => mode_tag(2, true)
    Insert => mode_tag(4, true)
    SendReceiveMode => mode_tag(12, true)
    Linefeed => mode_tag(20, true)
    CursorKeys => mode_tag(1, false)
    Mode132Column => mode_tag(3, false)
    SlowScroll => mode_tag(4, false)
    ReverseColors => mode_tag(5, false)
    Origin => mode_tag(6, false)
    Wraparound => mode_tag(7, false)
    Autorepeat => mode_tag(8, false)
    MouseEventX10 => mode_tag(9, false)
    CursorBlinking => mode_tag(12, false)
    CursorVisible => mode_tag(25, false)
    EnableMode3 => mode_tag(40, false)
    ReverseWrap => mode_tag(45, false)
    AltScreenLegacy => mode_tag(47, false)
    KeypadKeys => mode_tag(66, false)
    BackarrowKeyMode => mode_tag(67, false)
    EnableLeftAndRightMargin => mode_tag(69, false)
    MouseEventNormal => mode_tag(1000, false)
    MouseEventButton => mode_tag(1002, false)
    MouseEventAny => mode_tag(1003, false)
    FocusEvent => mode_tag(1004, false)
    MouseFormatUtf8 => mode_tag(1005, false)
    MouseFormatSgr => mode_tag(1006, false)
    MouseAlternateScroll => mode_tag(1007, false)
    MouseFormatUrxvt => mode_tag(1015, false)
    MouseFormatSgrPixels => mode_tag(1016, false)
    IgnoreKeypadWithNumlock => mode_tag(1035, false)
    AltEscPrefix => mode_tag(1036, false)
    AltSendsEscape => mode_tag(1039, false)
    ReverseWrapExtended => mode_tag(1045, false)
    AltScreen => mode_tag(1047, false)
    SaveCursor => mode_tag(1048, false)
    AltScreenSaveCursorClearEnter => mode_tag(1049, false)
    BracketedPaste => mode_tag(2004, false)
    SynchronizedOutput => mode_tag(2026, false)
    GraphemeCluster => mode_tag(2027, false)
    ReportColorScheme => mode_tag(2031, false)
    InBandSizeReports => mode_tag(2048, false)
  }
}

///|
pub fn mode_from_int(value : UInt16, ansi : Bool) -> Mode? {
  if ansi {
    match value {
      2 => Some(DisableKeyboard)
      4 => Some(Insert)
      12 => Some(SendReceiveMode)
      20 => Some(Linefeed)
      _ => None
    }
  } else {
    match value {
      1 => Some(CursorKeys)
      3 => Some(Mode132Column)
      4 => Some(SlowScroll)
      5 => Some(ReverseColors)
      6 => Some(Origin)
      7 => Some(Wraparound)
      8 => Some(Autorepeat)
      9 => Some(MouseEventX10)
      12 => Some(CursorBlinking)
      25 => Some(CursorVisible)
      40 => Some(EnableMode3)
      45 => Some(ReverseWrap)
      47 => Some(AltScreenLegacy)
      66 => Some(KeypadKeys)
      67 => Some(BackarrowKeyMode)
      69 => Some(EnableLeftAndRightMargin)
      1000 => Some(MouseEventNormal)
      1002 => Some(MouseEventButton)
      1003 => Some(MouseEventAny)
      1004 => Some(FocusEvent)
      1005 => Some(MouseFormatUtf8)
      1006 => Some(MouseFormatSgr)
      1007 => Some(MouseAlternateScroll)
      1015 => Some(MouseFormatUrxvt)
      1016 => Some(MouseFormatSgrPixels)
      1035 => Some(IgnoreKeypadWithNumlock)
      1036 => Some(AltEscPrefix)
      1039 => Some(AltSendsEscape)
      1045 => Some(ReverseWrapExtended)
      1047 => Some(AltScreen)
      1048 => Some(SaveCursor)
      1049 => Some(AltScreenSaveCursorClearEnter)
      2004 => Some(BracketedPaste)
      2026 => Some(SynchronizedOutput)
      2027 => Some(GraphemeCluster)
      2031 => Some(ReportColorScheme)
      2048 => Some(InBandSizeReports)
      _ => None
    }
  }
}

///|
pub struct ModePacked {
  mut bits : UInt64
} derive(Eq, Debug)

///|
fn mode_bit_index(mode : Mode) -> Int {
  match mode {
    DisableKeyboard => 0
    Insert => 1
    SendReceiveMode => 2
    Linefeed => 3
    CursorKeys => 4
    Mode132Column => 5
    SlowScroll => 6
    ReverseColors => 7
    Origin => 8
    Wraparound => 9
    Autorepeat => 10
    MouseEventX10 => 11
    CursorBlinking => 12
    CursorVisible => 13
    EnableMode3 => 14
    ReverseWrap => 15
    AltScreenLegacy => 16
    KeypadKeys => 17
    BackarrowKeyMode => 18
    EnableLeftAndRightMargin => 19
    MouseEventNormal => 20
    MouseEventButton => 21
    MouseEventAny => 22
    FocusEvent => 23
    MouseFormatUtf8 => 24
    MouseFormatSgr => 25
    MouseAlternateScroll => 26
    MouseFormatUrxvt => 27
    MouseFormatSgrPixels => 28
    IgnoreKeypadWithNumlock => 29
    AltEscPrefix => 30
    AltSendsEscape => 31
    ReverseWrapExtended => 32
    AltScreen => 33
    SaveCursor => 34
    AltScreenSaveCursorClearEnter => 35
    BracketedPaste => 36
    SynchronizedOutput => 37
    GraphemeCluster => 38
    ReportColorScheme => 39
    InBandSizeReports => 40
  }
}

///|
fn mode_mask(mode : Mode) -> UInt64 {
  1UL << mode_bit_index(mode)
}

///|
let default_mode_mask : UInt64 = mode_mask(SendReceiveMode) |
  mode_mask(Wraparound) |
  mode_mask(CursorVisible) |
  mode_mask(MouseAlternateScroll) |
  mode_mask(IgnoreKeypadWithNumlock) |
  mode_mask(AltEscPrefix)

///|
pub fn empty_mode_packed() -> ModePacked {
  { bits: 0UL }
}

///|
pub fn default_mode_packed() -> ModePacked {
  { bits: default_mode_mask }
}

///|
pub fn ModePacked::get(self : ModePacked, mode : Mode) -> Bool {
  (self.bits & mode_mask(mode)) != 0
}

///|
pub fn ModePacked::set(self : ModePacked, mode : Mode, value : Bool) -> Unit {
  let mask = mode_mask(mode)
  if value {
    self.bits = self.bits | mask
  } else if (self.bits & mask) != 0 {
    self.bits = self.bits ^ mask
  } else {
    ()
  }
}

///|
pub struct ModeState {
  mut values : ModePacked
  mut saved : ModePacked
  default : ModePacked
} derive(Eq, Debug)

///|
pub fn ModeState::new() -> ModeState {
  let defaults = default_mode_packed()
  { values: defaults, saved: empty_mode_packed(), default: defaults }
}

///|
pub fn ModeState::reset(self : ModeState) -> Unit {
  self.values = self.default
  self.saved = empty_mode_packed()
}

///|
pub fn ModeState::set(self : ModeState, mode : Mode, value : Bool) -> Unit {
  self.values.set(mode, value)
}

///|
pub fn ModeState::get(self : ModeState, mode : Mode) -> Bool {
  self.values.get(mode)
}

///|
pub fn ModeState::save(self : ModeState, mode : Mode) -> Unit {
  self.saved.set(mode, self.values.get(mode))
}

///|
pub fn ModeState::restore(self : ModeState, mode : Mode) -> Bool {
  let value = self.saved.get(mode)
  self.values.set(mode, value)
  value
}

///|
pub enum ReportState {
  NotRecognized
  Set
  Reset
  PermanentlySet
  PermanentlyReset
} derive(Eq, Debug)

///|
pub fn ReportState::code(self : ReportState) -> Int {
  match self {
    NotRecognized => 0
    Set => 1
    Reset => 2
    PermanentlySet => 3
    PermanentlyReset => 4
  }
}

///|
pub struct Report {
  tag : ModeTag
  state : ReportState
} derive(Eq, Debug)

///|
pub let report_max_size : Int = b"\x1B[?32767;4$y".length()

///|
pub fn Report::encode(self : Report) -> Bytes {
  let buffer = @buffer.new(size_hint=report_max_size)
  buffer.write_bytes(b"\x1B[")
  if !self.tag.ansi() {
    buffer.write_byte(b'?')
  }
  write_uint_ascii(buffer, self.tag.value().to_uint64())
  buffer.write_byte(b';')
  write_uint_ascii(buffer, self.state.code().to_uint64())
  buffer.write_bytes(b"$y")
  buffer.contents()
}

///|
pub fn ModeState::get_report(self : ModeState, tag : ModeTag) -> Report {
  match mode_from_int(tag.value(), tag.ansi()) {
    Some(mode) => { tag, state: if self.get(mode) { Set } else { Reset } }
    None => { tag, state: NotRecognized }
  }
}
