///|
fn test_size() -> Size {
  { rows: 24, columns: 80, cell_width: 9, cell_height: 18 }
}

///|
test "size_report/encode mode 2048" {
  assert_eq(encode(Mode2048, test_size()), b"\x1B[48;24;80;432;720t")
}

///|
test "size_report/encode csi 14 t" {
  assert_eq(encode(Csi14t, test_size()), b"\x1B[4;432;720t")
}

///|
test "size_report/encode csi 16 t" {
  assert_eq(encode(Csi16t, test_size()), b"\x1B[6;18;9t")
}

///|
test "size_report/encode csi 18 t" {
  assert_eq(encode(Csi18t, test_size()), b"\x1B[8;24;80t")
}

///|
test "size_report/encode max values for all fields" {
  let max_size : Size = {
    rows: 0xFFFF,
    columns: 0xFFFF,
    cell_width: 0xFFFFFFFF,
    cell_height: 0xFFFFFFFF,
  }

  assert_eq(
    encode(Mode2048, max_size),
    b"\x1B[48;65535;65535;281470681677825;281470681677825t",
  )
  assert_eq(
    encode(Csi14t, max_size),
    b"\x1B[4;281470681677825;281470681677825t",
  )
  assert_eq(encode(Csi16t, max_size), b"\x1B[6;4294967295;4294967295t")
  assert_eq(encode(Csi18t, max_size), b"\x1B[8;65535;65535t")
}
