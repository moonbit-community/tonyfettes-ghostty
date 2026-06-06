///|
/// A color carried by a cell style, tagged by source. Packed into a single
/// `UInt` (a transparent scalar): bits 24-25 hold the tag (0 none, 1 palette,
/// 2 rgb) and bits 0-23 the value — the palette index in the low byte, or rgb
/// as `r<<16 | g<<8 | b`. `None` encodes to 0, so a default color is just
/// `packed == 0`. Being a scalar (not a `#valtype` enum) lets it sit inline in
/// a `#valtype` `CellStyle`; its representation stays internal to this package,
/// reached only through the constructors and accessors below.
struct StyleColor(UInt) derive(Eq, Debug)

///|
const StyleColorTagShift : Int = 24

///|
const StyleColorPaletteTag : UInt = 1

///|
const StyleColorRgbTag : UInt = 2

///|
pub fn StyleColor::none() -> StyleColor {
  StyleColor(0)
}

///|
pub fn StyleColor::palette(index : Byte) -> StyleColor {
  StyleColor((StyleColorPaletteTag << StyleColorTagShift) | index.to_uint())
}

///|
pub fn StyleColor::rgb(value : @color.RGB) -> StyleColor {
  let bits = (value.r().to_uint() << 16) |
    (value.g().to_uint() << 8) |
    value.b().to_uint()
  StyleColor((StyleColorRgbTag << StyleColorTagShift) | bits)
}

///|
fn StyleColor::tag(self : StyleColor) -> UInt {
  self.0 >> StyleColorTagShift
}

///|
fn StyleColor::decode_rgb(self : StyleColor) -> @color.RGB {
  @color.RGB::new(
    ((self.0 >> 16) & 0xFFU).to_byte(),
    ((self.0 >> 8) & 0xFFU).to_byte(),
    (self.0 & 0xFFU).to_byte(),
  )
}

///|
pub fn StyleColor::is_default(self : StyleColor) -> Bool {
  self.0 == 0
}

///|
pub fn StyleColor::palette_index(self : StyleColor) -> Byte? {
  if self.tag() == StyleColorPaletteTag {
    Some((self.0 & 0xFFU).to_byte())
  } else {
    None
  }
}

///|
pub fn StyleColor::rgb_value(self : StyleColor) -> @color.RGB? {
  if self.tag() == StyleColorRgbTag {
    Some(self.decode_rgb())
  } else {
    None
  }
}

///|
/// Resolve to a concrete RGB against `palette`: none -> None,
/// palette(i) -> `palette[i]`, rgb(c) -> `c`. This and the accessors above are
/// the only decoders of a `StyleColor`, so its representation stays internal.
pub fn StyleColor::resolve(
  self : StyleColor,
  palette : Array[@color.RGB],
) -> @color.RGB? {
  let tag = self.tag()
  if tag == StyleColorPaletteTag {
    Some(palette[(self.0 & 0xFFU).reinterpret_as_int()])
  } else if tag == StyleColorRgbTag {
    Some(self.decode_rgb())
  } else {
    None
  }
}

// On/off attributes plus the underline kind, packed into one `UInt` with the
// same bit layout as upstream Ghostty's `Style.Flags` (`packed struct(u16)`):
// bit 0 bold, 1 italic, 2 faint, 3 blink, 4 inverse, 5 invisible,
// 6 strikethrough, 7 overline, bits 8-10 the underline kind (the
// `SgrUnderline` ordinal, which matches Zig's `Underline` enum order).

///|
const FlagBold : UInt = 0x1

///|
const FlagItalic : UInt = 0x2

///|
const FlagFaint : UInt = 0x4

///|
const FlagBlink : UInt = 0x8

///|
const FlagInverse : UInt = 0x10

///|
const FlagInvisible : UInt = 0x20

///|
const FlagStrikethrough : UInt = 0x40

///|
const FlagOverline : UInt = 0x80

///|
const UnderlineShift : Int = 8

///|
const UnderlineMask : UInt = 0x700

///|
fn underline_encode(value : @sgr.SgrUnderline) -> UInt {
  match value {
    None => 0
    Single => 1
    Double => 2
    Curly => 3
    Dotted => 4
    Dashed => 5
  }
}

///|
fn underline_decode(bits : UInt) -> @sgr.SgrUnderline {
  match bits {
    1 => Single
    2 => Double
    3 => Curly
    4 => Dotted
    5 => Dashed
    _ => None
  }
}

///|
struct CellStyle {
  mut fg_color : StyleColor
  mut bg_color : StyleColor
  mut underline_color : StyleColor
  mut flags : UInt
} derive(Eq, Debug)

///|
fn CellStyle::has_flag(self : CellStyle, mask : UInt) -> Bool {
  (self.flags & mask) != 0
}

///|
fn CellStyle::set_flag(self : CellStyle, mask : UInt, value : Bool) -> Unit {
  self.flags = if value { self.flags | mask } else { self.flags & mask.lnot() }
}

///|
pub fn CellStyle::new() -> CellStyle {
  {
    fg_color: StyleColor::none(),
    bg_color: StyleColor::none(),
    underline_color: StyleColor::none(),
    flags: 0,
  }
}

///|
pub fn CellStyle::reset(self : CellStyle) -> Unit {
  self.fg_color = StyleColor::none()
  self.bg_color = StyleColor::none()
  self.underline_color = StyleColor::none()
  self.flags = 0
}

///|
pub fn CellStyle::is_default(self : CellStyle) -> Bool {
  self.fg_color.is_default() &&
  self.bg_color.is_default() &&
  self.underline_color.is_default() &&
  self.flags == 0
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
  self.has_flag(FlagBold)
}

///|
pub fn CellStyle::italic(self : CellStyle) -> Bool {
  self.has_flag(FlagItalic)
}

///|
pub fn CellStyle::faint(self : CellStyle) -> Bool {
  self.has_flag(FlagFaint)
}

///|
pub fn CellStyle::blink(self : CellStyle) -> Bool {
  self.has_flag(FlagBlink)
}

///|
pub fn CellStyle::inverse(self : CellStyle) -> Bool {
  self.has_flag(FlagInverse)
}

///|
pub fn CellStyle::invisible(self : CellStyle) -> Bool {
  self.has_flag(FlagInvisible)
}

///|
pub fn CellStyle::strikethrough(self : CellStyle) -> Bool {
  self.has_flag(FlagStrikethrough)
}

///|
pub fn CellStyle::overline(self : CellStyle) -> Bool {
  self.has_flag(FlagOverline)
}

///|
pub fn CellStyle::underline(self : CellStyle) -> @sgr.SgrUnderline {
  underline_decode((self.flags >> UnderlineShift) & 0x7)
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
    flags: self.flags,
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
    Bold => self.set_flag(FlagBold, true)
    ResetBold => {
      self.set_flag(FlagBold, false)
      self.set_flag(FlagFaint, false)
    }
    Italic => self.set_flag(FlagItalic, true)
    ResetItalic => self.set_flag(FlagItalic, false)
    Faint => self.set_flag(FlagFaint, true)
    Underline(value) =>
      self.flags = (self.flags & UnderlineMask.lnot()) |
        (underline_encode(value) << UnderlineShift)
    UnderlineColor(rgb) => self.underline_color = StyleColor::rgb(rgb)
    Color256Underline(index) =>
      self.underline_color = StyleColor::palette(index)
    ResetUnderlineColor => self.underline_color = StyleColor::none()
    Overline => self.set_flag(FlagOverline, true)
    ResetOverline => self.set_flag(FlagOverline, false)
    Blink => self.set_flag(FlagBlink, true)
    ResetBlink => self.set_flag(FlagBlink, false)
    Inverse => self.set_flag(FlagInverse, true)
    ResetInverse => self.set_flag(FlagInverse, false)
    Invisible => self.set_flag(FlagInvisible, true)
    ResetInvisible => self.set_flag(FlagInvisible, false)
    Strikethrough => self.set_flag(FlagStrikethrough, true)
    ResetStrikethrough => self.set_flag(FlagStrikethrough, false)
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
