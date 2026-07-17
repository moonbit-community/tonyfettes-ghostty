///|
fn underline(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)

  let y = @cmp.minimum(
    metrics.underline_position,
    saturating_sub_uint(
      saturating_add_uint(height, canvas.padding_y),
      metrics.underline_thickness,
    ),
  )

  canvas.rect(
    {
      x: 0,
      y: y.reinterpret_as_int(),
      width: width.reinterpret_as_int(),
      height: metrics.underline_thickness.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
}

///|
fn underline_double(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)

  let y = @cmp.minimum(
    metrics.underline_position,
    saturating_sub_uint(
      saturating_add_uint(height, canvas.padding_y),
      2U * metrics.underline_thickness,
    ),
  )

  canvas.rect(
    {
      x: 0,
      y: saturating_sub_uint(y, metrics.underline_thickness).reinterpret_as_int(),
      width: width.reinterpret_as_int(),
      height: metrics.underline_thickness.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
  canvas.rect(
    {
      x: 0,
      y: (y + metrics.underline_thickness).reinterpret_as_int(),
      width: width.reinterpret_as_int(),
      height: metrics.underline_thickness.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
}

///|
fn underline_dashed(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)

  let y = @cmp.minimum(
    metrics.underline_position,
    saturating_sub_uint(
      saturating_add_uint(height, canvas.padding_y),
      metrics.underline_thickness,
    ),
  )

  let dash_width = width / 3U + 1U
  let dash_count = width / dash_width + 1U
  let mut i = 0U
  while i < dash_count {
    let x = i * dash_width
    canvas.rect(
      {
        x: x.reinterpret_as_int(),
        y: y.reinterpret_as_int(),
        width: dash_width.reinterpret_as_int(),
        height: metrics.underline_thickness.reinterpret_as_int(),
      },
      SpriteColor::on(),
    )
    i += 2U
  }
}

///|
fn strikethrough(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)
  ignore(height)

  canvas.rect(
    {
      x: 0,
      y: metrics.strikethrough_position.reinterpret_as_int(),
      width: width.reinterpret_as_int(),
      height: metrics.strikethrough_thickness.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
}

///|
fn overline(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)
  ignore(height)

  let y = @cmp.maximum(
    metrics.overline_position,
    -canvas.padding_y.reinterpret_as_int(),
  )

  canvas.rect(
    {
      x: 0,
      y,
      width: width.reinterpret_as_int(),
      height: metrics.overline_thickness.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
}

///|
fn cursor_rect(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)
  ignore(metrics)

  canvas.rect(
    {
      x: 0,
      y: 0,
      width: width.reinterpret_as_int(),
      height: height.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
}

///|
fn cursor_hollow_rect(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)

  canvas.rect(
    {
      x: 0,
      y: 0,
      width: width.reinterpret_as_int(),
      height: height.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
  canvas.rect(
    {
      x: metrics.cursor_thickness.reinterpret_as_int(),
      y: metrics.cursor_thickness.reinterpret_as_int(),
      width: saturating_sub_uint(width, metrics.cursor_thickness * 2U).reinterpret_as_int(),
      height: saturating_sub_uint(height, metrics.cursor_thickness * 2U).reinterpret_as_int(),
    },
    SpriteColor::off(),
  )
}

///|
fn cursor_bar(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)
  ignore(width)

  canvas.rect(
    {
      x: -((metrics.cursor_thickness + 1U) / 2U).reinterpret_as_int(),
      y: 0,
      width: metrics.cursor_thickness.reinterpret_as_int(),
      height: height.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
}

///|
fn cursor_underline(
  cp : UInt,
  canvas : SpriteCanvas,
  width : UInt,
  height : UInt,
  metrics : Metrics,
) -> Unit {
  ignore(cp)

  let y = @cmp.minimum(
    metrics.underline_position,
    saturating_sub_uint(
      saturating_add_uint(height, canvas.padding_y),
      metrics.underline_thickness,
    ),
  )

  canvas.rect(
    {
      x: 0,
      y: y.reinterpret_as_int(),
      width: width.reinterpret_as_int(),
      height: metrics.cursor_thickness.reinterpret_as_int(),
    },
    SpriteColor::on(),
  )
}

///|
fn saturating_add_uint(left : UInt, right : UInt) -> UInt {
  if left > 0xFFFFFFFFU - right {
    0xFFFFFFFFU
  } else {
    left + right
  }
}
