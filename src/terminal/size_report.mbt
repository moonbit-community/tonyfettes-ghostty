///|
pub enum Style {
  Mode2048
  Csi14t
  Csi16t
  Csi18t
} derive(Eq, Debug)

///|
struct Size {
  rows : CellCountInt
  columns : CellCountInt
  cell_width : UInt
  cell_height : UInt
} derive(Eq, Debug)

///|
pub fn Size::new(
  rows : CellCountInt,
  columns : CellCountInt,
  cell_width : UInt,
  cell_height : UInt,
) -> Size {
  { rows, columns, cell_width, cell_height }
}

///|
pub fn Size::rows(self : Size) -> CellCountInt {
  self.rows
}

///|
pub fn Size::columns(self : Size) -> CellCountInt {
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
  let buffer = @buffer.new()
  buffer.write_bytes(b"\x1B[")
  match style {
    Mode2048 => {
      buffer.write_bytes(b"48;")
      write_uint_ascii(buffer, size.rows.to_uint64())
      buffer.write_byte(b';')
      write_uint_ascii(buffer, size.columns.to_uint64())
      buffer.write_byte(b';')
      write_uint_ascii(buffer, height_pixels(size))
      buffer.write_byte(b';')
      write_uint_ascii(buffer, width_pixels(size))
      buffer.write_byte(b't')
    }
    Csi14t => {
      buffer.write_bytes(b"4;")
      write_uint_ascii(buffer, height_pixels(size))
      buffer.write_byte(b';')
      write_uint_ascii(buffer, width_pixels(size))
      buffer.write_byte(b't')
    }
    Csi16t => {
      buffer.write_bytes(b"6;")
      write_uint_ascii(buffer, size.cell_height.to_uint64())
      buffer.write_byte(b';')
      write_uint_ascii(buffer, size.cell_width.to_uint64())
      buffer.write_byte(b't')
    }
    Csi18t => {
      buffer.write_bytes(b"8;")
      write_uint_ascii(buffer, size.rows.to_uint64())
      buffer.write_byte(b';')
      write_uint_ascii(buffer, size.columns.to_uint64())
      buffer.write_byte(b't')
    }
  }
  buffer.contents()
}
