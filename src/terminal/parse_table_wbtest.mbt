///|

///|
fn transition_action_ordinal(action : TransitionAction) -> Int {
  match action {
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
fn expect_transition(
  transition : Transition,
  state : ParserState,
  action : TransitionAction,
  message : String,
) -> Unit raise {
  guard transition.state == state &&
    transition_action_ordinal(transition.action) ==
    transition_action_ordinal(action) else {
    fail(message)
  }
}

///|
test "parse table/anywhere transitions" {
  let escape = transition_for(0x1B, Ground)
  expect_transition(escape, Escape, None, "expected ESC anywhere transition")

  let csi = transition_for(0x9B, DcsIgnore)
  expect_transition(csi, CsiEntry, None, "expected C1 CSI anywhere transition")

  let dcs = transition_for(0x90, Ground)
  expect_transition(dcs, DcsEntry, None, "expected C1 DCS anywhere transition")

  let osc = transition_for(0x9D, Ground)
  expect_transition(osc, OscString, None, "expected C1 OSC anywhere transition")

  let st = transition_for(0x9C, DcsPassthrough)
  expect_transition(st, Ground, None, "expected ST anywhere transition")

  let cancel = transition_for(0x18, Escape)
  expect_transition(cancel, Ground, Execute, "expected CAN anywhere transition")
}

///|
test "parse table/ground transitions" {
  let printable = transition_for(0x41, Ground)
  expect_transition(
    printable,
    Ground,
    Print,
    "expected printable ground transition",
  )

  let execute = transition_for(0x1F, Ground)
  expect_transition(
    execute,
    Ground,
    Execute,
    "expected execute ground transition",
  )
}

///|
test "parse table/escape transitions" {
  let intermediate = transition_for(0x28, Escape)
  expect_transition(
    intermediate,
    EscapeIntermediate,
    Collect,
    "expected ESC intermediate collect",
  )

  let dispatch = transition_for(0x42, EscapeIntermediate)
  expect_transition(
    dispatch,
    Ground,
    EscDispatch,
    "expected ESC intermediate dispatch",
  )
}

///|
test "parse table/csi transitions preserve colon rules" {
  let entry_digit = transition_for(0x30, CsiEntry)
  expect_transition(
    entry_digit,
    CsiParam,
    Param,
    "expected CSI digit to enter param state",
  )

  let entry_semicolon = transition_for(0x3B, CsiEntry)
  expect_transition(
    entry_semicolon,
    CsiParam,
    Param,
    "expected CSI semicolon to stay in param state",
  )

  let entry_colon = transition_for(0x3A, CsiEntry)
  expect_transition(
    entry_colon,
    CsiIgnore,
    None,
    "expected CSI entry colon to go to ignore state",
  )

  let param_colon = transition_for(0x3A, CsiParam)
  expect_transition(
    param_colon,
    CsiParam,
    Param,
    "expected CSI param colon to be preserved",
  )

  let dispatch = transition_for(0x41, CsiParam)
  expect_transition(
    dispatch,
    Ground,
    CsiDispatch,
    "expected CSI final byte dispatch",
  )

  let delete = transition_for(0x7F, CsiParam)
  expect_transition(
    delete,
    CsiParam,
    Ignore,
    "expected DEL to be ignored in CSI param",
  )
}

///|
test "parse table/dcs transitions" {
  let entry = transition_for(0x50, Escape)
  expect_transition(entry, DcsEntry, None, "expected ESC P to enter DCS")

  let entry_colon = transition_for(0x3A, DcsEntry)
  expect_transition(
    entry_colon,
    DcsIgnore,
    None,
    "expected DCS entry colon to ignore",
  )

  let passthrough = transition_for(0x41, DcsPassthrough)
  expect_transition(
    passthrough,
    DcsPassthrough,
    Put,
    "expected DCS passthrough put",
  )

  let fallback = transition_for(0x30, DcsIgnore)
  expect_transition(fallback, DcsIgnore, None, "expected DCS ignore fallback")
}

///|
test "parse table/osc and apc transitions" {
  let osc_put = transition_for(0x41, OscString)
  expect_transition(osc_put, OscString, OscPut, "expected OSC payload byte")

  let osc_bel = transition_for(0x07, OscString)
  expect_transition(osc_bel, Ground, None, "expected BEL to terminate OSC")

  let apc_put = transition_for(0x41, SosPmApcString)
  expect_transition(
    apc_put,
    SosPmApcString,
    ApcPut,
    "expected APC payload byte",
  )
}

///|
test "parse table/decode transition unpacks state and action nibbles" {
  let decoded = decode_transition(0x58)
  expect_transition(decoded, CsiParam, Put, "expected packed transition decode")
}

///|
test "panic parse table/decode transition rejects invalid state nibble" {
  ignore(decode_transition(0xE0))
}

///|
test "panic parse table/decode transition rejects invalid action nibble" {
  ignore(decode_transition(0x0B))
}
