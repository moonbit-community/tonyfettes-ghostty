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
