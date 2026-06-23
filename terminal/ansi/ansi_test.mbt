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
  guard cursor_style_from_int(6) == Some(SteadyBar) else {
    fail("expected steady bar")
  }
  guard status_line_type_from_int(2) == Some(HostWritable) else {
    fail("expected host_writable status line type")
  }
  assert_eq(StatusDisplay::StatusLine.ordinal(), 1)
  guard status_display_from_int(0) == Some(Main) else {
    fail("expected main status display")
  }
  guard modify_key_format_from_int(4) == Some(OtherKeysNumericExcept) else {
    fail("expected other_keys_numeric_except")
  }
  guard rendition_aspect_from_int(39) == Some(DefaultFg) else {
    fail("expected default fg aspect")
  }
  assert_eq(ProtectedMode::Iso == Iso, true)
}

///|
test "ansi/all conversion helpers roundtrip" {
  let aspects : Array[(RenditionAspect, UInt16)] = [
    (Default, 0),
    (Bold, 1),
    (DefaultFg, 39),
    (DefaultBg, 49),
  ]
  for entry in aspects {
    assert_eq(entry.0.code(), entry.1)
    guard rendition_aspect_from_int(entry.1) == Some(entry.0) else {
      fail("expected rendition aspect roundtrip for \{entry.1}")
    }
  }
  guard rendition_aspect_from_int(2) == None else {
    fail("expected unknown rendition aspect to be rejected")
  }

  let cursor_styles : Array[(CursorStyle, Int)] = [
    (Default, 0),
    (BlinkingBlock, 1),
    (SteadyBlock, 2),
    (BlinkingUnderline, 3),
    (SteadyUnderline, 4),
    (BlinkingBar, 5),
    (SteadyBar, 6),
  ]
  for entry in cursor_styles {
    assert_eq(entry.0.ordinal(), entry.1)
    guard cursor_style_from_int(entry.1) == Some(entry.0) else {
      fail("expected cursor style roundtrip for \{entry.1}")
    }
  }
  guard cursor_style_from_int(7) == None else {
    fail("expected unknown cursor style to be rejected")
  }

  let status_line_types : Array[(StatusLineType, UInt16)] = [
    (None, 0),
    (Indicator, 1),
    (HostWritable, 2),
  ]
  for entry in status_line_types {
    assert_eq(entry.0.code(), entry.1)
    guard status_line_type_from_int(entry.1) == Some(entry.0) else {
      fail("expected status line type roundtrip for \{entry.1}")
    }
  }
  guard status_line_type_from_int(3) == None else {
    fail("expected unknown status line type to be rejected")
  }

  let status_displays : Array[(StatusDisplay, Int)] = [
    (Main, 0),
    (StatusLine, 1),
  ]
  for entry in status_displays {
    assert_eq(entry.0.ordinal(), entry.1)
    guard status_display_from_int(entry.1) == Some(entry.0) else {
      fail("expected status display roundtrip for \{entry.1}")
    }
  }
  guard status_display_from_int(2) == None else {
    fail("expected unknown status display to be rejected")
  }

  let key_formats : Array[(ModifyKeyFormat, Int)] = [
    (Legacy, 0),
    (CursorKeys, 1),
    (FunctionKeys, 2),
    (OtherKeysNone, 3),
    (OtherKeysNumericExcept, 4),
    (OtherKeysNumeric, 5),
  ]
  for entry in key_formats {
    assert_eq(entry.0.ordinal(), entry.1)
    guard modify_key_format_from_int(entry.1) == Some(entry.0) else {
      fail("expected modify-key roundtrip for \{entry.1}")
    }
  }
  guard modify_key_format_from_int(6) == None else {
    fail("expected unknown modify-key format to be rejected")
  }
}
