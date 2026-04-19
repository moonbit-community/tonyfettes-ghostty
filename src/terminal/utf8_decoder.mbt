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
pub struct Utf8Decoder {
  mut accumulator : UInt
  mut state : Byte
} derive(Eq, Debug)

///|
pub fn Utf8Decoder::new() -> Utf8Decoder {
  { accumulator: 0, state: AcceptState }
}

///|
pub fn Utf8Decoder::next(self : Utf8Decoder, byte : Byte) -> (UInt?, Bool) {
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
    (Some(result), true)
  } else if self.state == RejectState {
    self.accumulator = 0
    self.state = AcceptState
    (Some(0xFFFD), initial_state == AcceptState)
  } else {
    (None, true)
  }
}
