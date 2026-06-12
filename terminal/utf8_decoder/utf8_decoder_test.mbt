///|
fn decode_sequence(bytes : Bytes) -> Array[UInt] {
  let decoder = Utf8Decoder::new()
  let out : Array[UInt] = []
  for byte in bytes {
    let mut consumed = false
    while !consumed {
      let decoded = decoder.next(byte)
      consumed = decoded.consumed
      if decoded.value is Some(codepoint) {
        out.push(codepoint)
      }
    }
  }
  out
}

///|
test "utf8 decoder/ascii" {
  let decoded = decode_sequence(b"Hello, World!")
  let expected : Array[UInt] = []
  for byte in b"Hello, World!" {
    expected.push(byte.to_uint())
  }
  guard decoded == expected else {
    fail("expected ASCII input to decode one codepoint per byte")
  }
}

///|
test "utf8 decoder/well formed utf8" {
  let decoded = decode_sequence([
    0xF0, 0x9F, 0x98, 0x84, 0xE2, 0x9C, 0xA4, 0xC3, 0x81, 0x41,
  ])
  guard decoded == [0x1F604, 0x2724, 0xC1, 0x41] else {
    fail("expected well-formed UTF-8 to decode to Unicode codepoints")
  }
}

///|
test "utf8 decoder/well formed input consumes immediately" {
  let decoder = Utf8Decoder::new()
  let bytes : Bytes = [
    0xF0, 0x9F, 0x98, 0x84, 0xE2, 0x9C, 0xA4, 0xC3, 0x81, 0x41,
  ]
  for byte in bytes {
    assert_true(decoder.next(byte).consumed)
  }
}

///|
test "utf8 decoder/partially invalid utf8" {
  let decoded = decode_sequence([
    0xF0, 0x9F, 0xF0, 0x9F, 0x98, 0x84, 0xED, 0xA0, 0x80,
  ])
  guard decoded == [0xFFFD, 0x1F604, 0xFFFD, 0xFFFD, 0xFFFD] else {
    fail("expected invalid UTF-8 segments to emit replacement codepoints")
  }
}

///|
test "utf8 decoder/invalid leading byte consumes" {
  let decoder = Utf8Decoder::new()
  let decoded = decoder.next(0x80)
  guard decoded.value == Some(0xFFFD) && decoded.consumed else {
    fail("expected invalid leading byte to emit replacement and consume")
  }
}

///|
test "utf8 decoder/invalid continuation retries same byte" {
  let decoder = Utf8Decoder::new()
  let first = decoder.next(0xE2)
  guard first.value == None && first.consumed else {
    fail("expected decoder to start a multibyte sequence")
  }

  let second = decoder.next(0x41)
  guard second.value == Some(0xFFFD) && !second.consumed else {
    fail("expected retry signal on invalid continuation")
  }

  let third = decoder.next(0x41)
  guard third.value == Some(0x41) && third.consumed else {
    fail("expected the same byte to decode as ASCII on retry")
  }
}
