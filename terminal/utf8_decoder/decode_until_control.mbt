// Fused "scan to next control byte + bulk UTF-8 decode" pass, the view-level
// counterpart to the byte-at-a-time `Utf8Decoder`. This is a faithful port of
// upstream Ghostty's `simd.vt.utf8DecodeUntilControlSeq` (`src/simd/vt.zig`) —
// the function `nextSliceCapped`'s ground-state loop calls every iteration.
// This is the SCALAR implementation; upstream swaps in a Highway/simdutf C
// routine here.
//
// Contract (matches upstream): decode `input` until the first ESC (0x1B) — all
// bytes before it are plain UTF-8 — writing codepoints (UTF-32, NOT UTF-16) into
// `output`, and return how many input bytes were consumed and how many
// codepoints were produced. The function is STATELESS: a multi-byte sequence
// truncated at the end of `input` is left unconsumed (the caller hands the
// remainder to the scalar `Utf8Decoder`, which buffers it for the next slice).
//
// Ill-formed input follows the W3C/Unicode "substitution of maximal subparts"
// rule: each maximal invalid subpart becomes a single U+FFFD.
//
// `output` must have room for at least `input.length()` codepoints (each input
// byte yields at most one codepoint), exactly as upstream asserts — this lets the
// writes use `unsafe_set` (index is always < output length).
//
// Implementation: a single fused pass driven by array-pattern matching over the
// byte view, so the common ASCII / valid-multi-byte cases read without per-byte
// bounds checks. Only the rare ill-formed / truncated tail falls to the
// indexed `maximal_subpart` helper.

///|
/// Bytes consumed from the input and codepoints written to the output buffer.
/// Mirrors upstream's `simd.vt.DecodeResult`. `#valtype` so it is returned by
/// value with no heap box — the ground path calls this once per run, which is
/// many short calls on escape-dense input.
#valtype
pub struct DecodeResult {
  consumed : Int
  decoded : Int
} derive(Eq, Debug)

///|
/// Decode `input` into `output` up to (but not including) the first ESC byte,
/// following Unicode Table 3-7 for structural validity and maximal-subpart
/// substitution for ill-formed sequences. See the file header for the contract.
pub fn decode_utf8_until_control_seq(
  input : BytesView,
  output : FixedArray[UInt],
) -> DecodeResult {
  // `off`/`count` are mutated in place rather than threaded as loop variables so
  // the loop neither breaks with a tuple nor destructures one (both would box).
  let mut off = 0
  let mut count = 0
  for bytes = input {
    match bytes {
      [] => break
      // ESC begins a control sequence, not text: stop, leave it unconsumed.
      [0x1B, ..] => break
      // Eight printable ASCII at once. The 0x20-0x7F bound excludes ESC and all
      // C0 controls, so this arm can never swallow a control byte.
      [
        0x20..=0x7F as a0,
        0x20..=0x7F as a1,
        0x20..=0x7F as a2,
        0x20..=0x7F as a3,
        0x20..=0x7F as a4,
        0x20..=0x7F as a5,
        0x20..=0x7F as a6,
        0x20..=0x7F as a7,
        .. rest,
      ] => {
        output.unsafe_set(count, a0.to_uint())
        output.unsafe_set(count + 1, a1.to_uint())
        output.unsafe_set(count + 2, a2.to_uint())
        output.unsafe_set(count + 3, a3.to_uint())
        output.unsafe_set(count + 4, a4.to_uint())
        output.unsafe_set(count + 5, a5.to_uint())
        output.unsafe_set(count + 6, a6.to_uint())
        output.unsafe_set(count + 7, a7.to_uint())
        off = off + 8
        count = count + 8
        continue rest
      }
      // A single byte < 0x80: a lone printable, or a C0 control other than ESC.
      [0..=0x7F as b, .. rest] => {
        output.unsafe_set(count, b.to_uint())
        off = off + 1
        count = count + 1
        continue rest
      }
      // Complete, structurally valid 2-byte sequence.
      [0xC2..=0xDF as b0, 0x80..=0xBF as b1, .. rest] => {
        let cp = ((b0.to_int() & 0x1F) << 6) | (b1.to_int() & 0x3F)
        output.unsafe_set(count, cp.reinterpret_as_uint())
        off = off + 2
        count = count + 1
        continue rest
      }
      // Complete, structurally valid 3-byte sequence (Table 3-7 lead/cont ranges).
      [0xE0 as b0, 0xA0..=0xBF as b1, 0x80..=0xBF as b2, .. rest]
      | [0xE1..=0xEC as b0, 0x80..=0xBF as b1, 0x80..=0xBF as b2, .. rest]
      | [0xED as b0, 0x80..=0x9F as b1, 0x80..=0xBF as b2, .. rest]
      | [0xEE..=0xEF as b0, 0x80..=0xBF as b1, 0x80..=0xBF as b2, .. rest] => {
        let cp = ((b0.to_int() & 0x0F) << 12) |
          ((b1.to_int() & 0x3F) << 6) |
          (b2.to_int() & 0x3F)
        output.unsafe_set(count, cp.reinterpret_as_uint())
        off = off + 3
        count = count + 1
        continue rest
      }
      // Complete, structurally valid 4-byte sequence.
      [
        0xF0 as b0,
        0x90..=0xBF as b1,
        0x80..=0xBF as b2,
        0x80..=0xBF as b3,
        .. rest,
      ]
      | [
        0xF1..=0xF3 as b0,
        0x80..=0xBF as b1,
        0x80..=0xBF as b2,
        0x80..=0xBF as b3,
        .. rest,
      ]
      | [
        0xF4 as b0,
        0x80..=0x8F as b1,
        0x80..=0xBF as b2,
        0x80..=0xBF as b3,
        .. rest,
      ] => {
        let cp = ((b0.to_int() & 0x07) << 18) |
          ((b1.to_int() & 0x3F) << 12) |
          ((b2.to_int() & 0x3F) << 6) |
          (b3.to_int() & 0x3F)
        output.unsafe_set(count, cp.reinterpret_as_uint())
        off = off + 4
        count = count + 1
        continue rest
      }
      // Anything else: an invalid byte, or a multi-byte sequence that is
      // ill-formed or truncated. Rare path — resolve one maximal subpart with the
      // indexed helper, or stop if the input is truncated mid-sequence.
      _ => {
        let sub = maximal_subpart(bytes)
        if sub == 0 {
          break
        }
        output.unsafe_set(count, 0xFFFDU)
        off = off + sub
        count = count + 1
        continue bytes[sub:]
      }
    }
  }
  { consumed: off, decoded: count }
}

///|
/// Length in bytes of the maximal valid subpart at the start of `bytes`, for the
/// ill-formed / truncated fallback. Returns 0 if the prefix is a structurally
/// valid but TRUNCATED multi-byte sequence (caller should stop and not consume).
/// Otherwise returns how many bytes form the maximal subpart to replace with a
/// single U+FFFD. `bytes` is non-empty.
fn maximal_subpart(bytes : BytesView) -> Int {
  let b0 = bytes[0].to_int()
  // Continuation byte (80-BF) or invalid lead (C0-C1, F5-FF): a 1-byte subpart.
  if b0 < 0xC2 || b0 > 0xF4 {
    return 1
  }
  let len = utf8_seq_len(b0)
  let avail = bytes.length()
  let mut valid = 1
  for ci in 0..<(len - 1) {
    if valid >= avail {
      return 0 // truncated: may be completed by a later slice
    }
    if !cont_ok(b0, ci, bytes[valid].to_int()) {
      return valid // ill-formed here: maximal subpart is the valid prefix
    }
    valid = valid + 1
  }
  valid
}

///|
/// Expected total byte length of a UTF-8 sequence from its (already validated as
/// C2-F4) lead byte.
fn utf8_seq_len(lead : Int) -> Int {
  if lead <= 0xDF {
    2
  } else if lead <= 0xEF {
    3
  } else {
    4
  }
}

///|
/// Whether `cb` is a valid continuation byte at position `ci` (0-based) of a
/// sequence with the given lead, per Unicode Table 3-7. Only the first
/// continuation has lead-specific ranges; all later ones are the generic
/// 0x80-0xBF. Returns a Bool (not a range tuple) to avoid an allocation.
fn cont_ok(lead : Int, ci : Int, cb : Int) -> Bool {
  if ci == 0 {
    match lead {
      0xE0 => cb >= 0xA0 && cb <= 0xBF
      0xED => cb >= 0x80 && cb <= 0x9F
      0xF0 => cb >= 0x90 && cb <= 0xBF
      0xF4 => cb >= 0x80 && cb <= 0x8F
      _ => cb >= 0x80 && cb <= 0xBF // C2-DF, E1-EC, EE-EF, F1-F3
    }
  } else {
    cb >= 0x80 && cb <= 0xBF
  }
}
