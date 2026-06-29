// Glyph production + cache tests. They drive the chain end to end with
// synthetic raster shapes (no font needed): rasterize -> crop -> pack -> cache.

///|
test "render_glyph crops to the inked bbox and packs a tight bitmap" {
  let atlas = @atlas.Atlas::new(64, Grayscale)
  // A solid 8x8 square at (8,8) inside a 32x32 canvas: integer-aligned, so its
  // interior pixels are fully covered.
  let cov = @raster.render(@raster.rect(8.0, 8.0, 16.0, 16.0), 32, 32, NonZero)
  let g = @glyph.render_glyph(atlas, cov)
  // Tight bitmap is exactly the square, cropped out of the empty canvas.
  assert_eq(g.width, 8)
  assert_eq(g.height, 8)
  assert_eq(g.offset_x, 8)
  assert_eq(g.offset_y, 8)
  // It lands inside the atlas border.
  assert_true(g.atlas_x >= 1 && g.atlas_y >= 1)
  // The fully-covered interior wrote 255 into the atlas at the glyph's corner.
  let idx = g.atlas_y * atlas.size() + g.atlas_x
  assert_eq(atlas.data()[idx].to_int(), 255)
}

///|
test "render_glyph of a blank coverage is a zero-sized glyph" {
  let atlas = @atlas.Atlas::new(64, Grayscale)
  let blank = @raster.Coverage::new(16, 16) // all zero
  let before = atlas.modified()
  let g = @glyph.render_glyph(atlas, blank)
  assert_eq(g.width, 0)
  assert_eq(g.height, 0)
  // A blank glyph writes nothing into the texture.
  assert_eq(atlas.modified(), before)
}

///|
test "anti-aliased edges quantize to partial grayscale" {
  let atlas = @atlas.Atlas::new(64, Grayscale)
  let cov = @raster.render(
    @raster.circle(16.0, 16.0, 12.0, segments=64),
    32,
    32,
    NonZero,
  )
  let g = @glyph.render_glyph(atlas, cov)
  // Scan the placed bitmap: a circle has both solid interior (255) and
  // anti-aliased edge pixels strictly between 0 and 255.
  let mut saw_full = false
  let mut saw_partial = false
  for y in 0..<g.height {
    for x in 0..<g.width {
      let v = atlas.data()[(g.atlas_y + y) * atlas.size() + g.atlas_x + x].to_int()
      if v == 255 {
        saw_full = true
      }
      if v > 0 && v < 255 {
        saw_partial = true
      }
    }
  }
  assert_true(saw_full)
  assert_true(saw_partial)
}

///|
test "cache renders once and reuses on repeat lookups" {
  let cache = @glyph.GlyphCache::new(128, Grayscale)
  let key = @glyph.GlyphKey::{ font: 0, glyph: 65, px: 16 }
  let cov = @raster.render(@raster.rect(4.0, 4.0, 12.0, 12.0), 24, 24, NonZero)

  assert_true(cache.get(key) is None)
  let g1 = cache.render(key, cov)
  assert_eq(cache.count(), 1)
  assert_true(cache.get(key) == Some(g1))

  // A repeat lookup is a pure cache hit: same glyph, atlas untouched.
  let before = cache.atlas().modified()
  let g2 = cache.render(key, cov)
  assert_true(g2 == g1)
  assert_eq(cache.count(), 1)
  assert_eq(cache.atlas().modified(), before)

  // A different key renders a new entry and writes the atlas.
  let key2 = @glyph.GlyphKey::{ font: 0, glyph: 66, px: 16 }
  cache.render(key2, cov) |> ignore
  assert_eq(cache.count(), 2)
  assert_true(cache.atlas().modified() > before)
}

///|
test "two glyphs occupy disjoint atlas regions" {
  let cache = @glyph.GlyphCache::new(128, Grayscale)
  let cov = @raster.render(@raster.rect(2.0, 2.0, 10.0, 10.0), 16, 16, NonZero)
  let a = cache.render({ font: 0, glyph: 1, px: 16 }, cov)
  let b = cache.render({ font: 0, glyph: 2, px: 16 }, cov)
  // Same shape, but distinct placements in the atlas.
  let disjoint = a.atlas_x + a.width <= b.atlas_x ||
    b.atlas_x + b.width <= a.atlas_x ||
    a.atlas_y + a.height <= b.atlas_y ||
    b.atlas_y + b.height <= a.atlas_y
  assert_true(disjoint)
}
