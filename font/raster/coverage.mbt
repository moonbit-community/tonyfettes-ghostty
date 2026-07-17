///|
/// An alpha-coverage buffer: one `Double` in `[0, 1]` per pixel, row-major.
struct Coverage {
  width : Int
  height : Int
  data : Array[Double]
}

///|
pub fn Coverage::new(width : Int, height : Int) -> Coverage {
  { width, height, data: Array::make(width * height, 0.0) }
}

///|
pub fn Coverage::get(self : Coverage, x : Int, y : Int) -> Double {
  self.data[y * self.width + x]
}

///|
/// Buffer width in pixels.
pub fn Coverage::width(self : Coverage) -> Int {
  self.width
}

///|
/// Buffer height in pixels.
pub fn Coverage::height(self : Coverage) -> Int {
  self.height
}

///|
/// Sum of all pixel coverage. Because each pixel has unit area, this equals the
/// rendered area in px² — the quantity compared against the analytic shoelace
/// area in the area-conservation tests.
pub fn Coverage::total(self : Coverage) -> Double {
  let mut s = 0.0
  for v in self.data {
    s += v
  }
  s
}

///|
/// Largest per-pixel coverage difference between two equally-sized buffers.
pub fn Coverage::max_abs_diff(self : Coverage, other : Coverage) -> Double {
  let mut m = 0.0
  for i in 0..<self.data.length() {
    let d = absd(self.data[i] - other.data[i])
    if d > m {
      m = d
    }
  }
  m
}

///|
/// Mean per-pixel coverage difference between two equally-sized buffers.
pub fn Coverage::mean_abs_diff(self : Coverage, other : Coverage) -> Double {
  let mut s = 0.0
  for i in 0..<self.data.length() {
    s += absd(self.data[i] - other.data[i])
  }
  s / self.data.length().to_double()
}

///|
/// Render the buffer as ASCII art for eyeballing / snapshot regression tests.
pub fn Coverage::to_ascii(self : Coverage) -> String {
  let ramp : FixedArray[Char] = [
    ' ', '.', ':', '-', '=', '+', '*', '#', '%', '@',
  ]
  let sb = StringBuilder::new()
  for y in 0..<self.height {
    for x in 0..<self.width {
      let v = self.get(x, y)
      let mut idx = (v * (ramp.length() - 1).to_double()).to_int()
      if idx < 0 {
        idx = 0
      }
      if idx >= ramp.length() {
        idx = ramp.length() - 1
      }
      sb.write_char(ramp[idx])
    }
    sb.write_char('\n')
  }
  sb.to_string()
}
