// Case-insensitive (ASCII) string-keyed map. Build-once and read-only, so it
// uses plain open addressing with linear probing (no tombstones / deletion).
// Keys are hashed and compared with ASCII case folding, and `get_view` probes
// with a `BytesView`, so a caller parsing raw bytes can look up without
// allocating a normalized key.

///|
struct CiStrMap[V] {
  // `None` marks an empty slot; capacity is a power of two and always strictly
  // larger than the entry count, so a missing key always reaches a `None`.
  slots : FixedArray[(String, V)?]
  mask : Int
}

///|
/// Build a map from `(name, value)` entries. Later duplicates of a name (under
/// case folding) are unreachable — the first inserted wins on lookup.
pub fn[V] CiStrMap::from_entries(
  entries : ReadOnlyArray[(String, V)],
) -> CiStrMap[V] {
  let mut cap = 1
  while cap < entries.length() * 2 {
    cap = cap * 2
  }
  let slots : FixedArray[(String, V)?] = FixedArray::make(cap, None)
  let mask = cap - 1
  for entry in entries.iter() {
    let mut idx = fnv1a_string(entry.0) & mask
    while slots[idx] is Some(_) {
      idx = (idx + 1) & mask
    }
    slots[idx] = Some(entry)
  }
  { slots, mask }
}

///|
/// Look up by a `String` key (ASCII case-insensitive).
pub fn[V] CiStrMap::get(self : CiStrMap[V], key : String) -> V? {
  let mask = self.mask
  for idx = fnv1a_string(key) & mask {
    match self.slots[idx] {
      None => break None
      Some((name, value)) =>
        if string_eq_ignore_case(name, key) {
          break Some(value)
        } else {
          continue (idx + 1) & mask
        }
    }
  }
}

///|
/// Look up by a byte view (ASCII case-insensitive). No allocation: the view is
/// hashed and compared in place against the stored names.
pub fn[V] CiStrMap::get_view(self : CiStrMap[V], key : BytesView) -> V? {
  let mask = self.mask
  for idx = fnv1a_view(key) & mask {
    match self.slots[idx] {
      None => break None
      Some((name, value)) =>
        if view_eq_ignore_case(name, key) {
          break Some(value)
        } else {
          continue (idx + 1) & mask
        }
    }
  }
}

///|
/// ASCII lowercase a single code unit; non-letters pass through.
fn ascii_lower(code : Int) -> Int {
  if code >= 0x41 && code <= 0x5A {
    code + 0x20
  } else {
    code
  }
}

///|
/// FNV-1a over the ASCII-lowercased bytes. `Int` is 32-bit and wraps, matching
/// the 32-bit FNV reference. `fnv1a_string` must agree byte-for-byte with
/// `fnv1a_view` on ASCII so a `String` and an equal `BytesView` collide.
fn fnv1a_string(key : String) -> Int {
  let mut hash = 0x811c9dc5
  for i in 0..<key.length() {
    hash = (hash ^ ascii_lower(key[i].to_int())) * 0x01000193
  }
  hash
}

///|
fn fnv1a_view(key : BytesView) -> Int {
  let mut hash = 0x811c9dc5
  for byte in key {
    hash = (hash ^ ascii_lower(byte.to_int())) * 0x01000193
  }
  hash
}

///|
fn string_eq_ignore_case(name : String, key : String) -> Bool {
  guard name.length() == key.length() else { return false }
  for i in 0..<name.length() {
    if ascii_lower(name[i].to_int()) != ascii_lower(key[i].to_int()) {
      return false
    }
  }
  true
}

///|
fn view_eq_ignore_case(name : String, key : BytesView) -> Bool {
  guard name.length() == key.length() else { return false }
  for i in 0..<name.length() {
    if ascii_lower(name[i].to_int()) != ascii_lower(key[i].to_int()) {
      return false
    }
  }
  true
}
