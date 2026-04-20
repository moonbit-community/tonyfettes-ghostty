///|
pub(all) suberror ColorParseError {
  InvalidFormat
} derive(Eq, Debug)

///|
struct RGB {
  r : Byte
  g : Byte
  b : Byte
} derive(Eq, Debug)

///|
pub fn RGB::new(r : Byte, g : Byte, b : Byte) -> RGB {
  { r, g, b }
}

///|
pub fn RGB::r(self : RGB) -> Byte {
  self.r
}

///|
pub fn RGB::g(self : RGB) -> Byte {
  self.g
}

///|
pub fn RGB::b(self : RGB) -> Byte {
  self.b
}

///|
pub(all) enum Name {
  Black
  Red
  Green
  Yellow
  Blue
  Magenta
  Cyan
  White
  BrightBlack
  BrightRed
  BrightGreen
  BrightYellow
  BrightBlue
  BrightMagenta
  BrightCyan
  BrightWhite
} derive(Eq, Debug)

///|
pub fn Name::code(self : Name) -> Byte {
  match self {
    Black => 0
    Red => 1
    Green => 2
    Yellow => 3
    Blue => 4
    Magenta => 5
    Cyan => 6
    White => 7
    BrightBlack => 8
    BrightRed => 9
    BrightGreen => 10
    BrightYellow => 11
    BrightBlue => 12
    BrightMagenta => 13
    BrightCyan => 14
    BrightWhite => 15
  }
}

///|
pub fn Name::default_rgb(self : Name) -> RGB {
  match self {
    Black => { r: 0x1D, g: 0x1F, b: 0x21 }
    Red => { r: 0xCC, g: 0x66, b: 0x66 }
    Green => { r: 0xB5, g: 0xBD, b: 0x68 }
    Yellow => { r: 0xF0, g: 0xC6, b: 0x74 }
    Blue => { r: 0x81, g: 0xA2, b: 0xBE }
    Magenta => { r: 0xB2, g: 0x94, b: 0xBB }
    Cyan => { r: 0x8A, g: 0xBE, b: 0xB7 }
    White => { r: 0xC5, g: 0xC8, b: 0xC6 }
    BrightBlack => { r: 0x66, g: 0x66, b: 0x66 }
    BrightRed => { r: 0xD5, g: 0x4E, b: 0x53 }
    BrightGreen => { r: 0xB9, g: 0xCA, b: 0x4A }
    BrightYellow => { r: 0xE7, g: 0xC5, b: 0x47 }
    BrightBlue => { r: 0x7A, g: 0xA6, b: 0xDA }
    BrightMagenta => { r: 0xC3, g: 0x97, b: 0xD8 }
    BrightCyan => { r: 0x70, g: 0xC0, b: 0xB1 }
    BrightWhite => { r: 0xEA, g: 0xEA, b: 0xEA }
  }
}

///|
pub(all) enum Special {
  Bold
  Underline
  Blink
  Reverse
  Italic
} derive(Eq, Debug)

///|
const PaletteLength : UInt16 = 256

///|
pub fn Special::osc4(self : Special) -> UInt16 {
  match self {
    Bold => PaletteLength + 0
    Underline => PaletteLength + 1
    Blink => PaletteLength + 2
    Reverse => PaletteLength + 3
    Italic => PaletteLength + 4
  }
}

///|
pub(all) enum Dynamic {
  Foreground
  Background
  Cursor
  PointerForeground
  PointerBackground
  TektronixForeground
  TektronixBackground
  HighlightBackground
  TektronixCursor
  HighlightForeground
} derive(Eq, Debug)

///|
pub fn Dynamic::code(self : Dynamic) -> UInt16 {
  match self {
    Foreground => 10
    Background => 11
    Cursor => 12
    PointerForeground => 13
    PointerBackground => 14
    TektronixForeground => 15
    TektronixBackground => 16
    HighlightBackground => 17
    TektronixCursor => 18
    HighlightForeground => 19
  }
}

///|
pub fn Dynamic::next(self : Dynamic) -> Dynamic? {
  match self {
    Foreground => Some(Background)
    Background => Some(Cursor)
    Cursor => Some(PointerForeground)
    PointerForeground => Some(PointerBackground)
    PointerBackground => Some(TektronixForeground)
    TektronixForeground => Some(TektronixBackground)
    TektronixBackground => Some(HighlightBackground)
    HighlightBackground => Some(TektronixCursor)
    TektronixCursor => Some(HighlightForeground)
    HighlightForeground => None
  }
}

///|
const PaletteLengthInt : Int = 256

///|
fn default_palette_value() -> Array[RGB] {
  [
    RGB::new(29, 31, 33),
    RGB::new(204, 102, 102),
    RGB::new(181, 189, 104),
    RGB::new(240, 198, 116),
    RGB::new(129, 162, 190),
    RGB::new(178, 148, 187),
    RGB::new(138, 190, 183),
    RGB::new(197, 200, 198),
    RGB::new(102, 102, 102),
    RGB::new(213, 78, 83),
    RGB::new(185, 202, 74),
    RGB::new(231, 197, 71),
    RGB::new(122, 166, 218),
    RGB::new(195, 151, 216),
    RGB::new(112, 192, 177),
    RGB::new(234, 234, 234),
    RGB::new(0, 0, 0),
    RGB::new(0, 0, 95),
    RGB::new(0, 0, 135),
    RGB::new(0, 0, 175),
    RGB::new(0, 0, 215),
    RGB::new(0, 0, 255),
    RGB::new(0, 95, 0),
    RGB::new(0, 95, 95),
    RGB::new(0, 95, 135),
    RGB::new(0, 95, 175),
    RGB::new(0, 95, 215),
    RGB::new(0, 95, 255),
    RGB::new(0, 135, 0),
    RGB::new(0, 135, 95),
    RGB::new(0, 135, 135),
    RGB::new(0, 135, 175),
    RGB::new(0, 135, 215),
    RGB::new(0, 135, 255),
    RGB::new(0, 175, 0),
    RGB::new(0, 175, 95),
    RGB::new(0, 175, 135),
    RGB::new(0, 175, 175),
    RGB::new(0, 175, 215),
    RGB::new(0, 175, 255),
    RGB::new(0, 215, 0),
    RGB::new(0, 215, 95),
    RGB::new(0, 215, 135),
    RGB::new(0, 215, 175),
    RGB::new(0, 215, 215),
    RGB::new(0, 215, 255),
    RGB::new(0, 255, 0),
    RGB::new(0, 255, 95),
    RGB::new(0, 255, 135),
    RGB::new(0, 255, 175),
    RGB::new(0, 255, 215),
    RGB::new(0, 255, 255),
    RGB::new(95, 0, 0),
    RGB::new(95, 0, 95),
    RGB::new(95, 0, 135),
    RGB::new(95, 0, 175),
    RGB::new(95, 0, 215),
    RGB::new(95, 0, 255),
    RGB::new(95, 95, 0),
    RGB::new(95, 95, 95),
    RGB::new(95, 95, 135),
    RGB::new(95, 95, 175),
    RGB::new(95, 95, 215),
    RGB::new(95, 95, 255),
    RGB::new(95, 135, 0),
    RGB::new(95, 135, 95),
    RGB::new(95, 135, 135),
    RGB::new(95, 135, 175),
    RGB::new(95, 135, 215),
    RGB::new(95, 135, 255),
    RGB::new(95, 175, 0),
    RGB::new(95, 175, 95),
    RGB::new(95, 175, 135),
    RGB::new(95, 175, 175),
    RGB::new(95, 175, 215),
    RGB::new(95, 175, 255),
    RGB::new(95, 215, 0),
    RGB::new(95, 215, 95),
    RGB::new(95, 215, 135),
    RGB::new(95, 215, 175),
    RGB::new(95, 215, 215),
    RGB::new(95, 215, 255),
    RGB::new(95, 255, 0),
    RGB::new(95, 255, 95),
    RGB::new(95, 255, 135),
    RGB::new(95, 255, 175),
    RGB::new(95, 255, 215),
    RGB::new(95, 255, 255),
    RGB::new(135, 0, 0),
    RGB::new(135, 0, 95),
    RGB::new(135, 0, 135),
    RGB::new(135, 0, 175),
    RGB::new(135, 0, 215),
    RGB::new(135, 0, 255),
    RGB::new(135, 95, 0),
    RGB::new(135, 95, 95),
    RGB::new(135, 95, 135),
    RGB::new(135, 95, 175),
    RGB::new(135, 95, 215),
    RGB::new(135, 95, 255),
    RGB::new(135, 135, 0),
    RGB::new(135, 135, 95),
    RGB::new(135, 135, 135),
    RGB::new(135, 135, 175),
    RGB::new(135, 135, 215),
    RGB::new(135, 135, 255),
    RGB::new(135, 175, 0),
    RGB::new(135, 175, 95),
    RGB::new(135, 175, 135),
    RGB::new(135, 175, 175),
    RGB::new(135, 175, 215),
    RGB::new(135, 175, 255),
    RGB::new(135, 215, 0),
    RGB::new(135, 215, 95),
    RGB::new(135, 215, 135),
    RGB::new(135, 215, 175),
    RGB::new(135, 215, 215),
    RGB::new(135, 215, 255),
    RGB::new(135, 255, 0),
    RGB::new(135, 255, 95),
    RGB::new(135, 255, 135),
    RGB::new(135, 255, 175),
    RGB::new(135, 255, 215),
    RGB::new(135, 255, 255),
    RGB::new(175, 0, 0),
    RGB::new(175, 0, 95),
    RGB::new(175, 0, 135),
    RGB::new(175, 0, 175),
    RGB::new(175, 0, 215),
    RGB::new(175, 0, 255),
    RGB::new(175, 95, 0),
    RGB::new(175, 95, 95),
    RGB::new(175, 95, 135),
    RGB::new(175, 95, 175),
    RGB::new(175, 95, 215),
    RGB::new(175, 95, 255),
    RGB::new(175, 135, 0),
    RGB::new(175, 135, 95),
    RGB::new(175, 135, 135),
    RGB::new(175, 135, 175),
    RGB::new(175, 135, 215),
    RGB::new(175, 135, 255),
    RGB::new(175, 175, 0),
    RGB::new(175, 175, 95),
    RGB::new(175, 175, 135),
    RGB::new(175, 175, 175),
    RGB::new(175, 175, 215),
    RGB::new(175, 175, 255),
    RGB::new(175, 215, 0),
    RGB::new(175, 215, 95),
    RGB::new(175, 215, 135),
    RGB::new(175, 215, 175),
    RGB::new(175, 215, 215),
    RGB::new(175, 215, 255),
    RGB::new(175, 255, 0),
    RGB::new(175, 255, 95),
    RGB::new(175, 255, 135),
    RGB::new(175, 255, 175),
    RGB::new(175, 255, 215),
    RGB::new(175, 255, 255),
    RGB::new(215, 0, 0),
    RGB::new(215, 0, 95),
    RGB::new(215, 0, 135),
    RGB::new(215, 0, 175),
    RGB::new(215, 0, 215),
    RGB::new(215, 0, 255),
    RGB::new(215, 95, 0),
    RGB::new(215, 95, 95),
    RGB::new(215, 95, 135),
    RGB::new(215, 95, 175),
    RGB::new(215, 95, 215),
    RGB::new(215, 95, 255),
    RGB::new(215, 135, 0),
    RGB::new(215, 135, 95),
    RGB::new(215, 135, 135),
    RGB::new(215, 135, 175),
    RGB::new(215, 135, 215),
    RGB::new(215, 135, 255),
    RGB::new(215, 175, 0),
    RGB::new(215, 175, 95),
    RGB::new(215, 175, 135),
    RGB::new(215, 175, 175),
    RGB::new(215, 175, 215),
    RGB::new(215, 175, 255),
    RGB::new(215, 215, 0),
    RGB::new(215, 215, 95),
    RGB::new(215, 215, 135),
    RGB::new(215, 215, 175),
    RGB::new(215, 215, 215),
    RGB::new(215, 215, 255),
    RGB::new(215, 255, 0),
    RGB::new(215, 255, 95),
    RGB::new(215, 255, 135),
    RGB::new(215, 255, 175),
    RGB::new(215, 255, 215),
    RGB::new(215, 255, 255),
    RGB::new(255, 0, 0),
    RGB::new(255, 0, 95),
    RGB::new(255, 0, 135),
    RGB::new(255, 0, 175),
    RGB::new(255, 0, 215),
    RGB::new(255, 0, 255),
    RGB::new(255, 95, 0),
    RGB::new(255, 95, 95),
    RGB::new(255, 95, 135),
    RGB::new(255, 95, 175),
    RGB::new(255, 95, 215),
    RGB::new(255, 95, 255),
    RGB::new(255, 135, 0),
    RGB::new(255, 135, 95),
    RGB::new(255, 135, 135),
    RGB::new(255, 135, 175),
    RGB::new(255, 135, 215),
    RGB::new(255, 135, 255),
    RGB::new(255, 175, 0),
    RGB::new(255, 175, 95),
    RGB::new(255, 175, 135),
    RGB::new(255, 175, 175),
    RGB::new(255, 175, 215),
    RGB::new(255, 175, 255),
    RGB::new(255, 215, 0),
    RGB::new(255, 215, 95),
    RGB::new(255, 215, 135),
    RGB::new(255, 215, 175),
    RGB::new(255, 215, 215),
    RGB::new(255, 215, 255),
    RGB::new(255, 255, 0),
    RGB::new(255, 255, 95),
    RGB::new(255, 255, 135),
    RGB::new(255, 255, 175),
    RGB::new(255, 255, 215),
    RGB::new(255, 255, 255),
    RGB::new(8, 8, 8),
    RGB::new(18, 18, 18),
    RGB::new(28, 28, 28),
    RGB::new(38, 38, 38),
    RGB::new(48, 48, 48),
    RGB::new(58, 58, 58),
    RGB::new(68, 68, 68),
    RGB::new(78, 78, 78),
    RGB::new(88, 88, 88),
    RGB::new(98, 98, 98),
    RGB::new(108, 108, 108),
    RGB::new(118, 118, 118),
    RGB::new(128, 128, 128),
    RGB::new(138, 138, 138),
    RGB::new(148, 148, 148),
    RGB::new(158, 158, 158),
    RGB::new(168, 168, 168),
    RGB::new(178, 178, 178),
    RGB::new(188, 188, 188),
    RGB::new(198, 198, 198),
    RGB::new(208, 208, 208),
    RGB::new(218, 218, 218),
    RGB::new(228, 228, 228),
    RGB::new(238, 238, 238),
  ]
}

///|
pub fn default_palette() -> Array[RGB] {
  default_palette_value()
}

///|
struct DynamicRGB {
  mut override_ : RGB?
  default_ : RGB?
} derive(Eq, Debug)

///|
pub fn DynamicRGB::unset() -> DynamicRGB {
  { override_: None, default_: None }
}

///|
pub fn DynamicRGB::init(default_color : RGB) -> DynamicRGB {
  { override_: None, default_: Some(default_color) }
}

///|
pub fn DynamicRGB::get(self : DynamicRGB) -> RGB? {
  match self.override_ {
    Some(color) => Some(color)
    None => self.default_
  }
}

///|
pub fn DynamicRGB::set(self : DynamicRGB, color : RGB) -> Unit {
  self.override_ = Some(color)
}

///|
pub fn DynamicRGB::reset(self : DynamicRGB) -> Unit {
  self.override_ = self.default_
}

///|
struct DynamicPalette {
  mut current : Array[RGB]
  mut original : Array[RGB]
  mut mask : Array[Bool]
} derive(Eq, Debug)

///|
pub fn DynamicPalette::new() -> DynamicPalette {
  dynamic_palette_init(default_palette_value())
}

///|
pub fn DynamicPalette::color(self : DynamicPalette, idx : Byte) -> RGB {
  self.current[idx.to_int()]
}

///|
pub fn DynamicPalette::set(
  self : DynamicPalette,
  idx : Byte,
  color : RGB,
) -> Unit {
  let index = idx.to_int()
  self.current[index] = color
  self.mask[index] = true
}

///|
pub fn DynamicPalette::reset(self : DynamicPalette, idx : Byte) -> Unit {
  let index = idx.to_int()
  self.current[index] = self.original[index]
  self.mask[index] = false
}

///|
pub fn DynamicPalette::reset_all(self : DynamicPalette) -> Unit {
  self.current = self.original
  self.mask = empty_palette_mask()
}

///|
pub fn DynamicPalette::change_default(
  self : DynamicPalette,
  defaults : Array[RGB],
) -> Unit {
  let defaults_copy = clone_palette(defaults)
  self.original = defaults_copy
  if palette_mask_is_empty(self.mask) {
    self.current = clone_palette(defaults_copy)
    return
  }

  let current = clone_palette(defaults_copy)
  let mut i = 0
  while i < PaletteLengthInt {
    if self.mask[i] {
      current[i] = self.current[i]
    }
    i += 1
  }
  self.current = current
}

///|
struct TerminalColors {
  background : DynamicRGB
  foreground : DynamicRGB
  cursor : DynamicRGB
  palette : DynamicPalette
} derive(Eq, Debug)

///|
pub fn TerminalColors::new() -> TerminalColors {
  {
    background: DynamicRGB::unset(),
    foreground: DynamicRGB::unset(),
    cursor: DynamicRGB::unset(),
    palette: DynamicPalette::new(),
  }
}

///|
pub fn TerminalColors::background(self : TerminalColors) -> RGB? {
  self.background.get()
}

///|
pub fn TerminalColors::foreground(self : TerminalColors) -> RGB? {
  self.foreground.get()
}

///|
pub fn TerminalColors::cursor(self : TerminalColors) -> RGB? {
  self.cursor.get()
}

///|
pub fn TerminalColors::palette_color(self : TerminalColors, idx : Byte) -> RGB {
  self.palette.color(idx)
}

///|
pub fn TerminalColors::set_background(
  self : TerminalColors,
  color : RGB,
) -> Unit {
  self.background.set(color)
}

///|
pub fn TerminalColors::set_foreground(
  self : TerminalColors,
  color : RGB,
) -> Unit {
  self.foreground.set(color)
}

///|
pub fn TerminalColors::set_cursor(self : TerminalColors, color : RGB) -> Unit {
  self.cursor.set(color)
}

///|
pub fn TerminalColors::reset_background(self : TerminalColors) -> Unit {
  self.background.reset()
}

///|
pub fn TerminalColors::reset_foreground(self : TerminalColors) -> Unit {
  self.foreground.reset()
}

///|
pub fn TerminalColors::reset_cursor(self : TerminalColors) -> Unit {
  self.cursor.reset()
}

///|
pub fn TerminalColors::set_palette_color(
  self : TerminalColors,
  idx : Byte,
  color : RGB,
) -> Unit {
  self.palette.set(idx, color)
}

///|
pub fn TerminalColors::reset_palette_color(
  self : TerminalColors,
  idx : Byte,
) -> Unit {
  self.palette.reset(idx)
}

///|
pub fn TerminalColors::reset_palette(self : TerminalColors) -> Unit {
  self.palette.reset_all()
}

///|
pub fn TerminalColors::change_default_palette(
  self : TerminalColors,
  defaults : Array[RGB],
) -> Unit {
  self.palette.change_default(defaults)
}

///|
fn dynamic_palette_init(defaults : Array[RGB]) -> DynamicPalette {
  {
    current: clone_palette(defaults),
    original: clone_palette(defaults),
    mask: empty_palette_mask(),
  }
}

///|
fn empty_palette_mask() -> Array[Bool] {
  let result : Array[Bool] = []
  for _ in 0..<PaletteLengthInt {
    result.push(false)
  }
  result
}

///|
fn palette_mask_is_empty(mask : Array[Bool]) -> Bool {
  let mut i = 0
  while i < mask.length() {
    if mask[i] {
      return false
    }
    i += 1
  }
  true
}

///|
fn clone_palette(source : Array[RGB]) -> Array[RGB] {
  let result : Array[RGB] = []
  for color in source {
    result.push(color)
  }
  result
}

///|
pub fn RGB::parse(value : String) -> RGB raise ColorParseError {
  if value.length() == 0 {
    raise ColorParseError::InvalidFormat
  }

  if value[0] == '#' {
    parse_hash_rgb(value)
  } else {
    match x11_color_lookup(value) {
      Some(rgb) => rgb
      None => parse_rgb_spec(value)
    }
  }
}

///|
fn parse_hash_rgb(value : String) -> RGB raise ColorParseError {
  match value.length() {
    4 =>
      {
        r: parse_hex_component(value, 1, 2),
        g: parse_hex_component(value, 2, 3),
        b: parse_hex_component(value, 3, 4),
      }
    7 =>
      {
        r: parse_hex_component(value, 1, 3),
        g: parse_hex_component(value, 3, 5),
        b: parse_hex_component(value, 5, 7),
      }
    10 =>
      {
        r: parse_hex_component(value, 1, 4),
        g: parse_hex_component(value, 4, 7),
        b: parse_hex_component(value, 7, 10),
      }
    13 =>
      {
        r: parse_hex_component(value, 1, 5),
        g: parse_hex_component(value, 5, 9),
        b: parse_hex_component(value, 9, 13),
      }
    _ => raise ColorParseError::InvalidFormat
  }
}

///|
fn parse_rgb_spec(value : String) -> RGB raise ColorParseError {
  if value.length() < 6 {
    raise ColorParseError::InvalidFormat
  }
  guard value[0] == 'r' && value[1] == 'g' && value[2] == 'b' else {
    raise ColorParseError::InvalidFormat
  }

  let mut index = 3
  let use_intensity = if index < value.length() && value[index] == 'i' {
    index += 1
    true
  } else {
    false
  }

  guard index < value.length() && value[index] == ':' else {
    raise ColorParseError::InvalidFormat
  }
  index += 1

  let slash1 = find_char(value, index, '/')
  let slash2 = match slash1 {
    Some(pos) => find_char(value, pos + 1, '/')
    None => None
  }
  guard slash1 is Some(first) && slash2 is Some(second) else {
    raise ColorParseError::InvalidFormat
  }
  guard find_char(value, second + 1, '/') == None else {
    raise ColorParseError::InvalidFormat
  }

  if use_intensity {
    {
      r: parse_intensity_component(value, index, first),
      g: parse_intensity_component(value, first + 1, second),
      b: parse_intensity_component(value, second + 1, value.length()),
    }
  } else {
    {
      r: parse_hex_component(value, index, first),
      g: parse_hex_component(value, first + 1, second),
      b: parse_hex_component(value, second + 1, value.length()),
    }
  }
}

///|
fn parse_hex_component(
  value : String,
  start : Int,
  end_ : Int,
) -> Byte raise ColorParseError {
  let width = end_ - start
  guard width >= 1 && width <= 4 else { raise ColorParseError::InvalidFormat }

  let mut result = 0
  let mut i = start
  while i < end_ {
    let digit = match hex_digit(value[i]) {
      Some(d) => d
      None => raise ColorParseError::InvalidFormat
    }
    result = result * 16 + digit
    i += 1
  }

  let divisor = if width == 1 {
    0xF
  } else if width == 2 {
    0xFF
  } else if width == 3 {
    0xFFF
  } else {
    0xFFFF
  }

  (result * 0xFF / divisor).to_byte()
}

///|
fn parse_intensity_component(
  value : String,
  start : Int,
  end_ : Int,
) -> Byte raise ColorParseError {
  guard start < end_ else { raise ColorParseError::InvalidFormat }

  let mut i = start
  let mut saw_digit = false
  let mut saw_dot = false
  let mut integer = 0
  let mut fraction = 0
  let mut fraction_digits = 0

  while i < end_ {
    let char = value[i]
    if char >= '0' && char <= '9' {
      saw_digit = true
      let digit = char.to_int() - '0'.to_int()
      if saw_dot {
        fraction = fraction * 10 + digit
        fraction_digits += 1
      } else {
        integer = integer * 10 + digit
      }
    } else if char == '.' && !saw_dot {
      saw_dot = true
    } else {
      raise ColorParseError::InvalidFormat
    }
    i += 1
  }

  guard saw_digit else { raise ColorParseError::InvalidFormat }

  let mut denominator = 1
  for _ in 0..<fraction_digits {
    denominator = denominator * 10
  }
  let numerator = integer * denominator + fraction
  guard numerator <= denominator else { raise ColorParseError::InvalidFormat }

  (numerator * 0xFF / denominator).to_byte()
}

///|
fn find_char(value : String, start : Int, target : UInt16) -> Int? {
  let mut i = start
  while i < value.length() {
    if value[i] == target {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn hex_digit(value : UInt16) -> Int? {
  if value >= '0' && value <= '9' {
    Some(value.to_int() - '0'.to_int())
  } else if value >= 'a' && value <= 'f' {
    Some(value.to_int() - 'a'.to_int() + 10)
  } else if value >= 'A' && value <= 'F' {
    Some(value.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}
