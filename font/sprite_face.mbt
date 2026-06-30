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
    0x2580..=0x259F => true
    0x2800..=0x28FF => true
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
    0x2580..=0x259F => draw2580_259f(cp, canvas, width, height, metrics)
    0x2800..=0x28FF => draw2800_28ff(cp, canvas, width, height, metrics)
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
