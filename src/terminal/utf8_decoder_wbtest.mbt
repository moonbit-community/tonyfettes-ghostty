///|
fn decode_sequence(bytes : Bytes) -> Array[UInt] {
  let decoder = Utf8Decoder::new()
  let out : Array[UInt] = []
  for byte in bytes {
    let mut consumed = false
    while !consumed {
      let (value, did_consume) = decoder.next(byte)
      consumed = did_consume
      if value is Some(codepoint) {
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
  assert_eq(decoded, expected)
}

///|
test "utf8 decoder/well formed utf8" {
  let decoded = decode_sequence([
    0xF0, 0x9F, 0x98, 0x84, 0xE2, 0x9C, 0xA4, 0xC3, 0x81, 0x41,
  ])
  assert_eq(decoded, [0x1F604, 0x2724, 0xC1, 0x41])
}

///|
test "utf8 decoder/well formed input consumes immediately" {
  let decoder = Utf8Decoder::new()
  let bytes : Bytes = [
    0xF0, 0x9F, 0x98, 0x84, 0xE2, 0x9C, 0xA4, 0xC3, 0x81, 0x41,
  ]
  for byte in bytes {
    let (_, consumed) = decoder.next(byte)
    assert_true(consumed)
  }
}

///|
test "utf8 decoder/partially invalid utf8" {
  let decoded = decode_sequence([
    0xF0, 0x9F, 0xF0, 0x9F, 0x98, 0x84, 0xED, 0xA0, 0x80,
  ])
  assert_eq(decoded, [0xFFFD, 0x1F604, 0xFFFD, 0xFFFD, 0xFFFD])
}

///|
test "utf8 decoder/invalid leading byte consumes" {
  let decoder = Utf8Decoder::new()
  let (value, consumed) = decoder.next(0x80)
  guard value == Some(0xFFFD) && consumed else {
    fail("expected invalid leading byte to emit replacement and consume")
  }
}

///|
test "utf8 decoder/invalid continuation retries same byte" {
  let decoder = Utf8Decoder::new()
  let (first, first_consumed) = decoder.next(0xE2)
  guard first == None && first_consumed else {
    fail("expected decoder to start a multibyte sequence")
  }

  let (second, second_consumed) = decoder.next(0x41)
  guard second == Some(0xFFFD) && !second_consumed else {
    fail("expected retry signal on invalid continuation")
  }

  let (third, third_consumed) = decoder.next(0x41)
  guard third == Some(0x41) && third_consumed else {
    fail("expected the same byte to decode as ASCII on retry")
  }
}
