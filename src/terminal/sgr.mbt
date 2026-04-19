///|
pub(all) enum SgrUnderline {
  None
  Single
  Double
  Curly
  Dotted
  Dashed
} derive(Eq, Debug)

///|
pub(all) struct SgrUnknown {
  full : Array[UInt16]
  partial : Array[UInt16]
} derive(Eq, Debug)

///|
pub(all) enum SgrAttribute {
  Unset
  Unknown(SgrUnknown)
  Bold
  ResetBold
  Italic
  ResetItalic
  Faint
  Underline(SgrUnderline)
  UnderlineColor(RGB)
  Color256Underline(Byte)
  ResetUnderlineColor
  Overline
  ResetOverline
  Blink
  ResetBlink
  Inverse
  ResetInverse
  Invisible
  ResetInvisible
  Strikethrough
  ResetStrikethrough
  DirectColorFg(RGB)
  DirectColorBg(RGB)
  Color8Bg(Name)
  Color8Fg(Name)
  ResetFg
  ResetBg
  BrightColor8Bg(Name)
  BrightColor8Fg(Name)
  Color256Bg(Byte)
  Color256Fg(Byte)
} derive(Eq, Debug)

///|
priv struct SgrParser {
  params : Array[UInt16]
  params_sep : SepList
  mut idx : Int
} derive(Debug)

///|
fn SgrParser::empty() -> SgrParser {
  { params: [], params_sep: SepList::init_empty(), idx: 0 }
}

///|
fn SgrParser::next(self : SgrParser) -> SgrAttribute? {
  let current = self.idx
  if current >= self.params.length() {
    if current == 0 {
      self.idx += 1
      return Some(Unset)
    }
    return None
  }

  let colon = self.params_sep.is_set(current)
  self.idx += 1

  if colon {
    match self.params[current] {
      4 | 38 | 48 | 58 => ()
      _ => {
        while self.idx < self.params.length() &&
              self.params_sep.is_set(self.idx) {
          self.idx += 1
        }
        self.idx += 1
        let consumed_end = if self.idx < self.params.length() {
          self.idx
        } else {
          self.params.length()
        }
        return Some(
          Unknown({
            full: clone_params(self.params),
            partial: clone_param_range(self.params, current, consumed_end),
          }),
        )
      }
    }
  }

  match self.params[current] {
    0 => Some(Unset)
    1 => Some(Bold)
    2 => Some(Faint)
    3 => Some(Italic)
    4 =>
      if colon {
        if remaining_len(self, current) < 2 {
          Some(self.unknown_from(current))
        } else if self.is_colon() {
          self.consume_unknown_colon()
          Some(self.unknown_from(current))
        } else {
          self.idx += 1
          Some(
            Underline(
              match self.params[current + 1] {
                0 => SgrUnderline::None
                1 => SgrUnderline::Single
                2 => SgrUnderline::Double
                3 => SgrUnderline::Curly
                4 => SgrUnderline::Dotted
                5 => SgrUnderline::Dashed
                _ => SgrUnderline::Single
              },
            ),
          )
        }
      } else {
        Some(Underline(SgrUnderline::Single))
      }
    5 | 6 => Some(Blink)
    7 => Some(Inverse)
    8 => Some(Invisible)
    9 => Some(Strikethrough)
    21 => Some(Underline(SgrUnderline::Double))
    22 => Some(ResetBold)
    23 => Some(ResetItalic)
    24 => Some(Underline(SgrUnderline::None))
    25 => Some(ResetBlink)
    27 => Some(ResetInverse)
    28 => Some(ResetInvisible)
    29 => Some(ResetStrikethrough)
    value if value >= 30 && value <= 37 =>
      Some(Color8Fg(name_from_code((value - 30).to_byte())))
    38 => parse_color_selector(self, current, colon, true)
    39 => Some(ResetFg)
    value if value >= 40 && value <= 47 =>
      Some(Color8Bg(name_from_code((value - 40).to_byte())))
    48 => parse_color_selector(self, current, colon, false)
    49 => Some(ResetBg)
    53 => Some(Overline)
    55 => Some(ResetOverline)
    58 => parse_underline_color_selector(self, current, colon)
    59 => Some(ResetUnderlineColor)
    value if value >= 90 && value <= 97 =>
      Some(BrightColor8Fg(name_from_code((value - 82).to_byte())))
    value if value >= 100 && value <= 107 =>
      Some(BrightColor8Bg(name_from_code((value - 92).to_byte())))
    _ => Some(self.unknown_from(current))
  }
}

///|
fn parse_color_selector(
  parser : SgrParser,
  current : Int,
  colon : Bool,
  foreground : Bool,
) -> SgrAttribute? {
  if remaining_len(parser, current) < 2 {
    return Some(parser.unknown_from(current))
  }

  match parser.params[current + 1] {
    2 =>
      match parser.parse_direct_color(current, colon) {
        Some(rgb) =>
          if foreground {
            Some(DirectColorFg(rgb))
          } else {
            Some(DirectColorBg(rgb))
          }
        None => Some(parser.unknown_from(current))
      }
    5 =>
      if remaining_len(parser, current) >= 3 {
        parser.idx += 2
        let value = parser.params[current + 2].to_byte()
        if foreground {
          Some(Color256Fg(value))
        } else {
          Some(Color256Bg(value))
        }
      } else {
        Some(parser.unknown_from(current))
      }
    _ => Some(parser.unknown_from(current))
  }
}

///|
fn parse_underline_color_selector(
  parser : SgrParser,
  current : Int,
  colon : Bool,
) -> SgrAttribute? {
  if remaining_len(parser, current) < 2 {
    return Some(parser.unknown_from(current))
  }

  match parser.params[current + 1] {
    2 =>
      match parser.parse_direct_color(current, colon) {
        Some(rgb) => Some(UnderlineColor(rgb))
        None => Some(parser.unknown_from(current))
      }
    5 =>
      if remaining_len(parser, current) >= 3 {
        parser.idx += 2
        Some(Color256Underline(parser.params[current + 2].to_byte()))
      } else {
        Some(parser.unknown_from(current))
      }
    _ => Some(parser.unknown_from(current))
  }
}

///|
fn SgrParser::parse_direct_color(
  self : SgrParser,
  current : Int,
  colon : Bool,
) -> RGB? {
  if remaining_len(self, current) < 5 {
    return None
  }

  if !colon {
    self.idx += 4
    return Some({
      r: self.params[current + 2].to_byte(),
      g: self.params[current + 3].to_byte(),
      b: self.params[current + 4].to_byte(),
    })
  }

  match self.count_colon() {
    3 => {
      self.idx += 4
      Some({
        r: self.params[current + 2].to_byte(),
        g: self.params[current + 3].to_byte(),
        b: self.params[current + 4].to_byte(),
      })
    }
    4 =>
      if remaining_len(self, current) < 6 {
        self.consume_unknown_colon()
        None
      } else {
        self.idx += 5
        Some({
          r: self.params[current + 3].to_byte(),
          g: self.params[current + 4].to_byte(),
          b: self.params[current + 5].to_byte(),
        })
      }
    _ => {
      self.consume_unknown_colon()
      None
    }
  }
}

///|
fn SgrParser::is_colon(self : SgrParser) -> Bool {
  self.idx < self.params.length() && self.params_sep.is_set(self.idx)
}

///|
fn SgrParser::count_colon(self : SgrParser) -> Int {
  let mut count = 0
  let mut index = self.idx
  while index < self.params.length() - 1 && self.params_sep.is_set(index) {
    count += 1
    index += 1
  }
  count
}

///|
fn SgrParser::consume_unknown_colon(self : SgrParser) -> Unit {
  self.idx += self.count_colon() + 1
}

///|
fn SgrParser::unknown_from(self : SgrParser, current : Int) -> SgrAttribute {
  Unknown({
    full: clone_params(self.params),
    partial: clone_param_range(self.params, current, self.params.length()),
  })
}

///|
fn clone_param_range(
  source : Array[UInt16],
  start : Int,
  end_ : Int,
) -> Array[UInt16] {
  let result : Array[UInt16] = []
  for index in start..<end_ {
    result.push(source[index])
  }
  result
}

///|
fn remaining_len(parser : SgrParser, current : Int) -> Int {
  parser.params.length() - current
}

///|
fn name_from_code(code : Byte) -> Name {
  match code {
    0 => Name::Black
    1 => Name::Red
    2 => Name::Green
    3 => Name::Yellow
    4 => Name::Blue
    5 => Name::Magenta
    6 => Name::Cyan
    7 => Name::White
    8 => Name::BrightBlack
    9 => Name::BrightRed
    10 => Name::BrightGreen
    11 => Name::BrightYellow
    12 => Name::BrightBlue
    13 => Name::BrightMagenta
    14 => Name::BrightCyan
    _ => Name::BrightWhite
  }
}
