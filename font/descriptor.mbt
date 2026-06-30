///|
/// A four-byte OpenType variation axis identifier.
pub(all) struct FontVariationId {
  a : Byte
  b : Byte
  c : Byte
  d : Byte
} derive(Eq, Debug)

///|
pub fn FontVariationId::init(value : BytesView) -> FontVariationId {
  guard value.length() == 4 else {
    abort("FontVariationId requires four bytes")
  }
  { a: value[0], b: value[1], c: value[2], d: value[3] }
}

///|
pub fn FontVariationId::str(self : FontVariationId) -> Bytes {
  Bytes::from_array([self.a, self.b, self.c, self.d])
}

///|
pub(all) struct FontVariation {
  id : FontVariationId
  value : Double
} derive(Eq, Debug)

///|
/// Pure font-discovery descriptor. Platform discovery adapters are deferred.
pub(all) struct Descriptor {
  family : String?
  style : String?
  codepoint : UInt
  size : Float
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
  size? : Float = 0.0,
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
  hasher.combine_uint(self.size.reinterpret_as_uint())
  hasher.combine_bool(self.bold)
  hasher.combine_bool(self.italic)
  hasher.combine_bool(self.monospace)
  hasher.combine_int(self.variations.length())
  for variation in self.variations {
    hasher.combine_uint(font_variation_id_to_uint(variation.id))
    hasher.combine_int64(variation.value.to_int64())
  }
}

///|
fn font_variation_id_to_uint(id : FontVariationId) -> UInt {
  (id.a.to_uint() << 24) |
  (id.b.to_uint() << 16) |
  (id.c.to_uint() << 8) |
  id.d.to_uint()
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
