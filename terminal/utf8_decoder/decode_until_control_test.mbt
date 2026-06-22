// Correctness tests for `decode_utf8_until_control_seq`. The first five port
// upstream Ghostty's `src/simd/vt.zig` tests verbatim (same inputs, same
// expected consumed/decoded/FFFD), then we add CJK + astral coverage and a
// cross-check against the byte-at-a-time `Utf8Decoder` on valid input.

///|
/// Repeat `chunk` `times` times into a single `Bytes`.
fn rep(chunk : Bytes, times : Int) -> Bytes {
  let buf = Buffer(size_hint=chunk.length() * times)
  for _ in 0..<times {
    buf.write_bytes(chunk)
  }
  buf.contents()
}

///|
test "decode no escape" {
  let out = FixedArray::make(2048, 0U)
  let res = decode_utf8_until_control_seq(rep(b"hello", 128), out)
  assert_eq(res.consumed, 640)
  assert_eq(res.decoded, 640)
}

///|
test "decode ASCII to escape" {
  let out = FixedArray::make(2048, 0U)
  let buf = Buffer(size_hint=1024)
  buf.write_bytes(rep(b"hello", 64))
  buf.write_byte(0x1B)
  buf.write_bytes(rep(b"world", 64))
  let res = decode_utf8_until_control_seq(buf.contents(), out)
  assert_eq(res.consumed, 320)
  assert_eq(res.decoded, 320)
}

///|
test "decode immediate esc sequence" {
  let out = FixedArray::make(64, 0U)
  let res = decode_utf8_until_control_seq(b"\x1b[?5s", out)
  assert_eq(res.consumed, 0)
  assert_eq(res.decoded, 0)
}

///|
test "decode incomplete UTF-8" {
  let out = FixedArray::make(64, 0U)

  // 2-byte truncated at end of buffer.
  let r1 = decode_utf8_until_control_seq(b"hello\xc2", out)
  assert_eq(r1.consumed, 5)
  assert_eq(r1.decoded, 5)

  // 3-byte: \xe0 expects A0-BF next, but \x00 is out of range, so \xe0 is a
  // maximal subpart of length 1 -> FFFD, then \x00 is ASCII NUL.
  let r2 = decode_utf8_until_control_seq(b"hello\xe0\x00", out)
  assert_eq(r2.consumed, 7)
  assert_eq(r2.decoded, 7)
  assert_eq(out[5], 0xFFFDU)
  assert_eq(out[6], 0x00U)

  // 4-byte truncated at end of buffer (F0 90 is valid so far).
  let r3 = decode_utf8_until_control_seq(b"hello\xf0\x90", out)
  assert_eq(r3.consumed, 5)
  assert_eq(r3.decoded, 5)
}

///|
test "decode invalid UTF-8" {
  let out = FixedArray::make(64, 0U)
  // Invalid 2-byte sequence: \xc2 then \x01 (not a continuation byte).
  let res = decode_utf8_until_control_seq(b"hello\xc2\x01", out)
  assert_eq(res.consumed, 7)
  assert_eq(res.decoded, 7)
  assert_eq(out[5], 0xFFFDU)
  assert_eq(out[6], 0x01U)
}

///|
test "decode CJK" {
  let out = FixedArray::make(64, 0U)
  // "中文终端测试" — six 3-byte sequences.
  let str = b"\xE4\xB8\xAD\xE6\x96\x87\xE7\xBB\x88\xE7\xAB\xAF\xE6\xB5\x8B\xE8\xAF\x95"
  let res = decode_utf8_until_control_seq(str, out)
  assert_eq(res.consumed, 18)
  assert_eq(res.decoded, 6)
  let expected : ReadOnlyArray[UInt] = [
    0x4E2DU, 0x6587U, 0x7EC8U, 0x7AEFU, 0x6D4BU, 0x8BD5U,
  ]
  for i in 0..<6 {
    assert_eq(out[i], expected[i])
  }
}

///|
test "decode astral plane (4-byte)" {
  let out = FixedArray::make(64, 0U)
  // U+1F600 GRINNING FACE = F0 9F 98 80.
  let res = decode_utf8_until_control_seq(b"\xF0\x9F\x98\x80", out)
  assert_eq(res.consumed, 4)
  assert_eq(res.decoded, 1)
  assert_eq(out[0], 0x1F600U)
}

///|
test "cross-check against scalar Utf8Decoder on valid input" {
  // ESC-free, all valid: ASCII + CJK (世界) + astral (😀) + Latin-1 (é).
  let payload = b"Hello, \xE4\xB8\x96\xE7\x95\x8C! 123 \xF0\x9F\x98\x80 mixed \xC3\xA9"
  let out = FixedArray::make(payload.length(), 0U)
  let res = decode_utf8_until_control_seq(payload, out)

  // Reference: feed the streaming decoder one byte at a time.
  let dec = Utf8Decoder::new()
  let scalar : Array[UInt] = []
  for b in payload {
    let r = dec.next(b)
    if r.value is Some(cp) {
      scalar.push(cp)
    }
    if !r.consumed {
      let r2 = dec.next(b)
      if r2.consumed && r2.value is Some(cp) {
        scalar.push(cp)
      }
    }
  }
  assert_eq(res.consumed, payload.length())
  assert_eq(res.decoded, scalar.length())
  for i in 0..<res.decoded {
    assert_eq(out[i], scalar[i])
  }
}
