// A texture atlas (https://en.wikipedia.org/wiki/Texture_atlas).
//
// This is a MoonBit port of Ghostty's `font/Atlas.zig`. The packing is the
// skyline / "shelf" bin-packing from Jukka Jylänki's "A Thousand Ways to Pack
// the Bin", by way of Nicolas P. Rougier's freetype-gl. The atlas texture is
// always square; reserved regions need not be.
//
// A 1px border is kept around the usable area so that GPU sampling never bleeds
// across adjacent glyphs.

///|
/// Pixel format of the atlas texture. Must be uniform across the whole atlas.
/// Callers pick a format when constructing an atlas, so the variants are public.
pub(all) enum Format {
  /// 1 byte per pixel grayscale.
  Grayscale
  /// 3 bytes per pixel BGR.
  Bgr
  /// 4 bytes per pixel BGRA.
  Bgra
} derive(Eq, Debug)

///|
/// Bytes per pixel for this format.
pub fn Format::depth(self : Format) -> Int {
  match self {
    Grayscale => 1
    Bgr => 3
    Bgra => 4
  }
}

///|
/// Raised by `reserve` when the requested region cannot fit. The caller must
/// `grow` the atlas (or use a fresh one) and retry.
pub suberror AtlasError {
  AtlasFull
} derive(Eq, Debug)

///|
/// A reserved rectangle within the atlas. Required to write data via `set`.
pub struct Region {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
/// A node in the skyline: a horizontal segment of free space whose top sits at
/// `y`, starting at `x` and spanning `width` pixels.
priv struct Node {
  mut x : Int
  y : Int
  mut width : Int
}

///|
/// Opaque: the texture buffer and skyline are internal. The GPU uploader reads
/// state through the accessors below (`data`, `size`, `modified`, `resized`).
struct Atlas {
  /// Raw texture data, row-major, `depth` bytes per pixel.
  mut data : Array[Byte]
  /// Width == height of the (square) texture.
  mut size : Int
  /// Skyline nodes (free-space segments), kept sorted by `x`.
  nodes : Array[Node]
  /// Pixel format of `data`.
  format : Format
  /// Bumped on every content change; lets a GPU uploader know data is dirty.
  mut modified : Int
  /// Bumped on every resize; lets a GPU uploader know it must reallocate.
  mut resized : Int
}

///|
/// Raw texture bytes, row-major at `depth` bytes per pixel. Read-only in spirit:
/// the uploader streams this to the GPU; do not mutate it directly.
pub fn Atlas::data(self : Atlas) -> Array[Byte] {
  self.data
}

///|
/// Texture side length in pixels (square; includes the 1px border).
pub fn Atlas::size(self : Atlas) -> Int {
  self.size
}

///|
/// Pixel format of the texture.
pub fn Atlas::format(self : Atlas) -> Format {
  self.format
}

///|
/// Monotonic counter bumped on every content change. Compare against a stored
/// value to decide whether a GPU re-upload is needed.
pub fn Atlas::modified(self : Atlas) -> Int {
  self.modified
}

///|
/// Monotonic counter bumped on every resize. A change means the GPU texture
/// must be reallocated, not just updated in place.
pub fn Atlas::resized(self : Atlas) -> Int {
  self.resized
}

///|
/// Create a `size` x `size` atlas in the given format. `size` includes the 1px
/// border, so the usable area is `(size - 2)` square.
pub fn Atlas::new(size : Int, format : Format) -> Atlas {
  let self = Atlas::{
    data: Array::make(size * size * format.depth(), b'\x00'),
    size,
    nodes: [],
    format,
    modified: 0,
    resized: 0,
  }
  self.clear()
  self
}

///|
/// Empty the atlas, keeping the allocation. Resets the skyline to one full-width
/// segment inside the 1px border.
pub fn Atlas::clear(self : Atlas) -> Unit {
  self.modified += 1
  for i in 0..<self.data.length() {
    self.data[i] = b'\x00'
  }
  self.nodes.clear()
  // The initial free segment spans the full usable width, offset by the border.
  self.nodes.push({ x: 1, y: 1, width: self.size - 2 })
}

///|
/// Reserve a `width` x `height` region. Does not grow the texture; raises
/// `AtlasFull` if no spot fits. A zero-sized request returns a zero region.
pub fn Atlas::reserve(
  self : Atlas,
  width : Int,
  height : Int,
) -> Region raise AtlasError {
  if width == 0 && height == 0 {
    return { x: 0, y: 0, width, height }
  }

  // Find the node that fits the region with the lowest resulting top edge,
  // breaking ties toward the narrowest node (best-area heuristic).
  let int_max = 2147483647
  let mut best_height = int_max
  let mut best_width = int_max
  let mut chosen = -1
  let mut rx = 0
  let mut ry = 0
  for i in 0..<self.nodes.length() {
    match self.fit(i, width, height) {
      Some(y) => {
        let node = self.nodes[i]
        if y + height < best_height ||
          (
            y + height == best_height &&
            node.width > 0 &&
            node.width < best_width
          ) {
          chosen = i
          best_width = node.width
          best_height = y + height
          rx = node.x
          ry = y
        }
      }
      None => continue
    }
  }
  guard chosen >= 0 else { raise AtlasFull }
  let region = Region::{ x: rx, y: ry, width, height }

  // Insert the new skyline node for the space we just consumed.
  self.nodes.insert(chosen, { x: region.x, y: region.y + height, width })

  // Trim/remove any following nodes that the new node now overlaps. A removal
  // shifts the next node into the same index, so `i` stays put throughout.
  let i = chosen + 1
  while i < self.nodes.length() {
    let node = self.nodes[i]
    let prev = self.nodes[i - 1]
    if node.x < prev.x + prev.width {
      let shrink = prev.x + prev.width - node.x
      node.x += shrink
      node.width -= shrink
      if node.width <= 0 {
        // The next node shifts down into index `i`; re-examine it against the
        // same `prev`, so leave `i` unchanged.
        self.nodes.remove(i) |> ignore
        continue
      }
    }
    break
  }
  self.merge()
  region
}

///|
/// Can a `width` x `height` rectangle rest on the skyline starting at node
/// `idx`? Returns the `y` it would sit at, or `None` if it runs off an edge.
fn Atlas::fit(self : Atlas, idx : Int, width : Int, height : Int) -> Int? {
  let node = self.nodes[idx]
  if node.x + width > self.size - 1 {
    return None
  }
  // Walk forward across the nodes the rectangle spans, taking the highest top.
  let mut y = node.y
  let mut i = idx
  let mut width_left = width
  while width_left > 0 {
    let n = self.nodes[i]
    if n.y > y {
      y = n.y
    }
    if y + height > self.size - 1 {
      return None
    }
    width_left -= n.width
    i += 1
  }
  Some(y)
}

///|
/// Merge adjacent skyline nodes that share a `y`, keeping the list compact.
fn Atlas::merge(self : Atlas) -> Unit {
  let mut i = 0
  while i < self.nodes.length() - 1 {
    let node = self.nodes[i]
    let next = self.nodes[i + 1]
    if node.y == next.y {
      node.width += next.width
      self.nodes.remove(i + 1) |> ignore
      continue
    }
    i += 1
  }
}

///|
/// Copy `w` x `h` pixels from `src` (stride `src_stride` pixels, starting at
/// byte `src_base`) into the atlas at `(dst_x, dst_y)`. Both sides are packed at
/// `depth` bytes per pixel.
fn Atlas::blit(
  self : Atlas,
  dst_x : Int,
  dst_y : Int,
  w : Int,
  h : Int,
  src : Array[Byte],
  src_base : Int,
  src_stride : Int,
) -> Unit {
  let depth = self.format.depth()
  for i in 0..<h {
    let tex_off = ((dst_y + i) * self.size + dst_x) * depth
    let src_off = src_base + i * src_stride * depth
    for j in 0..<(w * depth) {
      self.data[tex_off + j] = src[src_off + j]
    }
  }
}

///|
/// Write tightly-packed `data` into a reserved `region`. `data` must hold
/// exactly `region.width * region.height * depth` bytes.
pub fn Atlas::set(self : Atlas, region : Region, data : Array[Byte]) -> Unit {
  self.blit(
    region.x,
    region.y,
    region.width,
    region.height,
    data,
    0,
    region.width,
  )
  self.modified += 1
}

///|
/// Like `set`, but copies a sub-rectangle out of a larger `src` buffer of width
/// `src_width`, starting at `(src_x, src_y)` within it.
pub fn Atlas::set_from_larger(
  self : Atlas,
  region : Region,
  src : Array[Byte],
  src_width : Int,
  src_x : Int,
  src_y : Int,
) -> Unit {
  let depth = self.format.depth()
  let src_base = (src_y * src_width + src_x) * depth
  self.blit(
    region.x,
    region.y,
    region.width,
    region.height,
    src,
    src_base,
    src_width,
  )
  self.modified += 1
}

///|
/// Grow the texture to `size_new` x `size_new`, preserving all written data.
/// `size_new` must be `>= size`.
pub fn Atlas::grow(self : Atlas, size_new : Int) -> Unit {
  if size_new == self.size {
    return
  }
  let data_old = self.data
  let size_old = self.size
  let depth = self.format.depth()
  self.data = Array::make(size_new * size_new * depth, b'\x00')
  self.size = size_new
  // Copy the old image back in, skipping its top and bottom border rows.
  self.blit(0, 1, size_old, size_old - 2, data_old, size_old * depth, size_old)
  // The freshly exposed column on the right becomes a new free segment.
  self.nodes.push({ x: size_old - 1, y: 1, width: size_new - size_old })
  self.modified += 1
  self.resized += 1
}
