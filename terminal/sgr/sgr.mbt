///|
const SgrSeparatorCapacity : Int = 64

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
/// Carries the parameters of an unrecognized SGR attribute out to the stream
/// handler. Unlike the internal parser payloads, an `SgrUnknown` crosses the
/// public `StreamHandler` boundary and may be stored by the consumer (e.g. a
/// handler that batches actions), so it owns `full` (a copy of the params) with
/// `partial` a slice of that copy — it never aliases the parser's reused buffer.
pub(all) struct SgrUnknown {
  full : ReadOnlyArray[UInt16]
  partial : ArrayView[UInt16]
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
  UnderlineColor(@color.RGB)
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
  DirectColorFg(@color.RGB)
  DirectColorBg(@color.RGB)
  Color8Bg(@color.Name)
  Color8Fg(@color.Name)
  ResetFg
  ResetBg
  BrightColor8Bg(@color.Name)
  BrightColor8Fg(@color.Name)
  Color256Bg(Byte)
  Color256Fg(Byte)
} derive(Eq, Debug)

///|
/// Abstract (no `pub`): callers build one via `SgrParser::from_params` / `new`
/// and drive it through `set_params`/`next`/`reset`, so its cursor state stays
/// sealed across the package boundary.
struct SgrParser {
  mut params : ArrayView[UInt16]
  mut params_sep : @parser.SepList
  mut idx : Int
} derive(Debug)

///|
/// Shared empty parameter view for the no-param parser. The backing empty array
/// is immutable in practice (length 0), so handing out the same view is safe.
let empty_sgr_params : ArrayView[UInt16] = ([] : Array[UInt16])

///|
fn SgrParser::empty() -> SgrParser {
  {
    params: empty_sgr_params,
    params_sep: @parser.SepList::init_empty(),
    idx: 0,
  }
}

///|
/// Build a parser over already-collected CSI parameters and their separator
/// set. Boundary factory so callers in other packages do not construct the
/// SgrParser record directly.
/// `params` borrows the caller's CSI parameter buffer (an `ArrayView`); the
/// parser is consumed synchronously within the dispatch window, so it never
/// outlives that buffer. The only attribute that escapes to the handler with
/// param data — the rare `Unknown` — is copied out in `make_unknown`.
pub fn SgrParser::from_params(
  params : ArrayView[UInt16],
  params_sep : @parser.SepList,
) -> SgrParser {
  { params, params_sep, idx: 0 }
}

///|
pub fn SgrParser::new() -> SgrParser {
  SgrParser::empty()
}

///|
pub fn SgrParser::reset(self : SgrParser) -> Unit {
  self.idx = 0
}

///|
pub fn SgrParser::set_params(
  self : SgrParser,
  params : Array[UInt16],
  separators : Array[Byte],
) -> @result_code.TerminalResultCode {
  if params.length() > SgrSeparatorCapacity ||
    separators.length() > SgrSeparatorCapacity {
    return InvalidValue
  }
  if separators.length() != 0 && separators.length() != params.length() {
    return InvalidValue
  }

  // Snapshot the caller's params into an independent buffer; the stored view
  // keeps that copy alive and is decoupled from later caller mutation.
  self.params = params.copy()
  self.params_sep = @parser.SepList::init_empty()
  for index in 0..<separators.length() {
    if separators[index] == b':' {
      self.params_sep = self.params_sep.set(index)
    }
  }
  self.idx = 0
  Success
}

///|
pub fn SgrParser::next(self : SgrParser) -> SgrAttribute? {
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
        return Some(Unknown(self.make_unknown(current, consumed_end)))
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
                0 => None
                1 => Single
                2 => Double
                3 => Curly
                4 => Dotted
                5 => Dashed
                _ => Single
              },
            ),
          )
        }
      } else {
        Some(Underline(Single))
      }
    5 | 6 => Some(Blink)
    7 => Some(Inverse)
    8 => Some(Invisible)
    9 => Some(Strikethrough)
    21 => Some(Underline(Double))
    22 => Some(ResetBold)
    23 => Some(ResetItalic)
    24 => Some(Underline(None))
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
) -> @color.RGB? {
  if remaining_len(self, current) < 5 {
    return None
  }

  if !colon {
    self.idx += 4
    return Some(
      @color.RGB::new(
        self.params[current + 2].to_byte(),
        self.params[current + 3].to_byte(),
        self.params[current + 4].to_byte(),
      ),
    )
  }

  match self.count_colon() {
    3 => {
      self.idx += 4
      Some(
        @color.RGB::new(
          self.params[current + 2].to_byte(),
          self.params[current + 3].to_byte(),
          self.params[current + 4].to_byte(),
        ),
      )
    }
    4 =>
      if remaining_len(self, current) < 6 {
        self.consume_unknown_colon()
        None
      } else {
        self.idx += 5
        Some(
          @color.RGB::new(
            self.params[current + 3].to_byte(),
            self.params[current + 4].to_byte(),
            self.params[current + 5].to_byte(),
          ),
        )
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
  Unknown(self.make_unknown(current, self.params.length()))
}

///|
/// Build an owned `SgrUnknown`. `self.params` borrows the parser's reused
/// buffer, but the `Unknown` attribute escapes to the stream handler (which may
/// store it), so the params are copied into an owned `ReadOnlyArray` with
/// `partial` a slice of that copy. Unknown SGR codes are rare, so this copy is
/// off the hot path (known attributes are returned as borrow-free value types).
fn SgrParser::make_unknown(
  self : SgrParser,
  start : Int,
  end : Int,
) -> SgrUnknown {
  let full = ReadOnlyArray::from_array(self.params.to_owned())
  { full, partial: full[start:end] }
}

///|
fn remaining_len(parser : SgrParser, current : Int) -> Int {
  parser.params.length() - current
}

///|
fn name_from_code(code : Byte) -> @color.Name {
  match code {
    0 => Black
    1 => Red
    2 => Green
    3 => Yellow
    4 => Blue
    5 => Magenta
    6 => Cyan
    7 => White
    8 => BrightBlack
    9 => BrightRed
    10 => BrightGreen
    11 => BrightYellow
    12 => BrightBlue
    13 => BrightMagenta
    14 => BrightCyan
    _ => BrightWhite
  }
}
