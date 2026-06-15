// Compare lookup strategies for a case-insensitive string table at a realistic
// size (~700 entries, the order of the X11 color table this map was built for).
// All candidates are fed the same `BytesView` keys, so the only difference is
// the lookup itself:
//   - linear_scan: scan an array, case-folding each candidate (the old impl)
//   - cimap_get_view: this package's open-addressing map, zero-alloc probe
//   - std_map_bytes_key: core `Map[Bytes, Int]`, allocating a lowercased key
//                        per lookup (the cost `get_view` avoids)

///|
fn bench_dataset() -> Array[(String, Int)] {
  let shades = ["", "light", "dark", "medium", "pale", "deep", "bright"]
  let bases = [
    "red", "green", "blue", "cyan", "magenta", "yellow", "white", "black", "navy",
    "teal", "olive", "maroon", "silver", "gray", "orange", "purple", "brown", "pink",
    "gold", "coral",
  ]
  let entries : Array[(String, Int)] = []
  for shade in shades {
    for base in bases {
      entries.push((shade + base, entries.length()))
      for n in 0..<4 {
        entries.push((shade + base + n.to_string(), entries.length()))
      }
    }
  }
  entries
}

///|
fn lower_bytes_view(view : BytesView) -> Bytes {
  let n = view.length()
  let buf = FixedArray::make(n, b'0')
  for i in 0..<n {
    let c = view[i]
    buf[i] = if c >= b'A' && c <= b'Z' {
      (c.to_int() + 32).to_byte()
    } else {
      c
    }
  }
  buf.unsafe_reinterpret_as_bytes()
}

///|
fn lower_bytes_string(name : String) -> Bytes {
  let n = name.length()
  let buf = FixedArray::make(n, b'0')
  for i in 0..<n {
    let c = name[i].to_int()
    buf[i] = (if c >= 0x41 && c <= 0x5A { c + 32 } else { c }).to_byte()
  }
  buf.unsafe_reinterpret_as_bytes()
}

///|
fn linear_scan_lookup(entries : Array[(String, Int)], view : BytesView) -> Int? {
  for entry in entries {
    let name = entry.0
    if name.length() != view.length() {
      continue
    }
    let mut equal = true
    for j in 0..<name.length() {
      let a = name[j].to_int()
      let a = if a >= 0x41 && a <= 0x5A { a + 32 } else { a }
      let b = view[j].to_int()
      let b = if b >= 0x41 && b <= 0x5A { b + 32 } else { b }
      if a != b {
        equal = false
        break
      }
    }
    if equal {
      return Some(entry.1)
    }
  }
  None
}

///|
test (b : @bench.T) {
  let entries = bench_dataset()
  let cimap = CiStrMap::from_entries(ReadOnlyArray::from_iter(entries.iter()))
  let std_map : Map[Bytes, Int] = {}
  for entry in entries {
    std_map[lower_bytes_string(entry.0)] = entry.1
  }

  // Hits spread across the table (mixed case) plus name-like misses.
  let keys : Array[Bytes] = [
    b"red", b"LightBlue", b"darkgreen", b"mediumpurple2", b"BrightCoral", b"navy",
    b"palegold3", b"deepteal", b"white", b"notacolor", b"lightlightred", b"brightbrown1",
  ]
  b.bench(name="linear_scan", fn() {
    for k in keys {
      b.keep(linear_scan_lookup(entries, k))
    }
  })
  b.bench(name="cimap_get_view", fn() {
    for k in keys {
      b.keep(cimap.get_view(k))
    }
  })
  b.bench(name="std_map_bytes_key", fn() {
    for k in keys {
      b.keep(std_map.get(lower_bytes_view(k)))
    }
  })
}
