///|
test "terminal system/internal decode helper reflects the installed callback" {
  terminal_system_clear_decode_png()
  guard terminal_system_decode_png(b"ABC") == None else {
    fail("expected cleared decoder helper to return none")
  }

  terminal_system_set_decode_png(fn(data) {
    Some(SystemImage::new(1U, 1U, data))
  })
  guard terminal_system_decode_png(b"\x01\x02") ==
    Some(SystemImage::new(1U, 1U, b"\x01\x02")) else {
    fail("expected installed decoder helper to delegate to callback")
  }

  terminal_system_clear_decode_png()
}
