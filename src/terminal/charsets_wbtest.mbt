///|
test "charsets/non utf8 tables have length 256" {
  assert_eq(table(Charset::Ascii).length(), 256)
  assert_eq(table(Charset::British).length(), 256)
  assert_eq(table(Charset::DecSpecial).length(), 256)
}

///|
test "charsets/british remaps hash to pound" {
  assert_eq(table(Charset::Ascii)[0x23], 0x23)
  assert_eq(table(Charset::British)[0x23], 0x00A3)
  assert_eq(table(Charset::British)[0x24], 0x24)
}

///|
test "charsets/dec special mappings preserve line drawing entries" {
  let table_ = table(Charset::DecSpecial)
  assert_eq(table_[0x60], 0x25C6)
  assert_eq(table_[0x61], 0x2592)
  assert_eq(table_[0x62], 0x2409)
  assert_eq(table_[0x63], 0x240C)
  assert_eq(table_[0x64], 0x240D)
  assert_eq(table_[0x65], 0x240A)
  assert_eq(table_[0x66], 0x00B0)
  assert_eq(table_[0x67], 0x00B1)
  assert_eq(table_[0x68], 0x2424)
  assert_eq(table_[0x69], 0x240B)
  assert_eq(table_[0x6A], 0x2518)
  assert_eq(table_[0x6B], 0x2510)
  assert_eq(table_[0x6C], 0x250C)
  assert_eq(table_[0x6D], 0x2514)
  assert_eq(table_[0x6E], 0x253C)
  assert_eq(table_[0x6F], 0x23BA)
  assert_eq(table_[0x70], 0x23BB)
  assert_eq(table_[0x71], 0x2500)
  assert_eq(table_[0x72], 0x23BC)
  assert_eq(table_[0x73], 0x23BD)
  assert_eq(table_[0x74], 0x251C)
  assert_eq(table_[0x75], 0x2524)
  assert_eq(table_[0x76], 0x2534)
  assert_eq(table_[0x77], 0x252C)
  assert_eq(table_[0x78], 0x2502)
  assert_eq(table_[0x7E], 0x00B7)
  assert_eq(table_[0x79], 0x2264)
  assert_eq(table_[0x7A], 0x2265)
  assert_eq(table_[0x7B], 0x03C0)
  assert_eq(table_[0x7C], 0x2260)
  assert_eq(table_[0x7D], 0x00A3)
}
