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
priv enum SpriteDrawThickness {
  ThicknessLight
  ThicknessHeavy
}

///|
fn SpriteDrawThickness::height(self : SpriteDrawThickness, base : UInt) -> UInt {
  match self {
    ThicknessLight => base
    ThicknessHeavy => base * 2U
  }
}

///|
fn vline(
  canvas : SpriteCanvas,
  y1 : Int,
  y2 : Int,
  x : Int,
  thickness_px : UInt,
) -> Unit {
  canvas.box(
    x,
    y1,
    x + thickness_px.reinterpret_as_int(),
    y2,
    SpriteColor::on(),
  )
}

///|
fn hline(
  canvas : SpriteCanvas,
  x1 : Int,
  x2 : Int,
  y : Int,
  thickness_px : UInt,
) -> Unit {
  canvas.box(
    x1,
    y,
    x2,
    y + thickness_px.reinterpret_as_int(),
    SpriteColor::on(),
  )
}

///|
fn vline_middle(
  metrics : Metrics,
  canvas : SpriteCanvas,
  thickness : SpriteDrawThickness,
) -> Unit {
  let thick_px = thickness.height(metrics.box_thickness)
  vline(
    canvas,
    0,
    metrics.cell_height.reinterpret_as_int(),
    (saturating_sub_uint(metrics.cell_width, thick_px) / 2U).reinterpret_as_int(),
    thick_px,
  )
}

///|
fn hline_middle(
  metrics : Metrics,
  canvas : SpriteCanvas,
  thickness : SpriteDrawThickness,
) -> Unit {
  let thick_px = thickness.height(metrics.box_thickness)
  hline(
    canvas,
    0,
    metrics.cell_width.reinterpret_as_int(),
    (saturating_sub_uint(metrics.cell_height, thick_px) / 2U).reinterpret_as_int(),
    thick_px,
  )
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
  OneQuarter
  Half
  TwoQuarters
  ThreeQuarters
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
    OneQuarter => 0.25
    Half => 0.5
    TwoQuarters => 0.5
    ThreeQuarters => 0.75
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
