///|
test "terminal style/default state" {
  let style = CellStyle::new()
  guard style.is_default() else { fail("expected default style") }
  guard style.fg_color().is_default() else {
    fail("expected default foreground color")
  }
  guard style.bg_color().is_default() else {
    fail("expected default background color")
  }
  guard style.underline_color().is_default() else {
    fail("expected default underline color")
  }
  guard style.underline() == SgrUnderline::None else {
    fail("expected default underline style")
  }
  guard style.fg_color().palette_index() == None else {
    fail("expected default foreground palette lookup to be empty")
  }
  guard style.bg_color().rgb_value() == None else {
    fail("expected default background rgb lookup to be empty")
  }
}

///|
test "terminal style/apply sgr flags and resets" {
  let style = CellStyle::new()
  style.apply_attribute(Bold)
  style.apply_attribute(Faint)
  style.apply_attribute(Italic)
  style.apply_attribute(Blink)
  style.apply_attribute(Inverse)
  style.apply_attribute(Invisible)
  style.apply_attribute(Strikethrough)
  style.apply_attribute(Overline)
  style.apply_attribute(Underline(SgrUnderline::Curly))

  guard style.bold() &&
    style.faint() &&
    style.italic() &&
    style.blink() &&
    style.inverse() &&
    style.invisible() &&
    style.strikethrough() &&
    style.overline() &&
    style.underline() == SgrUnderline::Curly else {
    fail("expected sgr flags to be applied")
  }

  style.apply_attribute(ResetBold)
  guard !style.bold() && !style.faint() else {
    fail("expected reset bold to clear bold and faint")
  }

  style.apply_attribute(ResetItalic)
  style.apply_attribute(ResetBlink)
  style.apply_attribute(ResetInverse)
  style.apply_attribute(ResetInvisible)
  style.apply_attribute(ResetStrikethrough)
  style.apply_attribute(ResetOverline)
  style.apply_attribute(Underline(SgrUnderline::None))
  guard !style.italic() &&
    !style.blink() &&
    !style.inverse() &&
    !style.invisible() &&
    !style.strikethrough() &&
    !style.overline() &&
    style.underline() == SgrUnderline::None else {
    fail("expected sgr resets to clear style flags")
  }
}

///|
test "terminal style/applies foreground background and underline colors" {
  let style = CellStyle::new()
  style.apply_attribute(Color8Fg(Name::Red))
  style.apply_attribute(Color8Bg(Name::Blue))
  style.apply_attribute(BrightColor8Bg(Name::BrightBlue))
  style.apply_attribute(BrightColor8Fg(Name::BrightYellow))
  style.apply_attribute(Color256Underline(17))
  guard style.bg_color().palette_index() == Some(Name::BrightBlue.code()) else {
    fail("expected bright palette background color")
  }
  guard style.fg_color().palette_index() == Some(Name::BrightYellow.code()) else {
    fail("expected bright palette foreground color")
  }
  guard style.underline_color().palette_index() == Some(17) else {
    fail("expected palette underline color")
  }

  let palette_bg = CellStyle::new()
  palette_bg.apply_attribute(Color8Bg(Name::Blue))
  guard palette_bg.bg_color().palette_index() == Some(Name::Blue.code()) else {
    fail("expected base palette background color")
  }

  let fg = RGB::new(1, 2, 3)
  let bg = RGB::new(4, 5, 6)
  let underline = RGB::new(7, 8, 9)
  style.apply_attribute(DirectColorFg(fg))
  style.apply_attribute(DirectColorBg(bg))
  style.apply_attribute(UnderlineColor(underline))
  guard style.fg_color().rgb_value() == Some(fg) else {
    fail("expected rgb foreground color")
  }
  guard style.bg_color().rgb_value() == Some(bg) else {
    fail("expected rgb background color")
  }
  guard style.underline_color().rgb_value() == Some(underline) else {
    fail("expected rgb underline color")
  }

  style.apply_attribute(Color256Fg(99))
  style.apply_attribute(Color256Bg(100))
  guard style.fg_color().palette_index() == Some(99) else {
    fail("expected 256-color foreground")
  }
  guard style.bg_color().palette_index() == Some(100) else {
    fail("expected 256-color background")
  }

  style.apply_attribute(ResetFg)
  style.apply_attribute(ResetBg)
  style.apply_attribute(ResetUnderlineColor)
  guard style.fg_color().is_default() &&
    style.bg_color().is_default() &&
    style.underline_color().is_default() else {
    fail("expected color resets to restore default colors")
  }
}

///|
test "terminal style/unset resets whole style" {
  let style = CellStyle::new()
  style.apply_attribute(Bold)
  style.apply_attribute(DirectColorFg(RGB::new(0xAA, 0xBB, 0xCC)))
  style.apply_attribute(Underline(SgrUnderline::Dashed))
  style.apply_attribute(Unset)
  guard style.is_default() else {
    fail("expected unset to restore default style")
  }
}

///|
test "terminal style/unknown sgr attribute is ignored" {
  let style = CellStyle::new()
  style.apply_attribute(Bold)
  style.apply_attribute(Unknown({ full: [999], partial: [999] }))
  guard style.bold() else {
    fail("expected unknown sgr attribute to leave existing style untouched")
  }
}
