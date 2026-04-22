///|
test "paste/safety matches upstream suspicious cases" {
  guard paste_is_safe(b"hello world") else {
    fail("expected plain text to be safe")
  }
  guard paste_is_safe(b"") else { fail("expected empty payload to be safe") }
  guard !paste_is_safe(b"hello\nworld") else {
    fail("expected newline to be unsafe")
  }
  guard !paste_is_safe(b"hello\x1B[201~world") else {
    fail("expected bracketed-paste terminator to be unsafe")
  }
}

///|
test "paste/encode bracketed keeps content and wraps fenceposts" {
  let encoded = PasteOptions::new(true).encode(b"hello")
  assert_eq(encoded, b"\x1B[200~hello\x1B[201~")
}

///|
test "paste/encode unbracketed rewrites newlines like xterm" {
  let encoded = PasteOptions::new(false).encode(b"hello\r\nworld")
  assert_eq(encoded, b"hello\r\rworld")
}

///|
test "paste/encode strips unsafe bytes in both modes" {
  let bracketed = PasteOptions::new(true).encode(b"hel\x1Blo\x00world")
  assert_eq(bracketed, b"\x1B[200~hel lo world\x1B[201~")

  let unbracketed = PasteOptions::new(false).encode(b"hel\x03lo")
  assert_eq(unbracketed, b"hel lo")
}
