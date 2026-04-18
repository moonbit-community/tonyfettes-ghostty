///|
test "ansi/c0 mapping" {
  let codes : Array[Byte] = [
    0x00, 0x01, 0x02, 0x05, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
  ]
  for code in codes {
    guard c0_from_byte(code) is Some(control) else {
      fail("expected C0 mapping for \{code}")
    }
    assert_eq(control.code(), code)
  }
  guard c0_from_byte(0x7F) == None else { fail("expected no C0 mapping") }
}

///|
test "ansi/enum ordinal helpers" {
  assert_eq(CursorStyle::BlinkingBar.ordinal(), 5)
  guard cursor_style_from_int(6) == Some(CursorStyle::SteadyBar) else {
    fail("expected steady bar")
  }
  guard status_line_type_from_int(2) == Some(StatusLineType::HostWritable) else {
    fail("expected host_writable status line type")
  }
  assert_eq(StatusDisplay::StatusLine.ordinal(), 1)
  guard status_display_from_int(0) == Some(StatusDisplay::Main) else {
    fail("expected main status display")
  }
  guard modify_key_format_from_int(4) ==
    Some(ModifyKeyFormat::OtherKeysNumericExcept) else {
    fail("expected other_keys_numeric_except")
  }
  guard rendition_aspect_from_int(39) == Some(RenditionAspect::DefaultFg) else {
    fail("expected default fg aspect")
  }
  assert_eq(ProtectedMode::Iso == ProtectedMode::Iso, true)
}
