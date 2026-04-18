///|
pub enum Style {
  Mode2048
  Csi14t
  Csi16t
  Csi18t
} derive(Eq, Debug)

///|
pub struct Size {
  rows : CellCountInt
  columns : CellCountInt
  cell_width : UInt
  cell_height : UInt
} derive(Eq, Debug)

///|
fn width_pixels(size : Size) -> UInt64 {
  size.columns.to_uint64() * size.cell_width.to_uint64()
}

///|
fn height_pixels(size : Size) -> UInt64 {
  size.rows.to_uint64() * size.cell_height.to_uint64()
}

///|
pub fn encode(style : Style, size : Size) -> String {
  match style {
    Mode2048 =>
      "\u{001B}[48;\{size.rows};\{size.columns};\{height_pixels(size)};\{width_pixels(size)}t"
    Csi14t => "\u{001B}[4;\{height_pixels(size)};\{width_pixels(size)}t"
    Csi16t => "\u{001B}[6;\{size.cell_height};\{size.cell_width}t"
    Csi18t => "\u{001B}[8;\{size.rows};\{size.columns}t"
  }
}
