///|
pub enum Slots {
  G0
  G1
  G2
  G3
} derive(Eq, Debug)

///|
pub enum ActiveSlot {
  Gl
  Gr
} derive(Eq, Debug)

///|
pub enum Charset {
  Utf8
  Ascii
  British
  DecSpecial
} derive(Eq, Debug)

///|
pub type CharsetTable = ReadOnlyArray[UInt16]

///|
const TableLen : Int = 256

///|
fn init_table() -> FixedArray[UInt16] {
  FixedArray::makei(TableLen, fn(i) { i.to_uint16() })
}

///|
let ascii_table : CharsetTable = ReadOnlyArray::from_array(init_table())

///|
let british_table : CharsetTable = {
  let table = init_table()
  table[0x23] = 0x00A3
  ReadOnlyArray::from_array(table)
}

///|
let dec_special_table : CharsetTable = {
  let table = init_table()
  table[0x60] = 0x25C6
  table[0x61] = 0x2592
  table[0x62] = 0x2409
  table[0x63] = 0x240C
  table[0x64] = 0x240D
  table[0x65] = 0x240A
  table[0x66] = 0x00B0
  table[0x67] = 0x00B1
  table[0x68] = 0x2424
  table[0x69] = 0x240B
  table[0x6A] = 0x2518
  table[0x6B] = 0x2510
  table[0x6C] = 0x250C
  table[0x6D] = 0x2514
  table[0x6E] = 0x253C
  table[0x6F] = 0x23BA
  table[0x70] = 0x23BB
  table[0x71] = 0x2500
  table[0x72] = 0x23BC
  table[0x73] = 0x23BD
  table[0x74] = 0x251C
  table[0x75] = 0x2524
  table[0x76] = 0x2534
  table[0x77] = 0x252C
  table[0x78] = 0x2502
  table[0x79] = 0x2264
  table[0x7A] = 0x2265
  table[0x7B] = 0x03C0
  table[0x7C] = 0x2260
  table[0x7D] = 0x00A3
  table[0x7E] = 0x00B7
  ReadOnlyArray::from_array(table)
}

///|
pub fn table(set : Charset) -> CharsetTable {
  match set {
    British => british_table
    DecSpecial => dec_special_table
    Ascii => ascii_table
    Utf8 => abort("Utf8 does not use a mapping table")
  }
}
