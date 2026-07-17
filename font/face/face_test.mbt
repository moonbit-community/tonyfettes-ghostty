// End-to-end: real font bytes -> harfbuzz outline -> raster coverage -> placed
// in the glyph cache. Drives the whole font stack with the embedded subset
// Inconsolata, no filesystem.

///|
test "loads the embedded face and reads its units-per-em" {
  let face = Face::load(inconsolata_subset)
  assert_eq(face.upem(), inconsolata_subset_upem)
}

///|
test "cmap maps embedded codepoints and rejects absent ones" {
  let face = Face::load(inconsolata_subset)
  // 'A' is in the subset; 'Z' (0x5A) is not.
  assert_true(face.glyph_index('A'.to_uint()) is Some(_))
  assert_true(face.glyph_index('Z'.to_uint()) is None)
}

///|
/// Rasterize a glyph from the embedded face into a coverage buffer.
fn rasterize_char(
  face : Face,
  ch : Char,
  px : Int,
  w : Int,
  h : Int,
  origin_x : Double,
  baseline_y : Double,
) -> @raster.Coverage raise {
  let gid = match face.glyph_index(ch.to_uint()) {
    Some(g) => g
    None => fail("no glyph for \{ch}")
  }
  face.rasterize(gid, px, w, h, origin_x, baseline_y)
}

///|
test "renders a real 'A' end to end into the glyph cache" {
  let face = Face::load(inconsolata_subset)
  let px = 32
  let cov = rasterize_char(face, 'A', px, 40, 40, 4.0, 34.0)
  let cache = @glyph.GlyphCache::new(256, Grayscale)
  let g = cache.render({ font: 0, glyph: 'A'.to_int(), px }, cov)
  // A real 'A' is non-empty and its tight bitmap fits the canvas.
  assert_true(g.width > 0 && g.height > 0)
  assert_true(g.width <= 40 && g.height <= 40)
  // Some pixel was actually inked into the atlas.
  let atlas = cache.atlas()
  let mut max_v = 0
  for y in 0..<g.height {
    for x in 0..<g.width {
      let v = atlas.data()[(g.atlas_y + y) * atlas.size() + g.atlas_x + x].to_int()
      if v > max_v {
        max_v = v
      }
    }
  }
  assert_eq(max_v, 255)
}

///|
test "distinct glyphs share an atlas in disjoint regions, cache hits are free" {
  let face = Face::load(inconsolata_subset)
  let cache = @glyph.GlyphCache::new(256, Grayscale)
  let px = 24
  let a_cov = rasterize_char(face, 'A', px, 32, 32, 2.0, 26.0)
  let o_cov = rasterize_char(face, 'o', px, 32, 32, 2.0, 26.0)
  let ka = @glyph.GlyphKey::{ font: 0, glyph: 'A'.to_int(), px }
  let ko = @glyph.GlyphKey::{ font: 0, glyph: 'o'.to_int(), px }
  let a = cache.render(ka, a_cov)
  let o = cache.render(ko, o_cov)
  assert_eq(cache.count(), 2)
  let disjoint = a.atlas_x + a.width <= o.atlas_x ||
    o.atlas_x + o.width <= a.atlas_x ||
    a.atlas_y + a.height <= o.atlas_y ||
    o.atlas_y + o.height <= a.atlas_y
  assert_true(disjoint)

  // Re-rendering 'A' is a pure cache hit: atlas untouched, count unchanged.
  let before = cache.atlas().modified()
  let a2 = cache.render(ka, a_cov)
  assert_true(a2 == a)
  assert_eq(cache.count(), 2)
  assert_eq(cache.atlas().modified(), before)
}

///|
test "ascii snapshot of the embedded 'A'" {
  let face = Face::load(inconsolata_subset)
  let cov = rasterize_char(face, 'A', 24, 22, 26, 2.0, 23.0)
  inspect(
    cov.to_ascii(),
    content=(
      #|                      
      #|                      
      #|                      
      #|                      
      #|                      
      #|                      
      #|                      
      #|                      
      #|       --             
      #|       **             
      #|       %%             
      #|      -%%-            
      #|      #**#            
      #|     .%:-%.           
      #|     =%  %=           
      #|     #+  *#           
      #|    :@:  -@:          
      #|    +@*++*@+          
      #|    %@++++%%          
      #|   -@:    :@-         
      #|   *%      %*         
      #|   %+      +%         
      #|  -@.      :@-        
      #|                      
      #|                      
      #|                      
      #|
    ),
  )
}
