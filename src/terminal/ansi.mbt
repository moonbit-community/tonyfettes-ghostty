///|
pub(all) enum C0 {
  Nul
  Soh
  Stx
  Enq
  Bel
  Bs
  Ht
  Lf
  Vt
  Ff
  Cr
  So
  Si
} derive(Eq, Debug)

///|
pub fn C0::code(self : C0) -> Byte {
  match self {
    Nul => 0x00
    Soh => 0x01
    Stx => 0x02
    Enq => 0x05
    Bel => 0x07
    Bs => 0x08
    Ht => 0x09
    Lf => 0x0A
    Vt => 0x0B
    Ff => 0x0C
    Cr => 0x0D
    So => 0x0E
    Si => 0x0F
  }
}

///|
pub fn c0_from_byte(value : Byte) -> C0? {
  match value {
    0x00 => Some(Nul)
    0x01 => Some(Soh)
    0x02 => Some(Stx)
    0x05 => Some(Enq)
    0x07 => Some(Bel)
    0x08 => Some(Bs)
    0x09 => Some(Ht)
    0x0A => Some(Lf)
    0x0B => Some(Vt)
    0x0C => Some(Ff)
    0x0D => Some(Cr)
    0x0E => Some(So)
    0x0F => Some(Si)
    _ => None
  }
}

///|
pub(all) enum RenditionAspect {
  Default
  Bold
  DefaultFg
  DefaultBg
} derive(Eq, Debug)

///|
pub fn RenditionAspect::code(self : RenditionAspect) -> UInt16 {
  match self {
    Default => 0
    Bold => 1
    DefaultFg => 39
    DefaultBg => 49
  }
}

///|
pub fn rendition_aspect_from_int(value : UInt16) -> RenditionAspect? {
  match value {
    0 => Some(Default)
    1 => Some(Bold)
    39 => Some(DefaultFg)
    49 => Some(DefaultBg)
    _ => None
  }
}

///|
pub(all) enum CursorStyle {
  Default
  BlinkingBlock
  SteadyBlock
  BlinkingUnderline
  SteadyUnderline
  BlinkingBar
  SteadyBar
} derive(Eq, Debug)

///|
pub fn CursorStyle::ordinal(self : CursorStyle) -> Int {
  match self {
    Default => 0
    BlinkingBlock => 1
    SteadyBlock => 2
    BlinkingUnderline => 3
    SteadyUnderline => 4
    BlinkingBar => 5
    SteadyBar => 6
  }
}

///|
pub fn cursor_style_from_int(value : Int) -> CursorStyle? {
  match value {
    0 => Some(Default)
    1 => Some(BlinkingBlock)
    2 => Some(SteadyBlock)
    3 => Some(BlinkingUnderline)
    4 => Some(SteadyUnderline)
    5 => Some(BlinkingBar)
    6 => Some(SteadyBar)
    _ => None
  }
}

///|
pub(all) enum StatusLineType {
  None
  Indicator
  HostWritable
} derive(Eq, Debug)

///|
pub fn StatusLineType::code(self : StatusLineType) -> UInt16 {
  match self {
    None => 0
    Indicator => 1
    HostWritable => 2
  }
}

///|
pub fn status_line_type_from_int(value : UInt16) -> StatusLineType? {
  match value {
    0 => Some(None)
    1 => Some(Indicator)
    2 => Some(HostWritable)
    _ => None
  }
}

///|
pub(all) enum StatusDisplay {
  Main
  StatusLine
} derive(Eq, Debug)

///|
pub fn StatusDisplay::ordinal(self : StatusDisplay) -> Int {
  match self {
    Main => 0
    StatusLine => 1
  }
}

///|
pub fn status_display_from_int(value : Int) -> StatusDisplay? {
  match value {
    0 => Some(Main)
    1 => Some(StatusLine)
    _ => None
  }
}

///|
pub(all) enum ModifyKeyFormat {
  Legacy
  CursorKeys
  FunctionKeys
  OtherKeysNone
  OtherKeysNumericExcept
  OtherKeysNumeric
} derive(Eq, Debug)

///|
pub fn ModifyKeyFormat::ordinal(self : ModifyKeyFormat) -> Int {
  match self {
    Legacy => 0
    CursorKeys => 1
    FunctionKeys => 2
    OtherKeysNone => 3
    OtherKeysNumericExcept => 4
    OtherKeysNumeric => 5
  }
}

///|
pub fn modify_key_format_from_int(value : Int) -> ModifyKeyFormat? {
  match value {
    0 => Some(Legacy)
    1 => Some(CursorKeys)
    2 => Some(FunctionKeys)
    3 => Some(OtherKeysNone)
    4 => Some(OtherKeysNumericExcept)
    5 => Some(OtherKeysNumeric)
    _ => None
  }
}

///|
pub(all) enum ProtectedMode {
  Off
  Iso
  Dec
} derive(Eq, Debug)
