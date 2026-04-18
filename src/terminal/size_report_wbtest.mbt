///|
fn test_size() -> Size {
  { rows: 24, columns: 80, cell_width: 9, cell_height: 18 }
}

///|
test "size_report/encode mode 2048" {
  inspect(encode(Mode2048, test_size()), content="\u{001B}[48;24;80;432;720t")
}

///|
test "size_report/encode csi 14 t" {
  inspect(encode(Csi14t, test_size()), content="\u{001B}[4;432;720t")
}

///|
test "size_report/encode csi 16 t" {
  inspect(encode(Csi16t, test_size()), content="\u{001B}[6;18;9t")
}

///|
test "size_report/encode csi 18 t" {
  inspect(encode(Csi18t, test_size()), content="\u{001B}[8;24;80t")
}

///|
test "size_report/encode max values for all fields" {
  let max_size : Size = {
    rows: 0xFFFF,
    columns: 0xFFFF,
    cell_width: 0xFFFFFFFF,
    cell_height: 0xFFFFFFFF,
  }

  inspect(
    encode(Mode2048, max_size),
    content="\u{001B}[48;65535;65535;281470681677825;281470681677825t",
  )
  inspect(
    encode(Csi14t, max_size),
    content="\u{001B}[4;281470681677825;281470681677825t",
  )
  inspect(encode(Csi16t, max_size), content="\u{001B}[6;4294967295;4294967295t")
  inspect(encode(Csi18t, max_size), content="\u{001B}[8;65535;65535t")
}
