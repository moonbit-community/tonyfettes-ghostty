///|
fn draw1cc21_1cc2f(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(metrics)

  let quad = (cp - 0x1CC20U).reinterpret_as_int()
  let gap = @cmp.maximum(1U, width / 12U).reinterpret_as_int()
  let mid_gap_x = gap * 2 + (width % 2U).reinterpret_as_int()
  let mid_gap_y = gap * 2 + (height % 2U).reinterpret_as_int()
  let w = (width.reinterpret_as_int() - gap * 2 - mid_gap_x) / 2
  let h = (height.reinterpret_as_int() - gap * 2 - mid_gap_y) / 2

  if (quad & 0x01) != 0 {
    canvas.box(gap, gap, gap + w, gap + h, SpriteColor::on())
  }
  if (quad & 0x02) != 0 {
    canvas.box(
      gap + w + mid_gap_x,
      gap,
      gap + w + mid_gap_x + w,
      gap + h,
      SpriteColor::on(),
    )
  }
  if (quad & 0x04) != 0 {
    canvas.box(
      gap,
      gap + h + mid_gap_y,
      gap + w,
      gap + h + mid_gap_y + h,
      SpriteColor::on(),
    )
  }
  if (quad & 0x08) != 0 {
    canvas.box(
      gap + w + mid_gap_x,
      gap + h + mid_gap_y,
      gap + w + mid_gap_x + w,
      gap + h + mid_gap_y + h,
      SpriteColor::on(),
    )
  }
}

///|
fn draw1ce51_1ce8f(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(metrics)

  let sex = (cp - 0x1CE50U).reinterpret_as_int()
  let gap = @cmp.maximum(1U, width / 12U).reinterpret_as_int()
  let mid_gap_x = gap * 2 + (width % 2U).reinterpret_as_int()
  let y_extra = (height % 3U).reinterpret_as_int()
  let mid_gap_y = gap * 2 + y_extra / 2
  let w = (width.reinterpret_as_int() - gap * 2 - mid_gap_x) / 2
  let h = (height.reinterpret_as_int() - gap * 2 - mid_gap_y * 2) / 3
  let h_m = height.reinterpret_as_int() - gap * 2 - mid_gap_y * 2 - h * 2

  if (sex & 0x01) != 0 {
    canvas.box(gap, gap, gap + w, gap + h, SpriteColor::on())
  }
  if (sex & 0x02) != 0 {
    canvas.box(
      gap + w + mid_gap_x,
      gap,
      gap + w + mid_gap_x + w,
      gap + h,
      SpriteColor::on(),
    )
  }
  if (sex & 0x04) != 0 {
    canvas.box(
      gap,
      gap + h + mid_gap_y,
      gap + w,
      gap + h + mid_gap_y + h_m,
      SpriteColor::on(),
    )
  }
  if (sex & 0x08) != 0 {
    canvas.box(
      gap + w + mid_gap_x,
      gap + h + mid_gap_y,
      gap + w + mid_gap_x + w,
      gap + h + mid_gap_y + h_m,
      SpriteColor::on(),
    )
  }
  if (sex & 0x10) != 0 {
    canvas.box(
      gap,
      gap + h + mid_gap_y + h_m + mid_gap_y,
      gap + w,
      gap + h + mid_gap_y + h_m + mid_gap_y + h,
      SpriteColor::on(),
    )
  }
  if (sex & 0x20) != 0 {
    canvas.box(
      gap + w + mid_gap_x,
      gap + h + mid_gap_y + h_m + mid_gap_y,
      gap + w + mid_gap_x + w,
      gap + h + mid_gap_y + h_m + mid_gap_y + h,
      SpriteColor::on(),
    )
  }
}

///|
fn draw1ce90_1ceaf(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(width)
  ignore(height)
  let q : ReadOnlyArray[SpriteDrawFraction] = [
    Zero,
    OneQuarter,
    TwoQuarters,
    ThreeQuarters,
    Full,
  ]
  match cp {
    0x1CE90 => fill(metrics, canvas, q[0], q[1], q[0], q[1])
    0x1CE91 => fill(metrics, canvas, q[1], q[2], q[0], q[1])
    0x1CE92 => fill(metrics, canvas, q[2], q[3], q[0], q[1])
    0x1CE93 => fill(metrics, canvas, q[3], q[4], q[0], q[1])
    0x1CE94 => fill(metrics, canvas, q[0], q[1], q[1], q[2])
    0x1CE95 => fill(metrics, canvas, q[1], q[2], q[1], q[2])
    0x1CE96 => fill(metrics, canvas, q[2], q[3], q[1], q[2])
    0x1CE97 => fill(metrics, canvas, q[3], q[4], q[1], q[2])
    0x1CE98 => fill(metrics, canvas, q[0], q[1], q[2], q[3])
    0x1CE99 => fill(metrics, canvas, q[1], q[2], q[2], q[3])
    0x1CE9A => fill(metrics, canvas, q[2], q[3], q[2], q[3])
    0x1CE9B => fill(metrics, canvas, q[3], q[4], q[2], q[3])
    0x1CE9C => fill(metrics, canvas, q[0], q[1], q[3], q[4])
    0x1CE9D => fill(metrics, canvas, q[1], q[2], q[3], q[4])
    0x1CE9E => fill(metrics, canvas, q[2], q[3], q[3], q[4])
    0x1CE9F => fill(metrics, canvas, q[3], q[4], q[3], q[4])
    0x1CEA0 => fill(metrics, canvas, q[2], q[4], q[3], q[4])
    0x1CEA1 => fill(metrics, canvas, q[1], q[4], q[3], q[4])
    0x1CEA2 => fill(metrics, canvas, q[0], q[3], q[3], q[4])
    0x1CEA3 => fill(metrics, canvas, q[0], q[2], q[3], q[4])
    0x1CEA4 => fill(metrics, canvas, q[0], q[1], q[2], q[4])
    0x1CEA5 => fill(metrics, canvas, q[0], q[1], q[1], q[4])
    0x1CEA6 => fill(metrics, canvas, q[0], q[1], q[0], q[3])
    0x1CEA7 => fill(metrics, canvas, q[0], q[1], q[0], q[2])
    0x1CEA8 => fill(metrics, canvas, q[0], q[2], q[0], q[1])
    0x1CEA9 => fill(metrics, canvas, q[0], q[3], q[0], q[1])
    0x1CEAA => fill(metrics, canvas, q[1], q[4], q[0], q[1])
    0x1CEAB => fill(metrics, canvas, q[2], q[4], q[0], q[1])
    0x1CEAC => fill(metrics, canvas, q[3], q[4], q[0], q[2])
    0x1CEAD => fill(metrics, canvas, q[3], q[4], q[0], q[3])
    0x1CEAE => fill(metrics, canvas, q[3], q[4], q[1], q[4])
    0x1CEAF => fill(metrics, canvas, q[3], q[4], q[2], q[4])
    _ => abort("unreachable sixteenth block")
  }
}
