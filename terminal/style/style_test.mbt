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
  guard style.underline() == None else {
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
  let mut style = CellStyle::new()
  style = style.apply_attribute(Bold)
  style = style.apply_attribute(Faint)
  style = style.apply_attribute(Italic)
  style = style.apply_attribute(Blink)
  style = style.apply_attribute(Inverse)
  style = style.apply_attribute(Invisible)
  style = style.apply_attribute(Strikethrough)
  style = style.apply_attribute(Overline)
  style = style.apply_attribute(Underline(Curly))

  guard style.bold() &&
    style.faint() &&
    style.italic() &&
    style.blink() &&
    style.inverse() &&
    style.invisible() &&
    style.strikethrough() &&
    style.overline() &&
    style.underline() == Curly else {
    fail("expected sgr flags to be applied")
  }

  style = style.apply_attribute(ResetBold)
  guard !style.bold() && !style.faint() else {
    fail("expected reset bold to clear bold and faint")
  }

  style = style.apply_attribute(ResetItalic)
  style = style.apply_attribute(ResetBlink)
  style = style.apply_attribute(ResetInverse)
  style = style.apply_attribute(ResetInvisible)
  style = style.apply_attribute(ResetStrikethrough)
  style = style.apply_attribute(ResetOverline)
  style = style.apply_attribute(Underline(None))
  guard !style.italic() &&
    !style.blink() &&
    !style.inverse() &&
    !style.invisible() &&
    !style.strikethrough() &&
    !style.overline() &&
    style.underline() == None else {
    fail("expected sgr resets to clear style flags")
  }
}

///|
test "terminal style/applies foreground background and underline colors" {
  let mut style = CellStyle::new()
  style = style.apply_attribute(Color8Fg(Red))
  style = style.apply_attribute(Color8Bg(Blue))
  style = style.apply_attribute(BrightColor8Bg(BrightBlue))
  style = style.apply_attribute(BrightColor8Fg(BrightYellow))
  style = style.apply_attribute(Color256Underline(17))
  guard style.bg_color().palette_index() == Some(@color.Name::BrightBlue.code()) else {
    fail("expected bright palette background color")
  }
  guard style.fg_color().palette_index() ==
    Some(@color.Name::BrightYellow.code()) else {
    fail("expected bright palette foreground color")
  }
  guard style.underline_color().palette_index() == Some(17) else {
    fail("expected palette underline color")
  }

  let mut palette_bg = CellStyle::new()
  palette_bg = palette_bg.apply_attribute(Color8Bg(Blue))
  guard palette_bg.bg_color().palette_index() == Some(@color.Name::Blue.code()) else {
    fail("expected base palette background color")
  }

  let fg = @color.RGB::new(1, 2, 3)
  let bg = @color.RGB::new(4, 5, 6)
  let underline = @color.RGB::new(7, 8, 9)
  style = style.apply_attribute(DirectColorFg(fg))
  style = style.apply_attribute(DirectColorBg(bg))
  style = style.apply_attribute(UnderlineColor(underline))
  guard style.fg_color().rgb_value() == Some(fg) else {
    fail("expected rgb foreground color")
  }
  guard style.bg_color().rgb_value() == Some(bg) else {
    fail("expected rgb background color")
  }
  guard style.underline_color().rgb_value() == Some(underline) else {
    fail("expected rgb underline color")
  }

  style = style.apply_attribute(Color256Fg(99))
  style = style.apply_attribute(Color256Bg(100))
  guard style.fg_color().palette_index() == Some(99) else {
    fail("expected 256-color foreground")
  }
  guard style.bg_color().palette_index() == Some(100) else {
    fail("expected 256-color background")
  }

  style = style.apply_attribute(ResetFg)
  style = style.apply_attribute(ResetBg)
  style = style.apply_attribute(ResetUnderlineColor)
  guard style.fg_color().is_default() &&
    style.bg_color().is_default() &&
    style.underline_color().is_default() else {
    fail("expected color resets to restore default colors")
  }
}

///|
test "terminal style/unset resets whole style" {
  let mut style = CellStyle::new()
  style = style.apply_attribute(Bold)
  style = style.apply_attribute(
    DirectColorFg(@color.RGB::new(0xAA, 0xBB, 0xCC)),
  )
  style = style.apply_attribute(Underline(Dashed))
  style = style.apply_attribute(Unset)
  guard style.is_default() else {
    fail("expected unset to restore default style")
  }
}

///|
test "terminal style/unknown sgr attribute is ignored" {
  let mut style = CellStyle::new()
  style = style.apply_attribute(Bold)
  style = style.apply_attribute(Unknown({ full: [999], partial: [999] }))
  guard style.bold() else {
    fail("expected unknown sgr attribute to leave existing style untouched")
  }
}
