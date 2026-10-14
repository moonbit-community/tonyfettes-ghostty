///|
pub(all) struct CodepointMapEntry {
  range : (UInt32, UInt32)
  descriptor : Descriptor
} derive(Eq, Debug)

///|
/// A small ordered map from codepoint ranges to font descriptors.
pub(all) struct CodepointMap {
  mut list : Array[CodepointMapEntry]
} derive(Eq, Debug)

///|
pub fn CodepointMap::new() -> CodepointMap {
  { list: [], }
}

///|
pub fn CodepointMap::add(
  self : CodepointMap,
  entry : CodepointMapEntry,
) -> Unit {
  guard! entry.range.0 <= entry.range.1
  self.list.push(entry)
}

///|
pub fn CodepointMap::get(
  self : CodepointMap,
  codepoint : UInt32,
) -> Descriptor? {
  let len = self.list.length()
  for forward_i in 0..<len {
    let index = len - forward_i - 1
    let entry = self.list[index]
    if entry.range.0 <= codepoint && codepoint <= entry.range.1 {
      return Some(entry.descriptor)
    }
  }
  None
}

///|
pub fn CodepointMap::hashcode(self : CodepointMap) -> UInt32 {
  let hasher = Hasher(seed=0)
  hasher.combine_int(self.list.length())
  for entry in self.list {
    hasher.combine_uint(entry.range.0)
    hasher.combine_uint(entry.range.1)
    entry.descriptor.hash_combine(hasher)
  }
  hasher.finalize().reinterpret_as_uint()
}

///|
pub extend CodepointMapEntry with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend CodepointMapEntry with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend CodepointMapEntry with @debug.Debug::{to_repr}

///|
pub extend CodepointMap with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend CodepointMap with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend CodepointMap with @debug.Debug::{to_repr}
