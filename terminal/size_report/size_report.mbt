///|
pub(all) enum Style {
  Mode2048
  Csi14t
  Csi16t
  Csi18t
} derive(Eq, Debug)

///|
struct Size {
  rows : @size.CellCountInt
  columns : @size.CellCountInt
  cell_width : UInt
  cell_height : UInt
} derive(Eq, Debug)

///|
pub fn Size::new(
  rows : @size.CellCountInt,
  columns : @size.CellCountInt,
  cell_width : UInt,
  cell_height : UInt,
) -> Size {
  { rows, columns, cell_width, cell_height }
}

///|
pub fn Size::rows(self : Size) -> @size.CellCountInt {
  self.rows
}

///|
pub fn Size::columns(self : Size) -> @size.CellCountInt {
  self.columns
}

///|
pub fn Size::cell_width(self : Size) -> UInt {
  self.cell_width
}

///|
pub fn Size::cell_height(self : Size) -> UInt {
  self.cell_height
}

///|
fn width_pixels(size : Size) -> UInt64 {
  size.columns.to_uint64() * size.cell_width.to_uint64()
}

///|
fn height_pixels(size : Size) -> UInt64 {
  size.rows.to_uint64() * size.cell_height.to_uint64()
}

///|
pub fn encode(style : Style, size : Size) -> Bytes {
  let buffer = Buffer()
  buffer.write_bytes(b"\x1B[")
  match style {
    Mode2048 => {
      buffer.write_bytes(b"48;")
      @ascii.write_uint_ascii(buffer, size.rows.to_uint64())
      buffer.write_byte(b';')
      @ascii.write_uint_ascii(buffer, size.columns.to_uint64())
      buffer.write_byte(b';')
      @ascii.write_uint_ascii(buffer, height_pixels(size))
      buffer.write_byte(b';')
      @ascii.write_uint_ascii(buffer, width_pixels(size))
      buffer.write_byte(b't')
    }
    Csi14t => {
      buffer.write_bytes(b"4;")
      @ascii.write_uint_ascii(buffer, height_pixels(size))
      buffer.write_byte(b';')
      @ascii.write_uint_ascii(buffer, width_pixels(size))
      buffer.write_byte(b't')
    }
    Csi16t => {
      buffer.write_bytes(b"6;")
      @ascii.write_uint_ascii(buffer, size.cell_height.to_uint64())
      buffer.write_byte(b';')
      @ascii.write_uint_ascii(buffer, size.cell_width.to_uint64())
      buffer.write_byte(b't')
    }
    Csi18t => {
      buffer.write_bytes(b"8;")
      @ascii.write_uint_ascii(buffer, size.rows.to_uint64())
      buffer.write_byte(b';')
      @ascii.write_uint_ascii(buffer, size.columns.to_uint64())
      buffer.write_byte(b't')
    }
  }
  buffer.contents()
}
