///|
const SpriteOneEighth : Double = 0.125

///|
const SpriteOneQuarter : Double = 0.25

///|
const SpriteThreeEighths : Double = 0.375

///|
const SpriteHalf : Double = 0.5

///|
const SpriteFiveEighths : Double = 0.625

///|
const SpriteThreeQuarters : Double = 0.75

///|
const SpriteSevenEighths : Double = 0.875

///|
fn draw2580_259f(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(width)
  ignore(height)
  match cp {
    0x2580 =>
      block(metrics, canvas, sprite_draw_alignment_upper(), 1.0, SpriteHalf)
    0x2581 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        SpriteOneEighth,
      )
    0x2582 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        SpriteOneQuarter,
      )
    0x2583 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        SpriteThreeEighths,
      )
    0x2584 =>
      block(metrics, canvas, sprite_draw_alignment_lower(), 1.0, SpriteHalf)
    0x2585 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        SpriteFiveEighths,
      )
    0x2586 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        SpriteThreeQuarters,
      )
    0x2587 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        SpriteSevenEighths,
      )
    0x2588 => full_block_shade(metrics, canvas, sprite_draw_shade_on())
    0x2589 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_left(),
        SpriteSevenEighths,
        1.0,
      )
    0x258A =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_left(),
        SpriteThreeQuarters,
        1.0,
      )
    0x258B =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_left(),
        SpriteFiveEighths,
        1.0,
      )
    0x258C =>
      block(metrics, canvas, sprite_draw_alignment_left(), SpriteHalf, 1.0)
    0x258D =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_left(),
        SpriteThreeEighths,
        1.0,
      )
    0x258E =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_left(),
        SpriteOneQuarter,
        1.0,
      )
    0x258F =>
      block(metrics, canvas, sprite_draw_alignment_left(), SpriteOneEighth, 1.0)
    0x2590 =>
      block(metrics, canvas, sprite_draw_alignment_right(), SpriteHalf, 1.0)
    0x2591 => full_block_shade(metrics, canvas, sprite_draw_shade_light())
    0x2592 => full_block_shade(metrics, canvas, sprite_draw_shade_medium())
    0x2593 => full_block_shade(metrics, canvas, sprite_draw_shade_dark())
    0x2594 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        SpriteOneEighth,
      )
    0x2595 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        SpriteOneEighth,
        1.0,
      )
    0x2596 =>
      quadrant(metrics, canvas, { tl: false, tr: false, bl: true, br: false })
    0x2597 =>
      quadrant(metrics, canvas, { tl: false, tr: false, bl: false, br: true })
    0x2598 =>
      quadrant(metrics, canvas, { tl: true, tr: false, bl: false, br: false })
    0x2599 =>
      quadrant(metrics, canvas, { tl: true, tr: false, bl: true, br: true })
    0x259A =>
      quadrant(metrics, canvas, { tl: true, tr: false, bl: false, br: true })
    0x259B =>
      quadrant(metrics, canvas, { tl: true, tr: true, bl: true, br: false })
    0x259C =>
      quadrant(metrics, canvas, { tl: true, tr: true, bl: false, br: true })
    0x259D =>
      quadrant(metrics, canvas, { tl: false, tr: true, bl: false, br: false })
    0x259E =>
      quadrant(metrics, canvas, { tl: false, tr: true, bl: true, br: false })
    0x259F =>
      quadrant(metrics, canvas, { tl: false, tr: true, bl: true, br: true })
    _ => abort("unreachable block element")
  }
}

///|
fn block(
  metrics : Metrics,
  canvas : SpriteCanvas,
  alignment : SpriteDrawAlignment,
  width : Double,
  height : Double,
) -> Unit {
  block_shade(metrics, canvas, alignment, width, height, sprite_draw_shade_on())
}

///|
fn block_shade(
  metrics : Metrics,
  canvas : SpriteCanvas,
  alignment : SpriteDrawAlignment,
  width : Double,
  height : Double,
  shade : SpriteDrawShade,
) -> Unit {
  let float_width = metrics.cell_width.to_double()
  let float_height = metrics.cell_height.to_double()
  let w = @math.round(float_width * width).to_uint()
  let h = @math.round(float_height * height).to_uint()
  let x = match alignment.horizontal {
    Left => 0U
    Right => metrics.cell_width - w
    Center => (metrics.cell_width - w) / 2U
  }
  let y = match alignment.vertical {
    Top => 0U
    Bottom => metrics.cell_height - h
    Middle => (metrics.cell_height - h) / 2U
  }
  canvas.rect(
    {
      x: x.reinterpret_as_int(),
      y: y.reinterpret_as_int(),
      width: w.reinterpret_as_int(),
      height: h.reinterpret_as_int(),
    },
    shade.color(),
  )
}

///|
fn full_block_shade(
  metrics : Metrics,
  canvas : SpriteCanvas,
  shade : SpriteDrawShade,
) -> Unit {
  canvas.box(
    0,
    0,
    metrics.cell_width.reinterpret_as_int(),
    metrics.cell_height.reinterpret_as_int(),
    shade.color(),
  )
}

///|
fn quadrant(
  metrics : Metrics,
  canvas : SpriteCanvas,
  quads : SpriteDrawQuads,
) -> Unit {
  if quads.tl {
    fill(metrics, canvas, Zero, Half, Zero, Half)
  }
  if quads.tr {
    fill(metrics, canvas, Half, Full, Zero, Half)
  }
  if quads.bl {
    fill(metrics, canvas, Zero, Half, Half, Full)
  }
  if quads.br {
    fill(metrics, canvas, Half, Full, Half, Full)
  }
}
