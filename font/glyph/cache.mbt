// A glyph cache: memoizes rendered glyphs in an atlas, keyed by the font, glyph
// id, and pixel size. Mirrors the role of Ghostty's `font/SharedGrid.zig` — the
// font subsystem is read-heavy, so a glyph is rasterized into the atlas once and
// reused on every subsequent frame.

///|
/// Identifies a rendered glyph: which face, which glyph in it, at which pixel
/// size. Callers build these to look up or render, so the fields are public.
pub(all) struct GlyphKey {
  font : Int
  glyph : Int
  px : Int
} derive(Eq, Hash, Debug)

///|
/// An atlas plus the memo table of glyphs already placed in it.
struct GlyphCache {
  atlas : @atlas.Atlas
  glyphs : Map[GlyphKey, Glyph]
}

///|
/// Create a cache backed by a fresh `size` x `size` atlas in `format`.
pub fn GlyphCache::new(size : Int, format : @atlas.Format) -> GlyphCache {
  { atlas: @atlas.Atlas::new(size, format), glyphs: Map([]) }
}

///|
/// The backing atlas, for the GPU uploader to read.
pub fn GlyphCache::atlas(self : GlyphCache) -> @atlas.Atlas {
  self.atlas
}

///|
/// The glyph for `key` if it has already been rendered, else `None`.
pub fn GlyphCache::get(self : GlyphCache, key : GlyphKey) -> Glyph? {
  self.glyphs.get(key)
}

///|
/// Number of distinct glyphs currently cached.
pub fn GlyphCache::count(self : GlyphCache) -> Int {
  self.glyphs.length()
}

///|
/// Return the cached glyph for `key`, or render `cov` into the atlas, cache it,
/// and return it. The coverage is only consulted on a miss, so callers may
/// rasterize lazily. Raises `AtlasFull` if a fresh glyph does not fit, or
/// `WrongAtlas` if the backing atlas is not grayscale.
pub fn GlyphCache::render(
  self : GlyphCache,
  key : GlyphKey,
  cov : @raster.Coverage,
) -> Glyph raise {
  match self.glyphs.get(key) {
    Some(g) => g
    None => {
      let g = render_glyph(self.atlas, cov)
      self.glyphs[key] = g
      g
    }
  }
}
