///|
pub(all) enum AtlasFormat {
  Grayscale
  Bgr
  Bgra
} derive(Eq, Debug)

///|
pub fn AtlasFormat::depth(self : AtlasFormat) -> Byte {
  match self {
    Grayscale => 1
    Bgr => 3
    Bgra => 4
  }
}

///|
pub(all) struct AtlasNode {
  mut x : UInt
  mut y : UInt
  mut width : UInt
} derive(Eq, Debug)

///|
pub suberror AtlasError {
  AtlasFull
} derive(Eq, Debug)

///|
pub(all) struct AtlasRegion {
  mut x : UInt
  mut y : UInt
  width : UInt
  height : UInt
} derive(Eq, Debug)

///|
pub(all) struct Atlas {
  mut data : Array[Byte]
  mut size : UInt
  mut nodes : Array[AtlasNode]
  mut format : AtlasFormat
  mut modified : UInt
  mut resized : UInt
} derive(Eq, Debug)

///|
pub fn Atlas::new(size : UInt, format : AtlasFormat) -> Atlas {
  let depth = format.depth().to_uint()
  let result = {
    data: Array::make((size * size * depth).reinterpret_as_int(), b'\x00'),
    size,
    nodes: [],
    format,
    modified: 0U,
    resized: 0U,
  }
  result.clear()
  result
}

///|
pub fn Atlas::reserve(
  self : Atlas,
  width : UInt,
  height : UInt,
) -> AtlasRegion raise AtlasError {
  let region = { x: 0U, y: 0U, width, height }
  if width == 0U && height == 0U {
    return region
  }
  let mut best_height = 0xFFFFFFFFU
  let mut best_width = best_height
  let mut chosen = -1
  for i in 0..<self.nodes.length() {
    match self.fit(i, width, height) {
      None => ()
      Some(y) => {
        let node = self.nodes[i]
        if y + height < best_height ||
          (
            y + height == best_height &&
            node.width > 0U &&
            node.width < best_width
          ) {
          chosen = i
          best_width = node.width
          best_height = y + height
          region.x = node.x
          region.y = y
        }
      }
    }
  }
  if chosen < 0 {
    raise AtlasFull
  }
  let best_idx = chosen
  self.nodes.insert(best_idx, { x: region.x, y: region.y + height, width })
  let i = best_idx + 1
  while i < self.nodes.length() {
    let node = self.nodes[i]
    let prev = self.nodes[i - 1]
    if node.x < prev.x + prev.width {
      let shrink = prev.x + prev.width - node.x
      node.x += shrink
      node.width = saturating_sub_uint(node.width, shrink)
      if node.width == 0U {
        ignore(self.nodes.remove(i))
        continue
      }
    }
    break
  }
  self.merge()
  region
}

///|
fn Atlas::fit(self : Atlas, idx : Int, width : UInt, height : UInt) -> UInt? {
  let node = self.nodes[idx]
  if node.x + width > self.size - 1U {
    return None
  }
  let mut y = node.y
  let mut i = idx
  let mut width_left = width
  while width_left > 0U {
    let n = self.nodes[i]
    if n.y > y {
      y = n.y
    }
    if y + height > self.size - 1U {
      return None
    }
    width_left = saturating_sub_uint(width_left, n.width)
    i += 1
  }
  Some(y)
}

///|
fn Atlas::merge(self : Atlas) -> Unit {
  let mut i = 0
  while i < self.nodes.length() - 1 {
    let node = self.nodes[i]
    let next = self.nodes[i + 1]
    if node.y == next.y {
      node.width += next.width
      ignore(self.nodes.remove(i + 1))
      continue
    }
    i += 1
  }
}

///|
pub fn Atlas::set(
  self : Atlas,
  reg : AtlasRegion,
  data : ArrayView[Byte],
) -> Unit {
  self.assert_region(reg)
  let depth = self.format.depth().to_uint()
  let row_len = (reg.width * depth).reinterpret_as_int()
  for i in 0..<reg.height.reinterpret_as_int() {
    let row = i.reinterpret_as_uint()
    let tex_offset = (((reg.y + row) * self.size + reg.x) * depth).reinterpret_as_int()
    let data_offset = row.reinterpret_as_int() * row_len
    for j in 0..<row_len {
      self.data[tex_offset + j] = data[data_offset + j]
    }
  }
  self.modified += 1U
}

///|
pub fn Atlas::set_from_larger(
  self : Atlas,
  reg : AtlasRegion,
  src : ArrayView[Byte],
  src_width : UInt,
  src_x : UInt,
  src_y : UInt,
) -> Unit {
  self.assert_region(reg)
  let depth = self.format.depth().to_uint()
  let row_len = (reg.width * depth).reinterpret_as_int()
  for i in 0..<reg.height.reinterpret_as_int() {
    let row = i.reinterpret_as_uint()
    let tex_offset = (((reg.y + row) * self.size + reg.x) * depth).reinterpret_as_int()
    let src_offset = (((src_y + row) * src_width + src_x) * depth).reinterpret_as_int()
    for j in 0..<row_len {
      self.data[tex_offset + j] = src[src_offset + j]
    }
  }
  self.modified += 1U
}

///|
pub fn Atlas::grow(self : Atlas, size_new : UInt) -> Unit {
  guard size_new >= self.size else { abort("Atlas cannot shrink") }
  if size_new == self.size {
    return
  }
  let depth = self.format.depth().to_uint()
  let data_new = Array::make(
    (size_new * size_new * depth).reinterpret_as_int(),
    b'\x00',
  )
  let data_old = self.data
  let size_old = self.size
  self.data = data_new
  self.size = size_new
  self.set(
    { x: 0U, y: 1U, width: size_old, height: size_old - 2U },
    data_old.view(start=(size_old * depth).reinterpret_as_int()),
  )
  self.nodes.push({ x: size_old - 1U, y: 1U, width: size_new - size_old })
  self.modified += 1U
  self.resized += 1U
}

///|
pub fn Atlas::clear(self : Atlas) -> Unit {
  self.modified += 1U
  self.data.fill(b'\x00')
  self.nodes.clear()
  self.nodes.push({ x: 1U, y: 1U, width: self.size - 2U })
}

///|
fn saturating_sub_uint(left : UInt, right : UInt) -> UInt {
  if left > right {
    left - right
  } else {
    0U
  }
}

///|
fn Atlas::assert_region(self : Atlas, reg : AtlasRegion) -> Unit {
  let max = self.size - 1U
  guard reg.x < max &&
    reg.x + reg.width <= max &&
    reg.y < max &&
    reg.y + reg.height <= max else {
    abort("Atlas region out of bounds")
  }
}
