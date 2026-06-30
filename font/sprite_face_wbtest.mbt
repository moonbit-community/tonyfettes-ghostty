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
  assert_true(face.has_codepoint(Sprite::underline().codepoint()))
  assert_true(face.has_codepoint(Sprite::underline_double().codepoint()))
  assert_false(face.has_codepoint(Sprite::underline_dotted().codepoint()))
  assert_true(face.has_codepoint(Sprite::underline_dashed().codepoint()))
  assert_false(face.has_codepoint(Sprite::underline_curly().codepoint()))
  assert_true(face.has_codepoint(Sprite::strikethrough().codepoint()))
  assert_true(face.has_codepoint(Sprite::overline().codepoint()))
  assert_true(face.has_codepoint(Sprite::cursor_rect().codepoint()))
  assert_true(face.has_codepoint(Sprite::cursor_hollow_rect().codepoint()))
  assert_true(face.has_codepoint(Sprite::cursor_bar().codepoint()))
  assert_true(face.has_codepoint(Sprite::cursor_underline().codepoint()))
  assert_true(face.has_codepoint(0x2500U))
  assert_true(face.has_codepoint(0x256CU))
  assert_false(face.has_codepoint(0x256DU))
  assert_false(face.has_codepoint(0x2573U))
  assert_true(face.has_codepoint(0x2574U))
  assert_true(face.has_codepoint(0x257FU))
  assert_true(face.has_codepoint(0x2580U))
  assert_true(face.has_codepoint(0x259FU))
  assert_true(face.has_codepoint(0x2800U))
  assert_true(face.has_codepoint(0x28FFU))
  assert_true(face.has_codepoint(0x1CC21U))
  assert_true(face.has_codepoint(0x1CC2FU))
  assert_true(face.has_codepoint(0x1CE51U))
  assert_true(face.has_codepoint(0x1CE8FU))
  assert_true(face.has_codepoint(0x1CE90U))
  assert_true(face.has_codepoint(0x1CEAFU))
  assert_false(face.has_codepoint(0x24FFU))
  assert_false(face.has_codepoint(0x2600U))
  assert_false(face.has_codepoint(0x2900U))
  assert_false(face.has_codepoint(0x1CC20U))
  assert_false(face.has_codepoint(0x1CC30U))
  assert_false(face.has_codepoint(0x1CD00U))
  assert_false(face.has_codepoint(0x1CE50U))
  assert_false(face.has_codepoint(0x1CEB0U))
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
test "sprite face deferred special codepoints return blank glyph" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(32U, Grayscale)
  let dotted = face.render_glyph(
    atlas,
    Sprite::underline_dotted().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  let curly = face.render_glyph(
    atlas,
    Sprite::underline_curly().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  guard dotted == sprite_blank_glyph() && curly == sprite_blank_glyph() else {
    fail("expected deferred special sprites to remain blank")
  }
}

///|
test "sprite face deferred box drawing codepoints return blank glyph" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(32U, Grayscale)
  for cp in 0x256DU..<=0x2573U {
    assert_false(face.has_codepoint(cp))
    let glyph = face.render_glyph(atlas, cp, None) catch {
      AtlasFull => fail("unexpected atlas full")
    }
    guard glyph == sprite_blank_glyph() else {
      fail("expected deferred box drawing sprite to remain blank")
    }
  }
}

///|
test "sprite face deferred legacy supplement codepoints return blank glyph" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(32U, Grayscale)
  let deferred : ReadOnlyArray[UInt] = [
    0x1CC30U, 0x1CD00U, 0x1CE0BU, 0x1CE0CU, 0x1CE16U,
  ]
  for cp in deferred {
    assert_false(face.has_codepoint(cp))
    let glyph = face.render_glyph(atlas, cp, None) catch {
      AtlasFull => fail("unexpected atlas full")
    }
    guard glyph == sprite_blank_glyph() else {
      fail("expected deferred legacy supplement sprite to remain blank")
    }
  }
}

///|
test "box draw thickness height matches upstream" {
  assert_eq(ThicknessLight.height(4U), 4U)
  assert_eq(ThicknessHeavy.height(4U), 8U)
}

///|
test "box dash fallback draws solid centered lines" {
  let metrics = {
    ..sprite_face_test_metrics(),
    cell_width: 3U,
    cell_height: 3U,
  }
  let horizontal = SpriteCanvas::new(3U, 3U, 0U, 0U)
  dash_horizontal(
    metrics,
    horizontal,
    2U,
    ThicknessLight.height(metrics.box_thickness),
    ThicknessLight.height(metrics.box_thickness),
  )
  assert_eq(horizontal.data[3], 0xFF)
  assert_eq(horizontal.data[4], 0xFF)
  assert_eq(horizontal.data[5], 0xFF)

  let vertical = SpriteCanvas::new(3U, 3U, 0U, 0U)
  dash_vertical(
    metrics,
    vertical,
    2U,
    ThicknessLight.height(metrics.box_thickness),
    ThicknessLight.height(metrics.box_thickness),
  )
  assert_eq(vertical.data[1], 0xFF)
  assert_eq(vertical.data[4], 0xFF)
  assert_eq(vertical.data[7], 0xFF)
}

///|
test "panic horizontal box dash rejects unsupported count" {
  let metrics = sprite_face_test_metrics()
  let canvas = SpriteCanvas::new(
    metrics.cell_width,
    metrics.cell_height,
    0U,
    0U,
  )
  dash_horizontal(
    metrics,
    canvas,
    1U,
    ThicknessLight.height(metrics.box_thickness),
    ThicknessLight.height(metrics.box_thickness),
  )
}

///|
test "panic vertical box dash rejects unsupported count" {
  let metrics = sprite_face_test_metrics()
  let canvas = SpriteCanvas::new(
    metrics.cell_width,
    metrics.cell_height,
    0U,
    0U,
  )
  dash_vertical(
    metrics,
    canvas,
    5U,
    ThicknessLight.height(metrics.box_thickness),
    ThicknessLight.height(metrics.box_thickness),
  )
}

///|
test "sprite face renders simple box drawing through direct dispatch" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(128U, Grayscale)

  let horizontal = face.render_glyph(atlas, 0x2500U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(horizontal.width, 8U)
  assert_eq(horizontal.height, 1U)
  assert_eq(horizontal.offset_x, 0)
  assert_eq(horizontal.offset_y, 9)
  assert_eq(
    sprite_face_atlas_pixel(atlas, horizontal.atlas_x, horizontal.atlas_y),
    0xFF,
  )

  let vertical = face.render_glyph(atlas, 0x2502U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(vertical.width, 1U)
  assert_eq(vertical.height, 16U)
  assert_eq(vertical.offset_x, 3)
  assert_eq(vertical.offset_y, 16)
  assert_eq(
    sprite_face_atlas_pixel(atlas, vertical.atlas_x, vertical.atlas_y),
    0xFF,
  )
}

///|
test "sprite face renders dashed and double box drawing" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(128U, Grayscale)

  let dashed = face.render_glyph(atlas, 0x2504U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(dashed.width, 7U)
  assert_eq(dashed.height, 1U)
  assert_eq(
    sprite_face_atlas_pixel(atlas, dashed.atlas_x, dashed.atlas_y),
    0xFF,
  )
  assert_eq(
    sprite_face_atlas_pixel(atlas, dashed.atlas_x + 2U, dashed.atlas_y),
    0x00,
  )
  assert_eq(
    sprite_face_atlas_pixel(atlas, dashed.atlas_x + 3U, dashed.atlas_y),
    0xFF,
  )

  let double = face.render_glyph(atlas, 0x2550U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(double.width, 8U)
  assert_eq(double.height, 3U)
  assert_eq(
    sprite_face_atlas_pixel(atlas, double.atlas_x, double.atlas_y),
    0xFF,
  )
  assert_eq(
    sprite_face_atlas_pixel(atlas, double.atlas_x, double.atlas_y + 1U),
    0x00,
  )
  assert_eq(
    sprite_face_atlas_pixel(atlas, double.atlas_x, double.atlas_y + 2U),
    0xFF,
  )
}

///|
test "sprite face renders every implemented box drawing arm" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(1024U, Grayscale)
  for cp in 0x2500U..<=0x256CU {
    let glyph = face.render_glyph(atlas, cp, None) catch {
      AtlasFull => fail("unexpected atlas full")
    }
    guard glyph.width > 0U && glyph.height > 0U else {
      fail("expected box drawing glyph for U+\{cp.to_string(radix=16)}")
    }
  }
  for cp in 0x2574U..<=0x257FU {
    let glyph = face.render_glyph(atlas, cp, None) catch {
      AtlasFull => fail("unexpected atlas full")
    }
    guard glyph.width > 0U && glyph.height > 0U else {
      fail("expected box drawing glyph for U+\{cp.to_string(radix=16)}")
    }
  }
}

///|
test "panic box draw rejects deferred arc and diagonal range" {
  let metrics = sprite_face_test_metrics()
  let canvas = SpriteCanvas::new(
    metrics.cell_width,
    metrics.cell_height,
    0U,
    0U,
  )
  draw2500_257f(
    0x256DU,
    canvas,
    metrics.cell_width,
    metrics.cell_height,
    metrics,
  )
}

///|
test "panic box draw rejects codepoint outside range" {
  let metrics = sprite_face_test_metrics()
  let canvas = SpriteCanvas::new(
    metrics.cell_width,
    metrics.cell_height,
    0U,
    0U,
  )
  draw2500_257f(
    0x24FFU,
    canvas,
    metrics.cell_width,
    metrics.cell_height,
    metrics,
  )
}

///|
test "special draw saturating add matches zig saturating arithmetic" {
  assert_eq(saturating_add_uint(1U, 2U), 3U)
  assert_eq(saturating_add_uint(0xFFFFFFFFU, 1U), 0xFFFFFFFFU)
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
test "sprite face renders legacy supplement pure block geometry" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(128U, Grayscale)

  let separated_quadrant = face.render_glyph(atlas, 0x1CC21U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(separated_quadrant.width, 2U)
  assert_eq(separated_quadrant.height, 6U)
  assert_eq(separated_quadrant.offset_x, 1)
  assert_eq(separated_quadrant.offset_y, 15)
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      separated_quadrant.atlas_x,
      separated_quadrant.atlas_y,
    ),
    0xFF,
  )

  let separated_sextant = face.render_glyph(atlas, 0x1CE51U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(separated_sextant.width, 2U)
  assert_eq(separated_sextant.height, 3U)
  assert_eq(separated_sextant.offset_x, 1)
  assert_eq(separated_sextant.offset_y, 15)
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      separated_sextant.atlas_x,
      separated_sextant.atlas_y,
    ),
    0xFF,
  )

  let sixteenth = face.render_glyph(atlas, 0x1CE90U, None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(sixteenth.width, 2U)
  assert_eq(sixteenth.height, 4U)
  assert_eq(sixteenth.offset_x, 0)
  assert_eq(sixteenth.offset_y, 16)
  assert_eq(
    sprite_face_atlas_pixel(atlas, sixteenth.atlas_x, sixteenth.atlas_y),
    0xFF,
  )
}

///|
test "sprite face renders every pure legacy supplement arm" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(512U, Grayscale)
  for cp in 0x1CC21U..<=0x1CC2FU {
    let glyph = face.render_glyph(atlas, cp, None) catch {
      AtlasFull => fail("unexpected atlas full")
    }
    guard glyph.width > 0U && glyph.height > 0U else {
      fail("expected separated quadrant glyph for U+\{cp.to_string(radix=16)}")
    }
  }
  for cp in 0x1CE51U..<=0x1CE8FU {
    let glyph = face.render_glyph(atlas, cp, None) catch {
      AtlasFull => fail("unexpected atlas full")
    }
    guard glyph.width > 0U && glyph.height > 0U else {
      fail("expected separated sextant glyph for U+\{cp.to_string(radix=16)}")
    }
  }
  for cp in 0x1CE90U..<=0x1CEAFU {
    let glyph = face.render_glyph(atlas, cp, None) catch {
      AtlasFull => fail("unexpected atlas full")
    }
    guard glyph.width > 0U && glyph.height > 0U else {
      fail("expected sixteenth block glyph for U+\{cp.to_string(radix=16)}")
    }
  }
}

///|
test "panic sixteenth block draw rejects codepoint outside range" {
  let metrics = sprite_face_test_metrics()
  let canvas = SpriteCanvas::new(
    metrics.cell_width,
    metrics.cell_height,
    0U,
    0U,
  )
  draw1ce90_1ceaf(
    0x1CE8FU,
    canvas,
    metrics.cell_width,
    metrics.cell_height,
    metrics,
  )
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

///|
test "sprite face renders rect only special sprites" {
  let face = SpriteFace::new(sprite_face_test_metrics())
  let atlas = Atlas::new(256U, Grayscale)

  let underline = face.render_glyph(
    atlas,
    Sprite::underline().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(underline.width, 8U)
  assert_eq(underline.height, 1U)
  assert_eq(
    sprite_face_atlas_pixel(atlas, underline.atlas_x, underline.atlas_y),
    0xFF,
  )

  let underline_double = face.render_glyph(
    atlas,
    Sprite::underline_double().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(underline_double.width, 8U)
  assert_eq(underline_double.height, 3U)
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      underline_double.atlas_x,
      underline_double.atlas_y,
    ),
    0xFF,
  )
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      underline_double.atlas_x,
      underline_double.atlas_y + 1U,
    ),
    0x00,
  )
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      underline_double.atlas_x,
      underline_double.atlas_y + 2U,
    ),
    0xFF,
  )

  let underline_dashed = face.render_glyph(
    atlas,
    Sprite::underline_dashed().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(underline_dashed.width, 9U)
  assert_eq(underline_dashed.height, 1U)
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      underline_dashed.atlas_x,
      underline_dashed.atlas_y,
    ),
    0xFF,
  )
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      underline_dashed.atlas_x + 3U,
      underline_dashed.atlas_y,
    ),
    0x00,
  )
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      underline_dashed.atlas_x + 6U,
      underline_dashed.atlas_y,
    ),
    0xFF,
  )
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      underline_dashed.atlas_x + 8U,
      underline_dashed.atlas_y,
    ),
    0xFF,
  )

  let strikethrough = face.render_glyph(
    atlas,
    Sprite::strikethrough().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(strikethrough.width, 8U)
  assert_eq(strikethrough.height, 1U)

  let overline = face.render_glyph(atlas, Sprite::overline().codepoint(), None) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(overline.width, 8U)
  assert_eq(overline.height, 1U)

  let cursor_rect = face.render_glyph(
    atlas,
    Sprite::cursor_rect().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(cursor_rect.width, 8U)
  assert_eq(cursor_rect.height, 16U)
  assert_eq(
    sprite_face_atlas_pixel(atlas, cursor_rect.atlas_x, cursor_rect.atlas_y),
    0xFF,
  )

  let cursor_hollow_rect = face.render_glyph(
    atlas,
    Sprite::cursor_hollow_rect().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(cursor_hollow_rect.width, 8U)
  assert_eq(cursor_hollow_rect.height, 16U)
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      cursor_hollow_rect.atlas_x,
      cursor_hollow_rect.atlas_y,
    ),
    0xFF,
  )
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      cursor_hollow_rect.atlas_x + 1U,
      cursor_hollow_rect.atlas_y + 1U,
    ),
    0x00,
  )

  let cursor_bar = face.render_glyph(
    atlas,
    Sprite::cursor_bar().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(cursor_bar.width, 1U)
  assert_eq(cursor_bar.height, 16U)
  assert_eq(
    sprite_face_atlas_pixel(atlas, cursor_bar.atlas_x, cursor_bar.atlas_y),
    0xFF,
  )

  let cursor_underline = face.render_glyph(
    atlas,
    Sprite::cursor_underline().codepoint(),
    None,
  ) catch {
    AtlasFull => fail("unexpected atlas full")
  }
  assert_eq(cursor_underline.width, 8U)
  assert_eq(cursor_underline.height, 1U)
  assert_eq(
    sprite_face_atlas_pixel(
      atlas,
      cursor_underline.atlas_x,
      cursor_underline.atlas_y,
    ),
    0xFF,
  )
}
