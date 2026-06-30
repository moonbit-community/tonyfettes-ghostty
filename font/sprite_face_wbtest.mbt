///|
fn sprite_face_test_metrics() -> Metrics {
  {
    cell_width: 8U,
    cell_height: 16U,
    cell_baseline: 12U,
    underline_position: 14U,
    underline_thickness: 1U,
    strikethrough_position: 8U,
    strikethrough_thickness: 1U,
    overline_position: 0,
    overline_thickness: 1U,
    box_thickness: 1U,
    cursor_thickness: 1U,
    cursor_height: 16U,
    icon_height: 16.0,
    icon_height_single: 12.0,
    face_width: 8.0,
    face_height: 16.0,
    face_y: 0.0,
  }
}

///|
fn sprite_face_atlas_pixel(atlas : Atlas, x : UInt, y : UInt) -> Byte {
  atlas.data[(y * atlas.size + x).reinterpret_as_int()]
}

///|
test "sprite face has codepoint for translated direct ranges" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  assert_true(face.has_codepoint(0x2580U))
  assert_true(face.has_codepoint(0x259FU))
  assert_true(face.has_codepoint(0x2800U))
  assert_true(face.has_codepoint(0x28FFU))
  assert_false(face.has_codepoint(0x257FU))
  assert_false(face.has_codepoint(0x2600U))
  assert_false(face.has_codepoint(0x2900U))
}

///|
test "sprite face unsupported codepoint returns blank glyph" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(32U, Grayscale)
  let glyph = face.render_glyph(atlas, 0x2600U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  guard glyph == sprite_blank_glyph() else {
    fail("expected unsupported sprite to return a blank glyph")
  }
  assert_eq(atlas.modified, 1U)
}

///|
test "sprite face renders full block through direct range dispatch" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(32U, Grayscale)
  let glyph = face.render_glyph(atlas, 0x2588U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(glyph.width, 8U)
  assert_eq(glyph.height, 16U)
  assert_eq(glyph.offset_x, 0)
  assert_eq(glyph.offset_y, 16)
  assert_eq(sprite_face_atlas_pixel(atlas, glyph.atlas_x, glyph.atlas_y), 0xFF)
}

///|
test "sprite face renders block shade alpha values" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(64U, Grayscale)
  let light = face.render_glyph(atlas, 0x2591U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  let medium = face.render_glyph(atlas, 0x2592U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  let dark = face.render_glyph(atlas, 0x2593U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(sprite_face_atlas_pixel(atlas, light.atlas_x, light.atlas_y), 0x40)
  assert_eq(
    sprite_face_atlas_pixel(atlas, medium.atlas_x, medium.atlas_y),
    0x80,
  )
  assert_eq(sprite_face_atlas_pixel(atlas, dark.atlas_x, dark.atlas_y), 0xC0)
}

///|
test "sprite face renders every block element arm" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(128U, Grayscale)
  for cp in 0x2580U..<=0x259FU {
    let glyph = face.render_glyph(atlas, cp, None) catch {
      AtlasFull => fail("unexpected atlas full")
    }
    guard glyph.width > 0U && glyph.height > 0U else {
      fail("expected block element glyph for U+\{cp.to_string(radix=16)}")
    }
  }
}

///|
test "panic block draw rejects codepoint outside block range" {
  let metrics = sprite_face_test_metrics()
  let canvas = SpriteCanvas::new(
    metrics.cell_width,
    metrics.cell_height,
    0U,
    0U,
  )
  draw2580_259f(
    0x257FU,
    canvas,
    metrics.cell_width,
    metrics.cell_height,
    metrics,
  )
}

///|
test "sprite face renders braille empty and full patterns" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(64U, Grayscale)
  let empty = face.render_glyph(atlas, 0x2800U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(empty.width, 0U)
  assert_eq(empty.height, 0U)

  let full = face.render_glyph(atlas, 0x28FFU, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(full.width, 6U)
  assert_eq(full.height, 14U)
  assert_eq(sprite_face_atlas_pixel(atlas, full.atlas_x, full.atlas_y), 0xFF)
}

///|
test "braille draw covers compact layout adjustments" {
  let metrics = sprite_face_test_metrics()
  let compact = SpriteCanvas::new(3U, 11U, 0U, 0U)
  draw2800_28ff(0x28FFU, compact, 3U, 11U, metrics)

  let uneven = SpriteCanvas::new(5U, 14U, 0U, 0U)
  draw2800_28ff(0x28FFU, uneven, 5U, 14U, metrics)
}

///|
test "panic braille draw rejects codepoint below range" {
  let metrics = sprite_face_test_metrics()
  let canvas = SpriteCanvas::new(
    metrics.cell_width,
    metrics.cell_height,
    0U,
    0U,
  )
  draw2800_28ff(
    0x27FFU,
    canvas,
    metrics.cell_width,
    metrics.cell_height,
    metrics,
  )
}

///|
test "panic braille draw rejects codepoint above range" {
  let metrics = sprite_face_test_metrics()
  let canvas = SpriteCanvas::new(
    metrics.cell_width,
    metrics.cell_height,
    0U,
    0U,
  )
  draw2800_28ff(
    0x2900U,
    canvas,
    metrics.cell_width,
    metrics.cell_height,
    metrics,
  )
}

///|
test "sprite face passes wide cell width to braille draw routine" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(64U, Grayscale)
  let normal = face.render_glyph(atlas, 0x28FFU, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  let wide = face.render_glyph(atlas, 0x28FFU, Some(2U)) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_true(wide.width > normal.width)
  assert_eq(wide.height, normal.height)
}
