///|
const AsciiZero : Byte = b'0'

///|
const AsciiUpperA : Byte = b'A'

///|
fn write_uint_ascii(buffer : @buffer.Buffer, value : UInt64) -> Unit {
  if value >= 10UL {
    write_uint_ascii(buffer, value / 10UL)
  }
  let digit = (value % 10UL).to_int()
  buffer.write_byte((digit + AsciiZero.to_int()).to_byte())
}

///|
fn write_hex8(buffer : @buffer.Buffer, value : UInt) -> Unit {
  let mut shift = 28
  while shift >= 0 {
    let nibble = ((value >> shift) & 0xF).reinterpret_as_int()
    buffer.write_byte(hex_digit_upper(nibble))
    shift -= 4
  }
}

///|
fn hex_digit_upper(value : Int) -> Byte {
  if value < 10 {
    (value + AsciiZero.to_int()).to_byte()
  } else {
    (value - 10 + AsciiUpperA.to_int()).to_byte()
  }
}
