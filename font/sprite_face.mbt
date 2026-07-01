///|
priv struct SpriteDrawFn((UInt, SpriteCanvas, UInt, UInt, Metrics) -> Unit)

///|
#warnings("-unused_value")
priv struct SpriteFace {
  metrics : Metrics
}

///|
#warnings("-unused_value")
fn SpriteFace::new(metrics : Metrics) -> SpriteFace {
  { metrics, }
}

///|
#warnings("-unused_value")
fn SpriteFace::has_codepoint(self : SpriteFace, cp : UInt) -> Bool {
  ignore(self)
  match get_draw_fn(cp) {
    Some(_) => true
    None => false
  }
}

///|
fn get_draw_fn(cp : UInt) -> SpriteDrawFn? {
  match cp {
    0x110000 => Some(SpriteDrawFn(underline))
    0x110001 => Some(SpriteDrawFn(underline_double))
    0x110003 => Some(SpriteDrawFn(underline_dashed))
    0x110005 => Some(SpriteDrawFn(strikethrough))
    0x110006 => Some(SpriteDrawFn(overline))
    0x110007 => Some(SpriteDrawFn(cursor_rect))
    0x110008 => Some(SpriteDrawFn(cursor_hollow_rect))
    0x110009 => Some(SpriteDrawFn(cursor_bar))
    0x11000A => Some(SpriteDrawFn(cursor_underline))
    0x2500..=0x256C => Some(SpriteDrawFn(draw2500_257f))
    0x2574..=0x257F => Some(SpriteDrawFn(draw2500_257f))
    0x2580..=0x259F => Some(SpriteDrawFn(draw2580_259f))
    0x2800..=0x28FF => Some(SpriteDrawFn(draw2800_28ff))
    0x1CC1B..=0x1CC1E => Some(SpriteDrawFn(draw1cc1b_1cc1e))
    0x1CC21..=0x1CC2F => Some(SpriteDrawFn(draw1cc21_1cc2f))
    0x1CD00..=0x1CDE5 => Some(SpriteDrawFn(draw1cd00_1cde5))
    0x1CE16..=0x1CE19 => Some(SpriteDrawFn(draw1ce16_1ce19))
    0x1CE51..=0x1CE8F => Some(SpriteDrawFn(draw1ce51_1ce8f))
    0x1CE90..=0x1CEAF => Some(SpriteDrawFn(draw1ce90_1ceaf))
    0x1FB00..=0x1FB3B => Some(SpriteDrawFn(draw1fb00_1fb3b))
    0x1FB70..=0x1FB75 => Some(SpriteDrawFn(draw1fb70_1fb75))
    0x1FB76..=0x1FB7B => Some(SpriteDrawFn(draw1fb76_1fb7b))
    0x1FB7C..=0x1FB97 => Some(SpriteDrawFn(draw1fb7c_1fb97))
    0x1FBAF => Some(SpriteDrawFn(draw1fbaf))
    0x1FBCE => Some(SpriteDrawFn(draw1fbce))
    0x1FBCF => Some(SpriteDrawFn(draw1fbcf))
    0x1FBE4..=0x1FBE7 => Some(SpriteDrawFn(draw1fbe0_1fbef))
    _ => None
  }
}

///|
#warnings("-unused_value")
fn SpriteFace::render_glyph(
  self : SpriteFace,
  atlas : Atlas,
  cp : UInt,
  cell_width : UInt?,
) -> Glyph raise AtlasError {
  let metrics = self.metrics
  let width = match cell_width.unwrap_or(1U) {
    0U | 1U => metrics.cell_width
    width => metrics.cell_width * width
  }
  let height = metrics.cell_height
  let padding_x = width / 4U
  let padding_y = height / 4U
  let canvas = SpriteCanvas::new(width, height, padding_x, padding_y)

  let draw_fn = match get_draw_fn(cp) {
    Some(draw_fn) => draw_fn
    None => return sprite_blank_glyph()
  }
  draw_fn(cp, canvas, width, height, metrics)

  let region = canvas.write_atlas(atlas)
  {
    width: region.width,
    height: region.height,
    offset_x: canvas.clip_left.reinterpret_as_int() -
    padding_x.reinterpret_as_int(),
    offset_y: (region.height + canvas.clip_bottom).reinterpret_as_int() -
    padding_y.reinterpret_as_int(),
    atlas_x: region.x,
    atlas_y: region.y,
  }
}

///|
fn sprite_blank_glyph() -> Glyph {
  { width: 0U, height: 0U, offset_x: 0, offset_y: 0, atlas_x: 0U, atlas_y: 0U }
}
