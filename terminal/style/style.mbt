///|
/// A color carried by a cell style, tagged by source. `#valtype` keeps it
/// unboxed: it stores inline in `CellStyle` (no per-color heap box) while
/// staying a normal enum, so callers can still pattern-match
/// `None`/`Palette`/`Rgb`. All payloads are scalar (`Byte`, and `RGB` is a
/// transparent `UInt` newtype), which `#valtype` enums require.
#valtype
enum StyleColor {
  None
  Palette(Byte)
  Rgb(@color.RGB)
} derive(Eq, Debug)

///|
pub fn StyleColor::none() -> StyleColor {
  None
}

///|
pub fn StyleColor::palette(index : Byte) -> StyleColor {
  Palette(index)
}

///|
pub fn StyleColor::rgb(value : @color.RGB) -> StyleColor {
  Rgb(value)
}

///|
pub fn StyleColor::is_default(self : StyleColor) -> Bool {
  self is None
}

///|
pub fn StyleColor::palette_index(self : StyleColor) -> Byte? {
  match self {
    Palette(value) => Some(value)
    None | Rgb(_) => None
  }
}

///|
pub fn StyleColor::rgb_value(self : StyleColor) -> @color.RGB? {
  match self {
    Rgb(value) => Some(value)
    None | Palette(_) => None
  }
}

///|
/// Resolve to a concrete RGB against `palette`: `None` -> None,
/// `Palette(i)` -> `palette[i]`, `Rgb(c)` -> `c`. This is the only decoder of a
/// `StyleColor`, so its representation stays internal to this package.
pub fn StyleColor::resolve(
  self : StyleColor,
  palette : Array[@color.RGB],
) -> @color.RGB? {
  match self {
    None => None
    Palette(index) => Some(palette[index.to_int()])
    Rgb(value) => Some(value)
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
  mut underline : @sgr.SgrUnderline
} derive(Eq, Debug)

///|
pub fn CellStyle::new() -> CellStyle {
  {
    fg_color: StyleColor::none(),
    bg_color: StyleColor::none(),
    underline_color: StyleColor::none(),
    bold: false,
    italic: false,
    faint: false,
    blink: false,
    inverse: false,
    invisible: false,
    strikethrough: false,
    overline: false,
    underline: None,
  }
}

///|
pub fn CellStyle::reset(self : CellStyle) -> Unit {
  self.fg_color = StyleColor::none()
  self.bg_color = StyleColor::none()
  self.underline_color = StyleColor::none()
  self.bold = false
  self.italic = false
  self.faint = false
  self.blink = false
  self.inverse = false
  self.invisible = false
  self.strikethrough = false
  self.overline = false
  self.underline = None
}

///|
pub fn CellStyle::is_default(self : CellStyle) -> Bool {
  self.fg_color is None &&
  self.bg_color is None &&
  self.underline_color is None &&
  !self.bold &&
  !self.italic &&
  !self.faint &&
  !self.blink &&
  !self.inverse &&
  !self.invisible &&
  !self.strikethrough &&
  !self.overline &&
  self.underline is None
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
pub fn CellStyle::underline(self : CellStyle) -> @sgr.SgrUnderline {
  self.underline
}

///|
/// A deep copy of this style. Callers in other packages can't reconstruct a
/// `CellStyle` field-by-field (the fields are private), so this is the one way
/// to snapshot a style.
pub fn CellStyle::clone(self : CellStyle) -> CellStyle {
  {
    fg_color: self.fg_color,
    bg_color: self.bg_color,
    underline_color: self.underline_color,
    bold: self.bold,
    italic: self.italic,
    faint: self.faint,
    blink: self.blink,
    inverse: self.inverse,
    invisible: self.invisible,
    strikethrough: self.strikethrough,
    overline: self.overline,
    underline: self.underline,
  }
}

///|
pub fn CellStyle::set_fg_color(self : CellStyle, color : StyleColor) -> Unit {
  self.fg_color = color
}

///|
pub fn CellStyle::set_bg_color(self : CellStyle, color : StyleColor) -> Unit {
  self.bg_color = color
}

///|
/// Resolve the foreground color to a concrete RGB against `palette`, or `None`
/// for the default (terminal-chosen) foreground.
pub fn CellStyle::fg_rgb(
  self : CellStyle,
  palette : Array[@color.RGB],
) -> @color.RGB? {
  self.fg_color.resolve(palette)
}

///|
/// Resolve the style's own background color to a concrete RGB. Note this does
/// not account for a color-only cell whose background lives in the cell
/// content — that precedence is handled at the render layer.
pub fn CellStyle::bg_color_rgb(
  self : CellStyle,
  palette : Array[@color.RGB],
) -> @color.RGB? {
  self.bg_color.resolve(palette)
}

///|
pub fn CellStyle::apply_attribute(
  self : CellStyle,
  attr : @sgr.SgrAttribute,
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
    UnderlineColor(rgb) => self.underline_color = StyleColor::rgb(rgb)
    Color256Underline(index) =>
      self.underline_color = StyleColor::palette(index)
    ResetUnderlineColor => self.underline_color = StyleColor::none()
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
    DirectColorFg(rgb) => self.fg_color = StyleColor::rgb(rgb)
    DirectColorBg(rgb) => self.bg_color = StyleColor::rgb(rgb)
    Color8Bg(name) => self.bg_color = StyleColor::palette(name.code())
    Color8Fg(name) => self.fg_color = StyleColor::palette(name.code())
    ResetFg => self.fg_color = StyleColor::none()
    ResetBg => self.bg_color = StyleColor::none()
    BrightColor8Bg(name) => self.bg_color = StyleColor::palette(name.code())
    BrightColor8Fg(name) => self.fg_color = StyleColor::palette(name.code())
    Color256Bg(index) => self.bg_color = StyleColor::palette(index)
    Color256Fg(index) => self.fg_color = StyleColor::palette(index)
  }
}
