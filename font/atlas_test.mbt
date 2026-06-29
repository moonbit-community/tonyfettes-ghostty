// Atlas tests. The first group is ported directly from Ghostty's `font/Atlas.zig`
// test suite (same sizes, same byte offsets) so behavior tracks the original.
// The second group adds packing invariants that need no reference: reserved
// regions must never overlap and must stay inside the border.

///|
/// Assert that a reservation raises `AtlasFull`.
fn expect_full(atlas : Atlas, w : Int, h : Int) -> Unit raise {
  let raised = try {
    atlas.reserve(w, h) |> ignore
    false
  } catch {
    AtlasFull => true
  }
  assert_true(raised)
}

///|
test "exact fit" {
  let atlas = Atlas::new(34, Grayscale) // +2 for the 1px border
  let modified = atlas.modified()
  atlas.reserve(32, 32) |> ignore
  assert_eq(atlas.modified(), modified) // reserve alone doesn't modify pixels
  expect_full(atlas, 1, 1)
}

///|
test "doesn't fit" {
  let atlas = Atlas::new(32, Grayscale)
  // Doesn't fit because of the border.
  expect_full(atlas, 32, 32)
}

///|
test "fit multiple" {
  let atlas = Atlas::new(32, Grayscale)
  atlas.reserve(15, 30) |> ignore
  atlas.reserve(15, 30) |> ignore
  expect_full(atlas, 1, 1)
}

///|
test "writing data" {
  let atlas = Atlas::new(32, Grayscale)
  let reg = atlas.reserve(2, 2)
  let old = atlas.modified()
  atlas.set(reg, [b'\x01', b'\x02', b'\x03', b'\x04'])
  assert_true(atlas.modified() > old)
  // 33 = (row 1 * size 32) + col 1, because of the 1px border.
  let d = atlas.data()
  assert_eq(d[33], b'\x01')
  assert_eq(d[34], b'\x02')
  assert_eq(d[65], b'\x03')
  assert_eq(d[66], b'\x04')
}

///|
test "writing data from a larger source" {
  let atlas = Atlas::new(32, Grayscale)
  let reg = atlas.reserve(2, 2)
  let old = atlas.modified()
  // The 2x2 region (1,2 / 3,4) sits inside a 5-wide source at (src_x=2, src_y=1).
  atlas.set_from_larger(
    reg,
    [
      b'\x08', b'\x08', b'\x08', b'\x08', b'\x08', //
       b'\x08', b'\x08', b'\x01', b'\x02', b'\x08', //
       b'\x08', b'\x08', b'\x03', b'\x04', b'\x08', //
       b'\x08', b'\x08', b'\x08', b'\x08', b'\x08',
    ],
    5,
    2,
    1,
  )
  assert_true(atlas.modified() > old)
  let d = atlas.data()
  assert_eq(d[33], b'\x01')
  assert_eq(d[34], b'\x02')
  assert_eq(d[65], b'\x03')
  assert_eq(d[66], b'\x04')
  // None of the surrounding `8`s should have leaked in.
  for b in d {
    assert_true(b != b'\x08')
  }
}

///|
test "grow" {
  let atlas = Atlas::new(4, Grayscale) // 2x2 usable
  let reg = atlas.reserve(2, 2)
  expect_full(atlas, 1, 1)
  atlas.set(reg, [b'\x01', b'\x02', b'\x03', b'\x04'])
  let d0 = atlas.data()
  assert_eq(d0[5], b'\x01')
  assert_eq(d0[6], b'\x02')
  assert_eq(d0[9], b'\x03')
  assert_eq(d0[10], b'\x04')

  // Expand by exactly 1 should fit a new 1x1 block.
  let old_modified = atlas.modified()
  let old_resized = atlas.resized()
  atlas.grow(atlas.size() + 1)
  assert_true(atlas.modified() > old_modified)
  assert_true(atlas.resized() > old_resized)
  atlas.reserve(1, 1) |> ignore

  // Data should survive the grow, at offsets shifted by the new size.
  let s = atlas.size()
  let d = atlas.data()
  assert_eq(d[s + 1], b'\x01')
  assert_eq(d[s + 2], b'\x02')
  assert_eq(d[s * 2 + 1], b'\x03')
  assert_eq(d[s * 2 + 2], b'\x04')
}

///|
test "writing BGR data" {
  let atlas = Atlas::new(32, Bgr) // 3 bpp
  let reg = atlas.reserve(1, 2)
  atlas.set(reg, [b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06'])
  let depth = atlas.format().depth()
  let d = atlas.data()
  assert_eq(d[33 * depth], b'\x01')
  assert_eq(d[33 * depth + 1], b'\x02')
  assert_eq(d[33 * depth + 2], b'\x03')
  assert_eq(d[65 * depth], b'\x04')
  assert_eq(d[65 * depth + 1], b'\x05')
  assert_eq(d[65 * depth + 2], b'\x06')
}

///|
/// Pack many regions and assert the two invariants a packer must never violate:
/// reserved rectangles stay inside the 1px border, and no two overlap.
test "packing invariants: in-bounds and non-overlapping" {
  let atlas = Atlas::new(128, Grayscale)
  let regions : Array[Region] = []
  // Deterministic pseudo-random sizes via a small LCG.
  let mut seed = 1234567
  let mut full = false
  // Far more attempts than can fit a 128² atlas, so a reservation must
  // eventually fail and exercise the AtlasFull path.
  for _ in 0..<3000 {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff
    let w = 1 + seed % 12
    let h = 1 + (seed >> 8) % 12
    let reg = atlas.reserve(w, h) catch {
      AtlasFull => {
        full = true
        break
      }
    }
    regions.push(reg)
  }
  // With far more attempts than can fit, a reservation must have failed.
  assert_true(full)
  assert_true(regions.length() > 0)
  let size = atlas.size()
  for r in regions {
    // In bounds: inside the [1, size-1) usable area.
    assert_true(r.x >= 1 && r.y >= 1)
    assert_true(r.x + r.width <= size - 1)
    assert_true(r.y + r.height <= size - 1)
  }
  // Pairwise non-overlap.
  for i in 0..<regions.length() {
    for j in (i + 1)..<regions.length() {
      let a = regions[i]
      let b = regions[j]
      let disjoint = a.x + a.width <= b.x ||
        b.x + b.width <= a.x ||
        a.y + a.height <= b.y ||
        b.y + b.height <= a.y
      assert_true(disjoint)
    }
  }
}

///|
test "zero-sized reservation is a no-op region" {
  let atlas = Atlas::new(32, Grayscale)
  let r = atlas.reserve(0, 0)
  assert_eq(r.x, 0)
  assert_eq(r.y, 0)
  assert_eq(r.width, 0)
  assert_eq(r.height, 0)
}
