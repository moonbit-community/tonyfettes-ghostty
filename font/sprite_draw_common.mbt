///|
priv struct SpriteDrawShade(Byte)

///|
fn sprite_draw_shade_light() -> SpriteDrawShade {
  SpriteDrawShade(0x40)
}

///|
fn sprite_draw_shade_medium() -> SpriteDrawShade {
  SpriteDrawShade(0x80)
}

///|
fn sprite_draw_shade_dark() -> SpriteDrawShade {
  SpriteDrawShade(0xC0)
}

///|
fn sprite_draw_shade_on() -> SpriteDrawShade {
  SpriteDrawShade(0xFF)
}

///|
fn SpriteDrawShade::color(self : SpriteDrawShade) -> SpriteColor {
  SpriteColor::from_byte(self.0)
}

///|
priv enum SpriteDrawHorizontalAlignment {
  Left
  Right
  Center
}

///|
priv enum SpriteDrawVerticalAlignment {
  Top
  Bottom
  Middle
}

///|
priv struct SpriteDrawAlignment {
  horizontal : SpriteDrawHorizontalAlignment
  vertical : SpriteDrawVerticalAlignment
}

///|
fn sprite_draw_alignment_upper() -> SpriteDrawAlignment {
  { horizontal: Center, vertical: Top }
}

///|
fn sprite_draw_alignment_lower() -> SpriteDrawAlignment {
  { horizontal: Center, vertical: Bottom }
}

///|
fn sprite_draw_alignment_left() -> SpriteDrawAlignment {
  { horizontal: Left, vertical: Middle }
}

///|
fn sprite_draw_alignment_right() -> SpriteDrawAlignment {
  { horizontal: Right, vertical: Middle }
}

///|
priv struct SpriteDrawQuads {
  tl : Bool
  tr : Bool
  bl : Bool
  br : Bool
}

///|
priv enum SpriteDrawFraction {
  Zero
  Half
  Full
}

///|
fn SpriteDrawFraction::min(self : SpriteDrawFraction, size : UInt) -> Int {
  let s = size.to_double()
  (s - @math.round((1.0 - self.fraction()) * s)).to_int()
}

///|
fn SpriteDrawFraction::max(self : SpriteDrawFraction, size : UInt) -> Int {
  @math.round(self.fraction() * size.to_double()).to_int()
}

///|
fn SpriteDrawFraction::fraction(self : SpriteDrawFraction) -> Double {
  match self {
    Zero => 0.0
    Half => 0.5
    Full => 1.0
  }
}

///|
fn fill(
  metrics : Metrics,
  canvas : SpriteCanvas,
  x0 : SpriteDrawFraction,
  x1 : SpriteDrawFraction,
  y0 : SpriteDrawFraction,
  y1 : SpriteDrawFraction,
) -> Unit {
  canvas.box(
    x0.min(metrics.cell_width),
    y0.min(metrics.cell_height),
    x1.max(metrics.cell_width),
    y1.max(metrics.cell_height),
    SpriteColor::on(),
  )
}
