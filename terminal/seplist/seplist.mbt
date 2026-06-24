///|
/// Abstract (no `pub`): a colon-vs-semicolon separator bitset built and read
/// only through `init_empty`/`set`/`is_set`/`count`, so its backing word stays
/// sealed across the package boundary. An immutable `UInt64` newtype — like
/// upstream's `SepList = std.StaticBitSet(MAX_PARAMS)` (an `IntegerBitSet`, i.e.
/// an inline integer value), `set` returns a new bitset and the holder rebinds
/// its field, so the value is unboxed with no per-sequence heap allocation.
///
/// Lives in its own leaf package so the SGR parser can read separator runs
/// without importing the whole VT `parser` state machine (the only thing `sgr`
/// needed from `parser` was this type). Mirrors how upstream `sgr.zig` reaches
/// for `Parser.zig`'s `SepList`, but as a shared dependency rather than a
/// back-reference.
struct SepList(UInt64) derive(Debug)

///|
pub fn SepList::init_empty() -> SepList {
  0UL
}

///|
pub fn SepList::set(self : SepList, index : Int) -> SepList {
  self.0 | (1UL << index)
}

///|
pub fn SepList::is_set(self : SepList, index : Int) -> Bool {
  (self.0 & (1UL << index)) != 0UL
}

///|
/// Number of separators set. `set` only ever targets indices below the param
/// cap, so the high bits stay clear and a full-word popcount equals the count.
pub fn SepList::count(self : SepList) -> Int {
  self.0.popcnt()
}
