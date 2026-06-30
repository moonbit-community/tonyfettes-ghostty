///|
pub(all) struct CodepointMapEntry {
  start : UInt
  end : UInt
  descriptor : Descriptor
} derive(Eq, Debug)

///|
/// A small ordered map from codepoint ranges to font descriptors.
struct CodepointMap {
  entries : Array[CodepointMapEntry]
} derive(Eq, Debug)

///|
pub fn CodepointMap::new() -> CodepointMap {
  { entries: [] }
}

///|
pub fn CodepointMap::add(
  self : CodepointMap,
  entry : CodepointMapEntry,
) -> Unit {
  guard entry.start <= entry.end
  self.entries.push(entry)
}

///|
pub fn CodepointMap::get(self : CodepointMap, codepoint : UInt) -> Descriptor? {
  let len = self.entries.length()
  for forward_i in 0..<len {
    let index = len - forward_i - 1
    let entry = self.entries[index]
    if entry.start <= codepoint && codepoint <= entry.end {
      return Some(entry.descriptor)
    }
  }
  None
}

///|
pub fn CodepointMap::hashcode(self : CodepointMap) -> UInt {
  let hasher = Hasher(seed=0)
  hasher.combine_int(self.entries.length())
  for entry in self.entries {
    hasher.combine_uint(entry.start)
    hasher.combine_uint(entry.end)
    entry.descriptor.hash_combine(hasher)
  }
  hasher.finalize().reinterpret_as_uint()
}
