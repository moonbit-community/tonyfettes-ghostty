///|
const LegacyOneEighth : Double = 0.125

///|
const LegacyOneQuarter : Double = 0.25

///|
const LegacyOneThird : Double = 1.0 / 3.0

///|
const LegacyThreeEighths : Double = 0.375

///|
const LegacyHalf : Double = 0.5

///|
const LegacyFiveEighths : Double = 0.625

///|
const LegacyTwoThirds : Double = 2.0 / 3.0

///|
const LegacyThreeQuarters : Double = 0.75

///|
const LegacySevenEighths : Double = 0.875

///|
fn legacy_eighths() -> ReadOnlyArray[SpriteDrawFraction] {
  [
    Zero,
    OneEighth,
    OneQuarter,
    ThreeEighths,
    Half,
    FiveEighths,
    ThreeQuarters,
    SevenEighths,
    Full,
  ]
}

///|
fn draw1fb00_1fb3b(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(width)
  ignore(height)

  guard cp >= 0x1FB00U && cp <= 0x1FB3BU else {
    abort("unreachable legacy computing sextant")
  }
  let idx = cp - 0x1FB00U
  let sex = (idx + idx / 0x14U + 1U).reinterpret_as_int()
  if (sex & 0x01) != 0 {
    fill(metrics, canvas, Zero, Half, Zero, OneThird)
  }
  if (sex & 0x02) != 0 {
    fill(metrics, canvas, Half, Full, Zero, OneThird)
  }
  if (sex & 0x04) != 0 {
    fill(metrics, canvas, Zero, Half, OneThird, TwoThirds)
  }
  if (sex & 0x08) != 0 {
    fill(metrics, canvas, Half, Full, OneThird, TwoThirds)
  }
  if (sex & 0x10) != 0 {
    fill(metrics, canvas, Zero, Half, TwoThirds, Full)
  }
  if (sex & 0x20) != 0 {
    fill(metrics, canvas, Half, Full, TwoThirds, Full)
  }
}

///|
fn draw1fb70_1fb75(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(width)
  ignore(height)

  let eighths = legacy_eighths()
  let n = (cp + 1U - 0x1FB70U).reinterpret_as_int()
  guard n >= 1 && n + 1 < eighths.length() else {
    abort("unreachable legacy computing vertical one eighth block")
  }
  fill(metrics, canvas, eighths[n], eighths[n + 1], Zero, Full)
}

///|
fn draw1fb76_1fb7b(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(width)
  ignore(height)

  let eighths = legacy_eighths()
  let n = (cp + 1U - 0x1FB76U).reinterpret_as_int()
  guard n >= 0 && n + 1 < eighths.length() else {
    abort("unreachable legacy computing horizontal one eighth block")
  }
  fill(metrics, canvas, Zero, Full, eighths[n], eighths[n + 1])
}

///|
fn draw1fb7c_1fb97(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  match cp {
    0x1FB7C => {
      block(metrics, canvas, sprite_draw_alignment_left(), LegacyOneEighth, 1.0)
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        LegacyOneEighth,
      )
    }
    0x1FB7D => {
      block(metrics, canvas, sprite_draw_alignment_left(), LegacyOneEighth, 1.0)
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacyOneEighth,
      )
    }
    0x1FB7E => {
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacyOneEighth,
        1.0,
      )
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacyOneEighth,
      )
    }
    0x1FB7F => {
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacyOneEighth,
        1.0,
      )
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        LegacyOneEighth,
      )
    }
    0x1FB80 => {
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacyOneEighth,
      )
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        LegacyOneEighth,
      )
    }
    0x1FB81 => {
      // Upstream intentionally calls just outside the nominal helper range to
      // address the first and last one-eighth rows.
      draw1fb76_1fb7b(0x1FB75U, canvas, width, height, metrics)
      draw1fb76_1fb7b(0x1FB77U, canvas, width, height, metrics)
      draw1fb76_1fb7b(0x1FB79U, canvas, width, height, metrics)
      draw1fb76_1fb7b(0x1FB7CU, canvas, width, height, metrics)
    }
    0x1FB82 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacyOneQuarter,
      )
    0x1FB83 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacyThreeEighths,
      )
    0x1FB84 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacyFiveEighths,
      )
    0x1FB85 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacyThreeQuarters,
      )
    0x1FB86 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacySevenEighths,
      )
    0x1FB87 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacyOneQuarter,
        1.0,
      )
    0x1FB88 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacyThreeEighths,
        1.0,
      )
    0x1FB89 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacyFiveEighths,
        1.0,
      )
    0x1FB8A =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacyThreeQuarters,
        1.0,
      )
    0x1FB8B =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacySevenEighths,
        1.0,
      )
    0x1FB8C =>
      block_shade(
        metrics,
        canvas,
        sprite_draw_alignment_left(),
        LegacyHalf,
        1.0,
        sprite_draw_shade_medium(),
      )
    0x1FB8D =>
      block_shade(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacyHalf,
        1.0,
        sprite_draw_shade_medium(),
      )
    0x1FB8E =>
      block_shade(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        1.0,
        LegacyHalf,
        sprite_draw_shade_medium(),
      )
    0x1FB8F =>
      block_shade(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        1.0,
        LegacyHalf,
        sprite_draw_shade_medium(),
      )
    0x1FB90 => full_block_shade(metrics, canvas, sprite_draw_shade_medium())
    0x1FB91 => {
      full_block_shade(metrics, canvas, sprite_draw_shade_medium())
      block(metrics, canvas, sprite_draw_alignment_upper(), 1.0, LegacyHalf)
    }
    0x1FB92 => {
      full_block_shade(metrics, canvas, sprite_draw_shade_medium())
      block(metrics, canvas, sprite_draw_alignment_lower(), 1.0, LegacyHalf)
    }
    // Upstream leaves U+1FB93 empty because it is an unallocated hole.
    0x1FB93 => ()
    0x1FB94 => {
      full_block_shade(metrics, canvas, sprite_draw_shade_medium())
      block(metrics, canvas, sprite_draw_alignment_right(), LegacyHalf, 1.0)
    }
    0x1FB95 => checkerboard_fill(metrics, canvas, 0)
    0x1FB96 => checkerboard_fill(metrics, canvas, 1)
    0x1FB97 => {
      canvas.box(
        0,
        (height / 4U).reinterpret_as_int(),
        width.reinterpret_as_int(),
        (2U * height / 4U).reinterpret_as_int(),
        SpriteColor::on(),
      )
      canvas.box(
        0,
        (3U * height / 4U).reinterpret_as_int(),
        width.reinterpret_as_int(),
        height.reinterpret_as_int(),
        SpriteColor::on(),
      )
    }
    _ => abort("unreachable legacy computing block")
  }
}

///|
fn draw1fbaf(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)
  ignore(width)
  ignore(height)

  lines_char(
    metrics,
    canvas,
    sprite_draw_lines(
      up=LineHeavy,
      down=LineHeavy,
      left=LineLight,
      right=LineLight,
    ),
  )
}

///|
fn draw1fbce(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)
  ignore(width)
  ignore(height)

  block(metrics, canvas, sprite_draw_alignment_left(), LegacyTwoThirds, 1.0)
}

///|
fn draw1fbcf(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)
  ignore(width)
  ignore(height)

  block(metrics, canvas, sprite_draw_alignment_left(), LegacyOneThird, 1.0)
}

///|
fn draw1fbe0_1fbef(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(width)
  ignore(height)

  match cp {
    0x1FBE4 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_upper(),
        LegacyHalf,
        LegacyHalf,
      )
    0x1FBE5 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_lower(),
        LegacyHalf,
        LegacyHalf,
      )
    0x1FBE6 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_left(),
        LegacyHalf,
        LegacyHalf,
      )
    0x1FBE7 =>
      block(
        metrics,
        canvas,
        sprite_draw_alignment_right(),
        LegacyHalf,
        LegacyHalf,
      )
    _ => abort("unreachable legacy computing circle/block range")
  }
}

///|
fn checkerboard_fill(
  metrics : Metrics,
  canvas : SpriteCanvas,
  parity : Int,
) -> Unit {
  let float_width = metrics.cell_width.to_double()
  let float_height = metrics.cell_height.to_double()
  let y_size = @math.round(4.0 * (float_height / float_width)).to_int()
  let width = metrics.cell_width.reinterpret_as_int()
  let height = metrics.cell_height.reinterpret_as_int()

  for x in 0..<4 {
    for y in 0..<y_size {
      if (x + y) % 2 == parity {
        let x0 = width * x / 4
        let x1 = width * (x + 1) / 4
        let y0 = height * y / y_size
        let y1 = height * (y + 1) / y_size
        canvas.box(x0, y0, x1, y1, SpriteColor::on())
      }
    }
  }
}
