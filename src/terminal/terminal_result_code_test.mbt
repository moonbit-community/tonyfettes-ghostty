///|
test "terminal_result_code/code values match upstream" {
  let cases : Array[(TerminalResultCode, Int)] = [
    (TerminalResultCode::Success, 0),
    (TerminalResultCode::OutOfMemory, -1),
    (TerminalResultCode::InvalidValue, -2),
    (TerminalResultCode::OutOfSpace, -3),
    (TerminalResultCode::NoValue, -4),
  ]

  for entry in cases {
    assert_eq(entry.0.code(), entry.1)
    guard terminal_result_code_from_int(entry.1) == Some(entry.0) else {
      fail("expected roundtrip result code for \{entry.1}")
    }
  }
}

///|
test "terminal_result_code/from_int rejects unknown values" {
  guard terminal_result_code_from_int(1) == None else {
    fail("positive status should be rejected")
  }
  guard terminal_result_code_from_int(-5) == None else {
    fail("unknown negative status should be rejected")
  }
}
