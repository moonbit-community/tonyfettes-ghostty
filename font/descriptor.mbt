///|
/// A four-byte OpenType variation axis identifier.
struct FontVariationId(UInt) derive(Eq, Debug)

///|
pub fn FontVariationId::new(
  a : Byte,
  b : Byte,
  c : Byte,
  d : Byte,
) -> FontVariationId {
  FontVariationId(
    (a.to_uint() << 24) | (b.to_uint() << 16) | (c.to_uint() << 8) | d.to_uint(),
  )
}

///|
pub fn FontVariationId::to_uint(self : FontVariationId) -> UInt {
  self.0
}

///|
pub(all) struct FontVariation {
  id : FontVariationId
  value : Double
} derive(Eq, Debug)

///|
/// Pure font-discovery descriptor. Platform discovery adapters are deferred.
struct Descriptor {
  family : String?
  style : String?
  codepoint : UInt
  size : Double
  bold : Bool
  italic : Bool
  monospace : Bool
  variations : Array[FontVariation]
} derive(Eq, Debug)

///|
pub fn Descriptor::new(
  family? : String? = None,
  style? : String? = None,
  codepoint? : UInt = 0U,
  size? : Double = 0.0,
  bold? : Bool = false,
  italic? : Bool = false,
  monospace? : Bool = false,
  variations? : Array[FontVariation] = [],
) -> Descriptor {
  {
    family,
    style,
    codepoint,
    size,
    bold,
    italic,
    monospace,
    variations: clone_variations(variations),
  }
}

///|
pub fn Descriptor::family(self : Descriptor) -> String? {
  self.family
}

///|
pub fn Descriptor::style(self : Descriptor) -> String? {
  self.style
}

///|
pub fn Descriptor::codepoint(self : Descriptor) -> UInt {
  self.codepoint
}

///|
pub fn Descriptor::size(self : Descriptor) -> Double {
  self.size
}

///|
pub fn Descriptor::bold(self : Descriptor) -> Bool {
  self.bold
}

///|
pub fn Descriptor::italic(self : Descriptor) -> Bool {
  self.italic
}

///|
pub fn Descriptor::monospace(self : Descriptor) -> Bool {
  self.monospace
}

///|
pub fn Descriptor::variations(self : Descriptor) -> Array[FontVariation] {
  clone_variations(self.variations)
}

///|
pub fn Descriptor::hashcode(self : Descriptor) -> UInt {
  let hasher = Hasher(seed=0)
  self.hash_combine(hasher)
  hasher.finalize().reinterpret_as_uint()
}

///|
fn Descriptor::hash_combine(self : Descriptor, hasher : Hasher) -> Unit {
  hash_optional_string(hasher, self.family)
  hash_optional_string(hasher, self.style)
  hasher.combine_uint(self.codepoint)
  hasher.combine_double(self.size)
  hasher.combine_bool(self.bold)
  hasher.combine_bool(self.italic)
  hasher.combine_bool(self.monospace)
  hasher.combine_int(self.variations.length())
  for variation in self.variations {
    hasher.combine_uint(variation.id.to_uint())
    hasher.combine_double(variation.value)
  }
}

///|
fn hash_optional_string(hasher : Hasher, value : String?) -> Unit {
  match value {
    Some(text) => {
      hasher.combine_bool(true)
      hasher.combine_string(text)
    }
    None => hasher.combine_bool(false)
  }
}

///|
fn clone_variations(source : Array[FontVariation]) -> Array[FontVariation] {
  let result : Array[FontVariation] = []
  for variation in source {
    result.push(variation)
  }
  result
}
