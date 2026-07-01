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
  match cp {
    0x110000 => true
    0x110001 => true
    0x110003 => true
    0x110005 => true
    0x110006 => true
    0x110007 => true
    0x110008 => true
    0x110009 => true
    0x11000A => true
    0x2500..=0x256C => true
    0x2574..=0x257F => true
    0x2580..=0x259F => true
    0x2800..=0x28FF => true
    0x1CC1B..=0x1CC1E => true
    0x1CC21..=0x1CC2F => true
    0x1CE16..=0x1CE19 => true
    0x1CE51..=0x1CE8F => true
    0x1CE90..=0x1CEAF => true
    0x1FB00..=0x1FB3B => true
    0x1FB70..=0x1FB97 => true
    0x1FBAF => true
    0x1FBCE..=0x1FBCF => true
    0x1FBE4..=0x1FBE7 => true
    _ => false
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

  match cp {
    0x110000 => underline(cp, canvas, width, height, metrics)
    0x110001 => underline_double(cp, canvas, width, height, metrics)
    0x110003 => underline_dashed(cp, canvas, width, height, metrics)
    0x110005 => strikethrough(cp, canvas, width, height, metrics)
    0x110006 => overline(cp, canvas, width, height, metrics)
    0x110007 => cursor_rect(cp, canvas, width, height, metrics)
    0x110008 => cursor_hollow_rect(cp, canvas, width, height, metrics)
    0x110009 => cursor_bar(cp, canvas, width, height, metrics)
    0x11000A => cursor_underline(cp, canvas, width, height, metrics)
    0x2500..=0x256C => draw2500_257f(cp, canvas, width, height, metrics)
    0x2574..=0x257F => draw2500_257f(cp, canvas, width, height, metrics)
    0x2580..=0x259F => draw2580_259f(cp, canvas, width, height, metrics)
    0x2800..=0x28FF => draw2800_28ff(cp, canvas, width, height, metrics)
    0x1CC1B..=0x1CC1E => draw1cc1b_1cc1e(cp, canvas, width, height, metrics)
    0x1CC21..=0x1CC2F => draw1cc21_1cc2f(cp, canvas, width, height, metrics)
    0x1CE16..=0x1CE19 => draw1ce16_1ce19(cp, canvas, width, height, metrics)
    0x1CE51..=0x1CE8F => draw1ce51_1ce8f(cp, canvas, width, height, metrics)
    0x1CE90..=0x1CEAF => draw1ce90_1ceaf(cp, canvas, width, height, metrics)
    0x1FB00..=0x1FB3B => draw1fb00_1fb3b(cp, canvas, width, height, metrics)
    0x1FB70..=0x1FB75 => draw1fb70_1fb75(cp, canvas, width, height, metrics)
    0x1FB76..=0x1FB7B => draw1fb76_1fb7b(cp, canvas, width, height, metrics)
    0x1FB7C..=0x1FB97 => draw1fb7c_1fb97(cp, canvas, width, height, metrics)
    0x1FBAF => draw1fbaf(cp, canvas, width, height, metrics)
    0x1FBCE => draw1fbce(cp, canvas, width, height, metrics)
    0x1FBCF => draw1fbcf(cp, canvas, width, height, metrics)
    0x1FBE4..=0x1FBE7 => draw1fbe0_1fbef(cp, canvas, width, height, metrics)
    _ => return sprite_blank_glyph()
  }

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
