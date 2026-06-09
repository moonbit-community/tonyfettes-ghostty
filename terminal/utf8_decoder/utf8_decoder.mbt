///|
let char_classes : ReadOnlyArray[Byte] = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 7, 7,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  7, 7, 7, 8, 8, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 10, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 3, 11, 6,
  6, 6, 5, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
]

///|
let transitions : ReadOnlyArray[Byte] = [
  0, 12, 24, 36, 60, 96, 84, 12, 12, 12, 48, 72, 12, 12, 12, 12, 12, 12, 12, 12,
  12, 12, 12, 12, 12, 0, 12, 12, 12, 12, 12, 0, 12, 0, 12, 12, 12, 24, 12, 12, 12,
  12, 12, 24, 12, 24, 12, 12, 12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12,
  24, 12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 12, 12, 12, 12, 36, 12,
  36, 12, 12, 12, 36, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12, 12, 36, 12, 12, 12,
  12, 12, 12, 12, 12, 12, 12,
]

///|
const AcceptState : Byte = 0

///|
const RejectState : Byte = 12

///|
/// Abstract (no `pub`): the DFA's `state` indexes the transition table, so an
/// out-of-range value assigned from outside would make `next()` read past it.
/// Callers use `new`/`next`/`is_accept_state` only, so keep the storage sealed.
struct Utf8Decoder {
  mut accumulator : UInt
  mut state : Byte
} derive(Eq, Debug)

///|
pub fn Utf8Decoder::new() -> Utf8Decoder {
  { accumulator: 0, state: AcceptState }
}

///|
/// Whether the decoder is at the accept (ground) state, i.e. not mid-sequence.
/// Read-only boundary accessor for stream's ground-state fast path, so callers
/// in other packages do not need access to the private `state` field.
pub fn Utf8Decoder::is_accept_state(self : Utf8Decoder) -> Bool {
  self.state == AcceptState
}

///|
/// The result of decoding one byte: the codepoint produced (if any) and whether
/// the byte was consumed (`consumed` is false on a reject that restarts the
/// state machine, so the byte must be re-fed). An immutable `#valtype` returned
/// by value with no heap object — unlike the `(UInt?, Bool)` tuple it replaces,
/// which was a per-byte heap allocation on the text hot path.
#valtype
pub struct Utf8Decoded {
  value : UInt?
  consumed : Bool
}

///|
pub fn Utf8Decoder::next(self : Utf8Decoder, byte : Byte) -> Utf8Decoded {
  let char_class = char_classes[byte.to_int()]
  let initial_state = self.state

  if self.state != AcceptState {
    self.accumulator = (self.accumulator << 6) | (byte & 0x3F).to_uint()
  } else {
    self.accumulator = ((0xFF >> char_class.to_int()) & byte.to_int()).reinterpret_as_uint()
  }

  self.state = transitions[self.state.to_int() + char_class.to_int()]

  if self.state == AcceptState {
    let result = self.accumulator
    self.accumulator = 0
    { value: Some(result), consumed: true }
  } else if self.state == RejectState {
    self.accumulator = 0
    self.state = AcceptState
    { value: Some(0xFFFD), consumed: initial_state == AcceptState }
  } else {
    { value: None, consumed: true }
  }
}
