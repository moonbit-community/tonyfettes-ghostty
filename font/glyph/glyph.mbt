// The glyph production chain: rasterize an outline's coverage, crop it to the
// inked bounding box, pack the tight bitmap into the atlas, and return the
// metadata a renderer needs to place the quad. Mirrors the role of Ghostty's
// `font/Glyph.zig` plus the rasterize-into-atlas step its faces perform.
//
// This layer is font-agnostic: it consumes a `@raster.Coverage` (whoever
// produced it — a real face via harfbuzz, or a synthetic shape) and never
// touches a font itself.

///|
/// A single rasterized glyph placed in the atlas.
pub struct Glyph {
  /// Tight bitmap width in pixels.
  width : Int
  /// Tight bitmap height in pixels.
  height : Int
  /// X of the inked bounding box within the source coverage canvas (the left
  /// bearing once the canvas origin is the pen origin).
  offset_x : Int
  /// Y of the inked bounding box within the source coverage canvas (top-down).
  offset_y : Int
  /// Top-left corner of the bitmap in the atlas texture, in pixels. Normalize
  /// against the atlas size before use in a shader.
  atlas_x : Int
  atlas_y : Int
} derive(Eq, Debug)

///|
/// Raised when a glyph's bitmap depth does not match the atlas format — here, a
/// grayscale coverage aimed at a `Bgr`/`Bgra` atlas. Mirrors Ghostty's
/// `error.WrongAtlas` in `face.renderGlyph`; it lives in this layer, not in the
/// atlas, because the format mismatch is a property of what is being rendered.
pub suberror WrongAtlas derive(Eq, Debug)

///|
/// Quantize a coverage value in `[0, 1]` to an 8-bit grayscale byte, rounded.
fn to_byte(v : Double) -> Byte {
  let mut n = (v * 255.0 + 0.5).to_int()
  if n < 0 {
    n = 0
  } else if n > 255 {
    n = 255
  }
  n.to_byte()
}

///|
/// Rasterize-and-place: crop `cov` to its inked bounding box, reserve an atlas
/// region of exactly that size, write the cropped grayscale bitmap, and return
/// the glyph metadata. A blank coverage (e.g. a space) yields a zero-sized glyph
/// and consumes no atlas space.
///
/// The atlas must be `Grayscale`: coverage is a single scalar channel, so the
/// bitmap is one byte per pixel, while `atlas.set` copies `width * height *
/// depth` bytes. Raising `WrongAtlas` for a `Bgr`/`Bgra` atlas avoids reading
/// past the buffer — color glyphs come from a separate bitmap path, as in
/// Ghostty's `face.renderGlyph`, where a grayscale bitmap into a non-grayscale
/// atlas returns `error.WrongAtlas`.
///
/// Raises `AtlasFull` if the atlas cannot fit the bitmap.
pub fn render_glyph(
  atlas : @atlas.Atlas,
  cov : @raster.Coverage,
) -> Glyph raise {
  guard atlas.format() is Grayscale else { raise WrongAtlas }
  let w = cov.width()
  let h = cov.height()
  // Inked bounding box: the extent of any non-zero (anti-aliased) coverage.
  let mut min_x = w
  let mut min_y = h
  let mut max_x = -1
  let mut max_y = -1
  for y in 0..<h {
    for x in 0..<w {
      if cov.get(x, y) > 0.0 {
        if x < min_x {
          min_x = x
        }
        if x > max_x {
          max_x = x
        }
        if y < min_y {
          min_y = y
        }
        if y > max_y {
          max_y = y
        }
      }
    }
  }
  if max_x < 0 {
    // Nothing was inked; reserve a zero region so the glyph still has a place.
    let region = atlas.reserve(0, 0)
    return {
      width: 0,
      height: 0,
      offset_x: 0,
      offset_y: 0,
      atlas_x: region.x,
      atlas_y: region.y,
    }
  }
  let gw = max_x - min_x + 1
  let gh = max_y - min_y + 1
  let bytes = Array::make(gw * gh, b'\x00')
  for y in 0..<gh {
    for x in 0..<gw {
      bytes[y * gw + x] = to_byte(cov.get(min_x + x, min_y + y))
    }
  }
  let region = atlas.reserve(gw, gh)
  atlas.set(region, bytes)
  {
    width: gw,
    height: gh,
    offset_x: min_x,
    offset_y: min_y,
    atlas_x: region.x,
    atlas_y: region.y,
  }
}
