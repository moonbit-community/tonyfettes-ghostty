///|
fn canvas_index(canvas : SpriteCanvas, x : UInt, y : UInt) -> Int {
  (y * canvas.width + x).reinterpret_as_int()
}

///|
test "sprite codepoint mapping" {
  assert_eq(Sprite::start(), 0x110000U)
  assert_eq(Sprite::end(), 0xFFFFFFFFU)
  assert_eq(Sprite::underline().codepoint(), Sprite::start())
  assert_eq(Sprite::underline_double().codepoint(), Sprite::start() + 1U)
  assert_eq(Sprite::underline_dotted().codepoint(), Sprite::start() + 2U)
  assert_eq(Sprite::underline_dashed().codepoint(), Sprite::start() + 3U)
  assert_eq(Sprite::underline_curly().codepoint(), Sprite::start() + 4U)
  assert_eq(Sprite::strikethrough().codepoint(), Sprite::start() + 5U)
  assert_eq(Sprite::overline().codepoint(), Sprite::start() + 6U)
  assert_eq(Sprite::cursor_rect().codepoint(), Sprite::start() + 7U)
  assert_eq(Sprite::cursor_hollow_rect().codepoint(), Sprite::start() + 8U)
  assert_eq(Sprite::cursor_bar().codepoint(), Sprite::start() + 9U)
  assert_eq(Sprite::cursor_underline().codepoint(), Sprite::start() + 10U)
  guard Sprite::from_codepoint(Sprite::cursor_bar().codepoint()).map(s => {
      s.codepoint()
    }) ==
    Some(Sprite::cursor_bar().codepoint()) else {
    fail("expected cursor bar sprite mapping")
  }
  guard Sprite::from_codepoint(0x10FFFFU) == None else {
    fail("expected max Unicode codepoint to be outside sprite range")
  }
  guard Sprite::from_codepoint(Sprite::start() + 11U) == None else {
    fail("expected unknown sprite codepoint to be rejected")
  }
}

///|
test "sprite color values" {
  assert_eq(SpriteColor::on().value(), 0xFF)
  assert_eq(SpriteColor::off().value(), 0x00)
  assert_eq(SpriteColor::from_byte(0x40).value(), 0x40)
}

///|
test "sprite box rect normalizes endpoints" {
  let box : SpriteBox[Int] = { p0: { x: 5, y: 2 }, p1: { x: 1, y: 9 } }
  let expected : SpriteRect[Int] = { x: 1, y: 2, width: 4, height: 7 }
  guard box.rect() == expected else {
    fail("expected normalized sprite rectangle")
  }
}

///|
test "sprite canvas new includes padding" {
  let canvas = SpriteCanvas::new(4U, 3U, 1U, 2U)
  assert_eq(canvas.width, 6U)
  assert_eq(canvas.height, 7U)
  assert_eq(canvas.data.length(), 42)
  guard !canvas.data.contains(1) else { fail("expected zeroed alpha surface") }
}

///|
test "sprite canvas pixel writes through padding transform" {
  let canvas = SpriteCanvas::new(4U, 3U, 1U, 2U)
  canvas.pixel(0, 0, SpriteColor::on())
  assert_eq(canvas.data[canvas_index(canvas, 1U, 2U)], 0xFF)
  canvas.pixel(-1, -2, SpriteColor::from_byte(0x40))
  assert_eq(canvas.data[canvas_index(canvas, 0U, 0U)], 0x40)
}

///|
test "sprite canvas pixel clips outside surface" {
  let canvas = SpriteCanvas::new(2U, 2U, 0U, 0U)
  canvas.pixel(-1, 0, SpriteColor::on())
  canvas.pixel(0, -1, SpriteColor::on())
  canvas.pixel(2, 0, SpriteColor::on())
  canvas.pixel(0, 2, SpriteColor::on())
  guard !canvas.data.contains(0xFF) else {
    fail("out-of-surface pixels should not modify alpha data")
  }
}

///|
test "sprite canvas rect and box draw filled rectangles" {
  let canvas = SpriteCanvas::new(5U, 4U, 1U, 1U)
  canvas.rect({ x: 1, y: 1, width: 2, height: 2 }, SpriteColor::on())
  assert_eq(canvas.data[canvas_index(canvas, 2U, 2U)], 0xFF)
  assert_eq(canvas.data[canvas_index(canvas, 3U, 3U)], 0xFF)
  assert_eq(canvas.data[canvas_index(canvas, 1U, 1U)], 0x00)

  canvas.box(4, 3, 2, 2, SpriteColor::from_byte(0x80))
  assert_eq(canvas.data[canvas_index(canvas, 3U, 3U)], 0x80)
  assert_eq(canvas.data[canvas_index(canvas, 4U, 3U)], 0x80)
  assert_eq(canvas.data[canvas_index(canvas, 4U, 4U)], 0x00)
}

///|
test "sprite canvas write atlas trims transparent border" {
  let canvas = SpriteCanvas::new(4U, 3U, 1U, 1U)
  canvas.pixel(1, 1, SpriteColor::on())
  let atlas = Atlas::new(32U, Grayscale)
  let region = canvas.write_atlas(atlas) catch {
    AtlasFull => fail("expected sprite atlas region")
  }
  let expected : AtlasRegion = { x: 1U, y: 1U, width: 1U, height: 1U }
  guard region == expected else {
    fail("expected trimmed single-pixel sprite atlas region")
  }
  assert_eq(canvas.clip_top, 2U)
  assert_eq(canvas.clip_left, 2U)
  assert_eq(canvas.clip_right, 3U)
  assert_eq(canvas.clip_bottom, 2U)
  assert_eq(atlas.data[(atlas.size + 1U).reinterpret_as_int()], 0xFF)
}

///|
test "sprite canvas write atlas preserves trimmed multi-byte alpha" {
  let canvas = SpriteCanvas::new(3U, 3U, 1U, 1U)
  canvas.pixel(0, 0, SpriteColor::from_byte(0x40))
  canvas.pixel(1, 0, SpriteColor::from_byte(0x80))
  canvas.pixel(0, 1, SpriteColor::from_byte(0xC0))
  canvas.pixel(1, 1, SpriteColor::on())
  let atlas = Atlas::new(32U, Grayscale)
  let region = canvas.write_atlas(atlas) catch {
    AtlasFull => fail("expected sprite atlas region")
  }
  let expected : AtlasRegion = { x: 1U, y: 1U, width: 2U, height: 2U }
  guard region == expected else {
    fail("expected trimmed 2x2 sprite atlas region")
  }
  assert_eq(atlas.data[33], 0x40)
  assert_eq(atlas.data[34], 0x80)
  assert_eq(atlas.data[65], 0xC0)
  assert_eq(atlas.data[66], 0xFF)
}

///|
test "sprite canvas write atlas all transparent returns empty region" {
  let canvas = SpriteCanvas::new(2U, 2U, 0U, 0U)
  let atlas = Atlas::new(8U, Grayscale)
  let modified = atlas.modified
  let region = canvas.write_atlas(atlas) catch {
    AtlasFull => fail("expected empty sprite atlas region")
  }
  let expected : AtlasRegion = { x: 0U, y: 0U, width: 0U, height: 0U }
  guard region == expected else { fail("expected empty sprite atlas region") }
  assert_eq(atlas.modified, modified)
}

///|
test "sprite canvas clear clipping regions" {
  let canvas = SpriteCanvas::new(3U, 2U, 1U, 1U)
  canvas.data.fill(5)
  canvas.clip_top = 1U
  canvas.clip_left = 1U
  canvas.clip_right = 1U
  canvas.clip_bottom = 1U
  canvas.clear_clipping_regions()
  for y in 0..<canvas.height.reinterpret_as_int() {
    for x in 0..<canvas.width.reinterpret_as_int() {
      let value = canvas.data[y * canvas.width.reinterpret_as_int() + x]
      if x > 0 &&
        x < canvas.width.reinterpret_as_int() - 1 &&
        y > 0 &&
        y < canvas.height.reinterpret_as_int() - 1 {
        assert_eq(value, 5)
      } else {
        assert_eq(value, 0)
      }
    }
  }
}

///|
test "sprite canvas invert" {
  let canvas = SpriteCanvas::new(3U, 1U, 0U, 0U)
  canvas.data[0] = 0x00
  canvas.data[1] = 0x40
  canvas.data[2] = 0xFF
  canvas.invert()
  assert_eq(canvas.data[0], 0xFF)
  assert_eq(canvas.data[1], 0xBF)
  assert_eq(canvas.data[2], 0x00)
}

///|
test "sprite canvas flip horizontal" {
  let canvas = SpriteCanvas::new(3U, 2U, 0U, 0U)
  canvas.data = [1, 2, 3, 4, 5, 6]
  canvas.clip_left = 1U
  canvas.clip_right = 2U
  canvas.flip_horizontal()
  guard canvas.data == [3, 2, 1, 6, 5, 4] else {
    fail("expected horizontally flipped alpha data")
  }
  assert_eq(canvas.clip_left, 2U)
  assert_eq(canvas.clip_right, 1U)
}

///|
test "sprite canvas flip vertical" {
  let canvas = SpriteCanvas::new(2U, 3U, 0U, 0U)
  canvas.data = [1, 2, 3, 4, 5, 6]
  canvas.clip_top = 1U
  canvas.clip_bottom = 2U
  canvas.flip_vertical()
  guard canvas.data == [5, 6, 3, 4, 1, 2] else {
    fail("expected vertically flipped alpha data")
  }
  assert_eq(canvas.clip_top, 2U)
  assert_eq(canvas.clip_bottom, 1U)
}

///|
test "panic sprite canvas write atlas requires grayscale atlas" {
  let canvas = SpriteCanvas::new(2U, 2U, 0U, 0U)
  let atlas = Atlas::new(8U, Bgr)
  ignore(canvas.write_atlas(atlas))
}
