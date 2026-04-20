///|
enum StyleColor {
  None
  Palette(Byte)
  Rgb(RGB)
} derive(Eq, Debug)

///|
fn style_color_none() -> StyleColor {
  None
}

///|
fn style_color_palette(index : Byte) -> StyleColor {
  Palette(index)
}

///|
fn style_color_rgb(rgb : RGB) -> StyleColor {
  Rgb(rgb)
}

///|
pub fn StyleColor::is_default(self : StyleColor) -> Bool {
  self == None
}

///|
pub fn StyleColor::palette_index(self : StyleColor) -> Byte? {
  match self {
    Palette(value) => Some(value)
    None | Rgb(_) => None
  }
}

///|
pub fn StyleColor::rgb_value(self : StyleColor) -> RGB? {
  match self {
    Rgb(value) => Some(value)
    None | Palette(_) => None
  }
}

///|
struct CellStyle {
  mut fg_color : StyleColor
  mut bg_color : StyleColor
  mut underline_color : StyleColor
  mut bold : Bool
  mut italic : Bool
  mut faint : Bool
  mut blink : Bool
  mut inverse : Bool
  mut invisible : Bool
  mut strikethrough : Bool
  mut overline : Bool
  mut underline : SgrUnderline
} derive(Eq, Debug)

///|
pub fn CellStyle::new() -> CellStyle {
  {
    fg_color: style_color_none(),
    bg_color: style_color_none(),
    underline_color: style_color_none(),
    bold: false,
    italic: false,
    faint: false,
    blink: false,
    inverse: false,
    invisible: false,
    strikethrough: false,
    overline: false,
    underline: SgrUnderline::None,
  }
}

///|
pub fn CellStyle::reset(self : CellStyle) -> Unit {
  self.fg_color = style_color_none()
  self.bg_color = style_color_none()
  self.underline_color = style_color_none()
  self.bold = false
  self.italic = false
  self.faint = false
  self.blink = false
  self.inverse = false
  self.invisible = false
  self.strikethrough = false
  self.overline = false
  self.underline = SgrUnderline::None
}

///|
pub fn CellStyle::is_default(self : CellStyle) -> Bool {
  self == CellStyle::new()
}

///|
pub fn CellStyle::fg_color(self : CellStyle) -> StyleColor {
  self.fg_color
}

///|
pub fn CellStyle::bg_color(self : CellStyle) -> StyleColor {
  self.bg_color
}

///|
pub fn CellStyle::underline_color(self : CellStyle) -> StyleColor {
  self.underline_color
}

///|
pub fn CellStyle::bold(self : CellStyle) -> Bool {
  self.bold
}

///|
pub fn CellStyle::italic(self : CellStyle) -> Bool {
  self.italic
}

///|
pub fn CellStyle::faint(self : CellStyle) -> Bool {
  self.faint
}

///|
pub fn CellStyle::blink(self : CellStyle) -> Bool {
  self.blink
}

///|
pub fn CellStyle::inverse(self : CellStyle) -> Bool {
  self.inverse
}

///|
pub fn CellStyle::invisible(self : CellStyle) -> Bool {
  self.invisible
}

///|
pub fn CellStyle::strikethrough(self : CellStyle) -> Bool {
  self.strikethrough
}

///|
pub fn CellStyle::overline(self : CellStyle) -> Bool {
  self.overline
}

///|
pub fn CellStyle::underline(self : CellStyle) -> SgrUnderline {
  self.underline
}

///|
pub fn CellStyle::apply_attribute(
  self : CellStyle,
  attr : SgrAttribute,
) -> Unit {
  match attr {
    Unset => self.reset()
    Unknown(_) => ()
    Bold => self.bold = true
    ResetBold => {
      self.bold = false
      self.faint = false
    }
    Italic => self.italic = true
    ResetItalic => self.italic = false
    Faint => self.faint = true
    Underline(value) => self.underline = value
    UnderlineColor(rgb) => self.underline_color = style_color_rgb(rgb)
    Color256Underline(index) =>
      self.underline_color = style_color_palette(index)
    ResetUnderlineColor => self.underline_color = style_color_none()
    Overline => self.overline = true
    ResetOverline => self.overline = false
    Blink => self.blink = true
    ResetBlink => self.blink = false
    Inverse => self.inverse = true
    ResetInverse => self.inverse = false
    Invisible => self.invisible = true
    ResetInvisible => self.invisible = false
    Strikethrough => self.strikethrough = true
    ResetStrikethrough => self.strikethrough = false
    DirectColorFg(rgb) => self.fg_color = style_color_rgb(rgb)
    DirectColorBg(rgb) => self.bg_color = style_color_rgb(rgb)
    Color8Bg(name) => self.bg_color = style_color_palette(name.code())
    Color8Fg(name) => self.fg_color = style_color_palette(name.code())
    ResetFg => self.fg_color = style_color_none()
    ResetBg => self.bg_color = style_color_none()
    BrightColor8Bg(name) => self.bg_color = style_color_palette(name.code())
    BrightColor8Fg(name) => self.fg_color = style_color_palette(name.code())
    Color256Bg(index) => self.bg_color = style_color_palette(index)
    Color256Fg(index) => self.fg_color = style_color_palette(index)
  }
}
