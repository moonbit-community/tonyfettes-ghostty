///|
fn draw2800_28ff(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(metrics)

  let mut w = @cmp.minimum(width / 4U, height / 8U).reinterpret_as_int()
  let mut x_spacing = (width / 4U).reinterpret_as_int()
  let mut y_spacing = (height / 8U).reinterpret_as_int()
  let mut x_margin = x_spacing / 2
  let mut y_margin = y_spacing / 2

  let mut x_px_left = width.reinterpret_as_int() -
    2 * x_margin -
    x_spacing -
    2 * w
  let mut y_px_left = height.reinterpret_as_int() -
    2 * y_margin -
    3 * y_spacing -
    4 * w

  if x_px_left >= 2 && y_px_left >= 4 && w == 0 {
    w += 1
    x_px_left -= 2
    y_px_left -= 4
  }

  if x_px_left >= 2 && x_margin == 0 {
    x_margin += 1
    x_px_left -= 2
  }
  if y_px_left >= 2 && y_margin == 0 {
    y_margin += 1
    y_px_left -= 2
  }

  if x_px_left >= 1 {
    x_spacing += 1
    x_px_left -= 1
  }
  if y_px_left >= 3 {
    y_spacing += 1
    y_px_left -= 3
  }

  if x_px_left >= 2 {
    x_margin += 1
    x_px_left -= 2
  }
  if y_px_left >= 2 {
    y_margin += 1
    y_px_left -= 2
  }

  if x_px_left >= 2 && y_px_left >= 4 {
    w += 1
    x_px_left -= 2
    y_px_left -= 4
  }

  guard x_px_left <= 1 || y_px_left <= 1 else {
    abort("braille layout should leave at most one axis with spare pixels")
  }
  guard 2 * x_margin + 2 * w + x_spacing <= width.reinterpret_as_int() else {
    abort("braille layout exceeds width")
  }
  guard 2 * y_margin + 4 * w + 3 * y_spacing <= height.reinterpret_as_int() else {
    abort("braille layout exceeds height")
  }

  let x : ReadOnlyArray[Int] = [x_margin, x_margin + w + x_spacing]
  let y : ReadOnlyArray[Int] = [
    y_margin,
    y_margin + w + y_spacing,
    y_margin + 2 * w + 2 * y_spacing,
    y_margin + 3 * w + 3 * y_spacing,
  ]

  guard cp >= 0x2800U else { abort("braille codepoint below range") }
  guard cp <= 0x28FFU else { abort("braille codepoint above range") }
  let bits = (cp & 0xFFU).reinterpret_as_int()

  if (bits & 0x01) != 0 {
    canvas.box(x[0], y[0], x[0] + w, y[0] + w, SpriteColor::on())
  }
  if (bits & 0x02) != 0 {
    canvas.box(x[0], y[1], x[0] + w, y[1] + w, SpriteColor::on())
  }
  if (bits & 0x04) != 0 {
    canvas.box(x[0], y[2], x[0] + w, y[2] + w, SpriteColor::on())
  }
  if (bits & 0x40) != 0 {
    canvas.box(x[0], y[3], x[0] + w, y[3] + w, SpriteColor::on())
  }
  if (bits & 0x08) != 0 {
    canvas.box(x[1], y[0], x[1] + w, y[0] + w, SpriteColor::on())
  }
  if (bits & 0x10) != 0 {
    canvas.box(x[1], y[1], x[1] + w, y[1] + w, SpriteColor::on())
  }
  if (bits & 0x20) != 0 {
    canvas.box(x[1], y[2], x[1] + w, y[2] + w, SpriteColor::on())
  }
  if (bits & 0x80) != 0 {
    canvas.box(x[1], y[3], x[1] + w, y[3] + w, SpriteColor::on())
  }
}
