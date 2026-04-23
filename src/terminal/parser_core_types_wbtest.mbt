///|

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

  assert_eq(parser_state_count(), states.length())
  for entry in states {
    assert_eq(entry.0.ordinal(), entry.1)
    guard parser_state_from_int(entry.1) == Some(entry.0) else {
      fail("expected parser state roundtrip for \{entry.1}")
    }
  }

  guard parser_state_from_int(-1) == None else {
    fail("expected negative parser state to be rejected")
  }
  guard parser_state_from_int(parser_state_count()) == None else {
    fail("expected parser state overflow to be rejected")
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
    guard transition_action_from_int(entry.1) is Some(found) &&
      found.ordinal() == entry.1 else {
      fail("expected transition action roundtrip for \{entry.1}")
    }
  }

  guard transition_action_from_int(-1) is None else {
    fail("expected negative transition action to be rejected")
  }
  guard transition_action_from_int(actions.length()) is None else {
    fail("expected transition action overflow to be rejected")
  }
}
