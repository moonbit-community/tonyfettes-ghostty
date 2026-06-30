///|
test "atlas format depth" {
  assert_eq(AtlasFormat::Grayscale.depth(), 1)
  assert_eq(AtlasFormat::Bgr.depth(), 3)
  assert_eq(AtlasFormat::Bgra.depth(), 4)
}

///|
test "atlas reserve empty region" {
  let atlas = Atlas::new(4U, Grayscale)
  let modified = atlas.modified
  let region = atlas.reserve(0U, 0U) catch {
    AtlasFull => fail("empty atlas region should fit")
  }
  guard region == { x: 0U, y: 0U, width: 0U, height: 0U } else {
    fail("expected empty region")
  }
  assert_eq(atlas.modified, modified)
}

///|
test "atlas exact fit" {
  let atlas = Atlas::new(34U, Grayscale)
  let modified = atlas.modified
  ignore(
    atlas.reserve(32U, 32U) catch {
      AtlasFull => fail("expected exact fit")
    },
  )
  assert_eq(atlas.modified, modified)
  try atlas.reserve(1U, 1U) catch {
    AtlasFull => ()
  } noraise {
    _ => fail("expected full atlas")
  }
}

///|
test "atlas does not fit due to border" {
  let atlas = Atlas::new(32U, Grayscale)
  try atlas.reserve(32U, 32U) catch {
    AtlasFull => ()
  } noraise {
    _ => fail("expected border to make atlas full")
  }
}

///|
test "atlas fits multiple regions" {
  let atlas = Atlas::new(32U, Grayscale)
  ignore(
    atlas.reserve(15U, 30U) catch {
      AtlasFull => fail("expected first region")
    },
  )
  ignore(
    atlas.reserve(15U, 30U) catch {
      AtlasFull => fail("expected second region")
    },
  )
  try atlas.reserve(1U, 1U) catch {
    AtlasFull => ()
  } noraise {
    _ => fail("expected full atlas")
  }
}

///|
test "atlas fit raises y across skyline nodes" {
  let atlas = Atlas::new(10U, Grayscale)
  atlas.nodes = [{ x: 1U, y: 1U, width: 2U }, { x: 3U, y: 5U, width: 4U }]
  let reg = atlas.reserve(4U, 1U) catch {
    AtlasFull => fail("expected region across skyline nodes")
  }
  guard reg.x == 1U && reg.y == 5U else {
    fail("expected fit to raise y to the taller skyline node")
  }
}

///|
test "atlas writes data" {
  let atlas = Atlas::new(32U, Grayscale)
  let reg = atlas.reserve(2U, 2U) catch { AtlasFull => fail("expected region") }
  let old = atlas.modified
  atlas.set(reg, [1, 2, 3, 4])
  guard atlas.modified > old else {
    fail("expected atlas modification counter to increase")
  }
  assert_eq(atlas.data[33], 1)
  assert_eq(atlas.data[34], 2)
  assert_eq(atlas.data[65], 3)
  assert_eq(atlas.data[66], 4)
}

///|
test "atlas writes data from larger source" {
  let atlas = Atlas::new(32U, Grayscale)
  let reg = atlas.reserve(2U, 2U) catch { AtlasFull => fail("expected region") }
  let old = atlas.modified
  atlas.set_from_larger(
    reg,
    [8, 8, 8, 8, 8, 8, 8, 1, 2, 8, 8, 8, 3, 4, 8, 8, 8, 8, 8, 8],
    5U,
    2U,
    1U,
  )
  guard atlas.modified > old else {
    fail("expected atlas modification counter to increase")
  }
  assert_eq(atlas.data[33], 1)
  assert_eq(atlas.data[34], 2)
  assert_eq(atlas.data[65], 3)
  assert_eq(atlas.data[66], 4)
  guard !atlas.data.contains(8) else {
    fail("larger-source padding should not be copied")
  }
}

///|
test "atlas grow" {
  let atlas = Atlas::new(4U, Grayscale)
  let reg = atlas.reserve(2U, 2U) catch {
    AtlasFull => fail("expected initial region")
  }
  try atlas.reserve(1U, 1U) catch {
    AtlasFull => ()
  } noraise {
    _ => fail("expected full atlas")
  }
  atlas.set(reg, [1, 2, 3, 4])
  assert_eq(atlas.data[5], 1)
  assert_eq(atlas.data[6], 2)
  assert_eq(atlas.data[9], 3)
  assert_eq(atlas.data[10], 4)
  let old_modified = atlas.modified
  let old_resized = atlas.resized
  atlas.grow(atlas.size + 1U)
  guard atlas.modified > old_modified else {
    fail("expected grow to modify atlas")
  }
  guard atlas.resized > old_resized else {
    fail("expected grow to resize atlas")
  }
  ignore(
    atlas.reserve(1U, 1U) catch {
      AtlasFull => fail("expected new edge space")
    },
  )
  assert_eq(atlas.data[atlas.size.reinterpret_as_int() + 1], 1)
  assert_eq(atlas.data[atlas.size.reinterpret_as_int() + 2], 2)
  assert_eq(atlas.data[(atlas.size * 2U).reinterpret_as_int() + 1], 3)
  assert_eq(atlas.data[(atlas.size * 2U).reinterpret_as_int() + 2], 4)
}

///|
test "atlas grow same size is no-op" {
  let atlas = Atlas::new(4U, Grayscale)
  let modified = atlas.modified
  let resized = atlas.resized
  atlas.grow(atlas.size)
  assert_eq(atlas.modified, modified)
  assert_eq(atlas.resized, resized)
}

///|
test "atlas writes BGR data" {
  let atlas = Atlas::new(32U, Bgr)
  let reg = atlas.reserve(1U, 2U) catch { AtlasFull => fail("expected region") }
  atlas.set(reg, [1, 2, 3, 4, 5, 6])
  let depth = atlas.format.depth().to_uint().reinterpret_as_int()
  assert_eq(atlas.data[33 * depth], 1)
  assert_eq(atlas.data[33 * depth + 1], 2)
  assert_eq(atlas.data[33 * depth + 2], 3)
  assert_eq(atlas.data[65 * depth], 4)
  assert_eq(atlas.data[65 * depth + 1], 5)
  assert_eq(atlas.data[65 * depth + 2], 6)
}

///|
test "atlas grow BGR" {
  let atlas = Atlas::new(4U, Bgr)
  let reg = atlas.reserve(2U, 2U) catch {
    AtlasFull => fail("expected initial region")
  }
  try atlas.reserve(1U, 1U) catch {
    AtlasFull => ()
  } noraise {
    _ => fail("expected full atlas")
  }
  atlas.set(reg, [10, 11, 12, 13, 14, 15, 20, 21, 22, 23, 24, 25])
  let depth = atlas.format.depth().to_uint().reinterpret_as_int()
  let mut tl = (atlas.size * depth.reinterpret_as_uint()).reinterpret_as_int() +
    depth
  assert_eq(atlas.data[tl], 10)
  assert_eq(atlas.data[tl + 1], 11)
  assert_eq(atlas.data[tl + 2], 12)
  assert_eq(atlas.data[tl + 3], 13)
  assert_eq(atlas.data[tl + 4], 14)
  assert_eq(atlas.data[tl + 5], 15)
  assert_eq(atlas.data[tl + 6], 0)
  tl += (atlas.size * depth.reinterpret_as_uint()).reinterpret_as_int()
  assert_eq(atlas.data[tl], 20)
  assert_eq(atlas.data[tl + 1], 21)
  assert_eq(atlas.data[tl + 2], 22)
  assert_eq(atlas.data[tl + 3], 23)
  assert_eq(atlas.data[tl + 4], 24)
  assert_eq(atlas.data[tl + 5], 25)
  assert_eq(atlas.data[tl + 6], 0)

  atlas.grow(atlas.size + 1U)
  tl = (atlas.size * depth.reinterpret_as_uint()).reinterpret_as_int() + depth
  assert_eq(atlas.data[tl], 10)
  assert_eq(atlas.data[tl + 1], 11)
  assert_eq(atlas.data[tl + 2], 12)
  assert_eq(atlas.data[tl + 3], 13)
  assert_eq(atlas.data[tl + 4], 14)
  assert_eq(atlas.data[tl + 5], 15)
  assert_eq(atlas.data[tl + 6], 0)
  tl += (atlas.size * depth.reinterpret_as_uint()).reinterpret_as_int()
  assert_eq(atlas.data[tl], 20)
  assert_eq(atlas.data[tl + 1], 21)
  assert_eq(atlas.data[tl + 2], 22)
  assert_eq(atlas.data[tl + 3], 23)
  assert_eq(atlas.data[tl + 4], 24)
  assert_eq(atlas.data[tl + 5], 25)
  assert_eq(atlas.data[tl + 6], 0)
  ignore(
    atlas.reserve(1U, 3U) catch {
      AtlasFull => fail("expected right edge")
    },
  )
  ignore(
    atlas.reserve(2U, 1U) catch {
      AtlasFull => fail("expected bottom edge")
    },
  )
  try atlas.reserve(1U, 1U) catch {
    AtlasFull => ()
  } noraise {
    _ => fail("expected full atlas")
  }
}

///|
test "atlas clear resets data and nodes" {
  let atlas = Atlas::new(4U, Grayscale)
  let reg = atlas.reserve(2U, 2U) catch {
    AtlasFull => fail("expected initial region")
  }
  atlas.set(reg, [1, 2, 3, 4])
  let old = atlas.modified
  atlas.clear()
  guard atlas.modified > old else { fail("expected clear to modify atlas") }
  guard atlas.nodes == [{ x: 1U, y: 1U, width: 2U }] else {
    fail("expected initial node after clear")
  }
  guard !atlas.data.contains(1) &&
    !atlas.data.contains(2) &&
    !atlas.data.contains(3) &&
    !atlas.data.contains(4) else {
    fail("expected clear to zero data")
  }
}

///|
test "panic atlas set rejects out-of-bounds region" {
  let atlas = Atlas::new(4U, Grayscale)
  atlas.set({ x: 3U, y: 1U, width: 1U, height: 1U }, [1])
}

///|
test "panic atlas grow cannot shrink" {
  let atlas = Atlas::new(4U, Grayscale)
  atlas.grow(3U)
}
