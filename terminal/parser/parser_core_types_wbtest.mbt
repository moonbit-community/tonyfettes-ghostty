///|
fn TransitionAction::ordinal(self : TransitionAction) -> Int {
  match self {
    None => 0
    Ignore => 1
    Print => 2
    Execute => 3
    Collect => 4
    Param => 5
    EscDispatch => 6
    CsiDispatch => 7
    Put => 8
    OscPut => 9
    ApcPut => 10
  }
}

///|
test "parser core types/parser state roundtrip and count" {
  let states : Array[(ParserState, Int)] = [
    (Ground, 0),
    (Escape, 1),
    (EscapeIntermediate, 2),
    (CsiEntry, 3),
    (CsiIntermediate, 4),
    (CsiParam, 5),
    (CsiIgnore, 6),
    (DcsEntry, 7),
    (DcsParam, 8),
    (DcsIntermediate, 9),
    (DcsPassthrough, 10),
    (DcsIgnore, 11),
    (OscString, 12),
    (SosPmApcString, 13),
  ]

  assert_eq(ParserStateCount, states.length())
  for entry in states {
    assert_eq(entry.0.ordinal(), entry.1)
    guard parser_state_from_int(entry.1) == entry.0 else {
      fail("expected parser state roundtrip for \{entry.1}")
    }
  }
}

///|
test "parser core types/transition action roundtrip" {
  let actions : Array[(TransitionAction, Int)] = [
    (None, 0),
    (Ignore, 1),
    (Print, 2),
    (Execute, 3),
    (Collect, 4),
    (Param, 5),
    (EscDispatch, 6),
    (CsiDispatch, 7),
    (Put, 8),
    (OscPut, 9),
    (ApcPut, 10),
  ]

  for entry in actions {
    assert_eq(entry.0.ordinal(), entry.1)
    guard transition_action_from_int(entry.1).ordinal() == entry.1 else {
      fail("expected transition action roundtrip for \{entry.1}")
    }
  }
}
