///|
struct SpriteColor(Byte) derive(Eq, Debug)

///|
pub fn SpriteColor::on() -> SpriteColor {
  SpriteColor(0xFF)
}

///|
pub fn SpriteColor::off() -> SpriteColor {
  SpriteColor(0x00)
}

///|
pub fn SpriteColor::from_byte(value : Byte) -> SpriteColor {
  SpriteColor(value)
}

///|
pub fn SpriteColor::value(self : SpriteColor) -> Byte {
  self.0
}

///|
pub(all) struct SpritePoint[T] {
  x : T
  y : T
} derive(Eq, Debug)

///|
pub(all) struct SpriteLine[T] {
  p0 : SpritePoint[T]
  p1 : SpritePoint[T]
} derive(Eq, Debug)

///|
pub(all) struct SpriteBox[T] {
  p0 : SpritePoint[T]
  p1 : SpritePoint[T]
} derive(Eq, Debug)

///|
pub fn SpriteBox::rect(self : SpriteBox[Int]) -> SpriteRect[Int] {
  let tl_x = @cmp.minimum(self.p0.x, self.p1.x)
  let tl_y = @cmp.minimum(self.p0.y, self.p1.y)
  let br_x = @cmp.maximum(self.p0.x, self.p1.x)
  let br_y = @cmp.maximum(self.p0.y, self.p1.y)
  { x: tl_x, y: tl_y, width: br_x - tl_x, height: br_y - tl_y }
}

///|
pub(all) struct SpriteRect[T] {
  x : T
  y : T
  width : T
  height : T
} derive(Eq, Debug)

///|
pub(all) struct SpriteTriangle[T] {
  p0 : SpritePoint[T]
  p1 : SpritePoint[T]
  p2 : SpritePoint[T]
} derive(Eq, Debug)

///|
pub(all) struct SpriteQuad[T] {
  p0 : SpritePoint[T]
  p1 : SpritePoint[T]
  p2 : SpritePoint[T]
  p3 : SpritePoint[T]
} derive(Eq, Debug)

///|
pub(all) struct SpriteCanvas {
  mut data : Array[Byte]
  width : UInt
  height : UInt
  padding_x : UInt
  padding_y : UInt
  mut clip_top : UInt
  mut clip_left : UInt
  mut clip_right : UInt
  mut clip_bottom : UInt
} derive(Eq, Debug)

///|
pub fn SpriteCanvas::new(
  width : UInt,
  height : UInt,
  padding_x : UInt,
  padding_y : UInt,
) -> SpriteCanvas {
  let surface_width = width + 2U * padding_x
  let surface_height = height + 2U * padding_y
  {
    data: Array::make(
      (surface_width * surface_height).reinterpret_as_int(),
      b'\x00',
    ),
    width: surface_width,
    height: surface_height,
    padding_x,
    padding_y,
    clip_top: 0U,
    clip_left: 0U,
    clip_right: 0U,
    clip_bottom: 0U,
  }
}

///|
pub fn SpriteCanvas::write_atlas(
  self : SpriteCanvas,
  atlas : Atlas,
) -> AtlasRegion raise AtlasError {
  guard atlas.format == Grayscale else {
    abort("SpriteCanvas requires a grayscale atlas")
  }

  self.trim()

  let region_width = saturating_sub_uint(
    saturating_sub_uint(self.width, self.clip_left),
    self.clip_right,
  )
  let region_height = saturating_sub_uint(
    saturating_sub_uint(self.height, self.clip_top),
    self.clip_bottom,
  )

  let region = atlas.reserve(region_width, region_height)

  if region.width > 0U && region.height > 0U {
    atlas.set_from_larger(
      region,
      self.data.view(),
      self.width,
      self.clip_left,
      self.clip_top,
    )
  }

  region
}

///|
fn SpriteCanvas::trim(self : SpriteCanvas) -> Unit {
  let width = self.width
  let height = self.height

  top~: while self.clip_top < height - self.clip_bottom {
    let y = self.clip_top
    let x0 = self.clip_left
    let x1 = width - self.clip_right
    for x in x0.reinterpret_as_int()..<x1.reinterpret_as_int() {
      if self.data[(y * width + x.reinterpret_as_uint()).reinterpret_as_int()] !=
        b'\x00' {
        break top~
      }
    }
    self.clip_top += 1U
  }

  bottom~: while self.clip_bottom < height - self.clip_top {
    let y = saturating_sub_uint(height - self.clip_bottom, 1U)
    let x0 = self.clip_left
    let x1 = width - self.clip_right
    for x in x0.reinterpret_as_int()..<x1.reinterpret_as_int() {
      if self.data[(y * width + x.reinterpret_as_uint()).reinterpret_as_int()] !=
        b'\x00' {
        break bottom~
      }
    }
    self.clip_bottom += 1U
  }

  left~: while self.clip_left < width - self.clip_right {
    let x = self.clip_left
    let y0 = self.clip_top
    let y1 = height - self.clip_bottom
    for y in y0.reinterpret_as_int()..<y1.reinterpret_as_int() {
      if self.data[(y.reinterpret_as_uint() * width + x).reinterpret_as_int()] !=
        b'\x00' {
        break left~
      }
    }
    self.clip_left += 1U
  }

  right~: while self.clip_right < width - self.clip_left {
    let x = saturating_sub_uint(width - self.clip_right, 1U)
    let y0 = self.clip_top
    let y1 = height - self.clip_bottom
    for y in y0.reinterpret_as_int()..<y1.reinterpret_as_int() {
      if self.data[(y.reinterpret_as_uint() * width + x).reinterpret_as_int()] !=
        b'\x00' {
        break right~
      }
    }
    self.clip_right += 1U
  }
}

///|
pub fn SpriteCanvas::clear_clipping_regions(self : SpriteCanvas) -> Unit {
  let width = self.width.reinterpret_as_int()
  let height = self.height.reinterpret_as_int()

  for y in 0..<height {
    for x in 0..<self.clip_left.reinterpret_as_int() {
      self.data[y * width + x] = b'\x00'
    }
  }

  for y in 0..<height {
    for x in (width - self.clip_right.reinterpret_as_int())..<width {
      self.data[y * width + x] = b'\x00'
    }
  }

  for y in 0..<self.clip_top.reinterpret_as_int() {
    for x in 0..<width {
      self.data[y * width + x] = b'\x00'
    }
  }

  for y in (height - self.clip_bottom.reinterpret_as_int())..<height {
    for x in 0..<width {
      self.data[y * width + x] = b'\x00'
    }
  }
}

///|
pub fn SpriteCanvas::pixel(
  self : SpriteCanvas,
  x : Int,
  y : Int,
  color : SpriteColor,
) -> Unit {
  let surface_x = x + self.padding_x.reinterpret_as_int()
  let surface_y = y + self.padding_y.reinterpret_as_int()
  if surface_x < 0 ||
    surface_y < 0 ||
    surface_x >= self.width.reinterpret_as_int() ||
    surface_y >= self.height.reinterpret_as_int() {
    return
  }
  self.data[surface_y * self.width.reinterpret_as_int() + surface_x] = color.value()
}

///|
pub fn SpriteCanvas::rect(
  self : SpriteCanvas,
  v : SpriteRect[Int],
  color : SpriteColor,
) -> Unit {
  let mut y = v.y
  while y < v.y + v.height {
    let mut x = v.x
    while x < v.x + v.width {
      self.pixel(x, y, color)
      x += 1
    }
    y += 1
  }
}

///|
pub fn SpriteCanvas::box(
  self : SpriteCanvas,
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  color : SpriteColor,
) -> Unit {
  let box : SpriteBox[Int] = { p0: { x: x0, y: y0 }, p1: { x: x1, y: y1 } }
  self.rect(box.rect(), color)
}

///|
pub fn SpriteCanvas::invert(self : SpriteCanvas) -> Unit {
  for i in 0..<self.data.length() {
    self.data[i] = (255 - self.data[i].to_int()).to_byte()
  }
}

///|
pub fn SpriteCanvas::flip_horizontal(self : SpriteCanvas) -> Unit {
  let clone = self.data.copy()
  let width = self.width.reinterpret_as_int()
  let height = self.height.reinterpret_as_int()
  for y in 0..<height {
    for x in 0..<width {
      self.data[y * width + x] = clone[y * width + width - x - 1]
    }
  }
  let clip_left = self.clip_left
  self.clip_left = self.clip_right
  self.clip_right = clip_left
}

///|
pub fn SpriteCanvas::flip_vertical(self : SpriteCanvas) -> Unit {
  let clone = self.data.copy()
  let width = self.width.reinterpret_as_int()
  let height = self.height.reinterpret_as_int()
  for y in 0..<height {
    for x in 0..<width {
      self.data[y * width + x] = clone[(height - y - 1) * width + x]
    }
  }
  let clip_top = self.clip_top
  self.clip_top = self.clip_bottom
  self.clip_bottom = clip_top
}
