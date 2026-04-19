///|
test "parse table/anywhere transitions" {
  let escape = transition_for(0x1B, Ground)
  guard escape.state == Escape && escape.action == None else {
    fail("expected ESC anywhere transition")
  }

  let csi = transition_for(0x9B, DcsIgnore)
  guard csi.state == CsiEntry && csi.action == None else {
    fail("expected C1 CSI anywhere transition")
  }

  let dcs = transition_for(0x90, Ground)
  guard dcs.state == DcsEntry && dcs.action == None else {
    fail("expected C1 DCS anywhere transition")
  }

  let osc = transition_for(0x9D, Ground)
  guard osc.state == OscString && osc.action == None else {
    fail("expected C1 OSC anywhere transition")
  }

  let st = transition_for(0x9C, DcsPassthrough)
  guard st.state == Ground && st.action == None else {
    fail("expected ST anywhere transition")
  }

  let cancel = transition_for(0x18, Escape)
  guard cancel.state == Ground && cancel.action == Execute else {
    fail("expected CAN anywhere transition")
  }
}

///|
test "parse table/ground transitions" {
  let printable = transition_for(0x41, Ground)
  guard printable.state == Ground && printable.action == Print else {
    fail("expected printable ground transition")
  }

  let execute = transition_for(0x1F, Ground)
  guard execute.state == Ground && execute.action == Execute else {
    fail("expected execute ground transition")
  }
}

///|
test "parse table/escape transitions" {
  let intermediate = transition_for(0x28, Escape)
  guard intermediate.state == EscapeIntermediate &&
    intermediate.action == Collect else {
    fail("expected ESC intermediate collect")
  }

  let dispatch = transition_for(0x42, EscapeIntermediate)
  guard dispatch.state == Ground && dispatch.action == EscDispatch else {
    fail("expected ESC intermediate dispatch")
  }
}

///|
test "parse table/csi transitions preserve colon rules" {
  let entry_digit = transition_for(0x30, CsiEntry)
  guard entry_digit.state == CsiParam && entry_digit.action == Param else {
    fail("expected CSI digit to enter param state")
  }

  let entry_semicolon = transition_for(0x3B, CsiEntry)
  guard entry_semicolon.state == CsiParam && entry_semicolon.action == Param else {
    fail("expected CSI semicolon to stay in param state")
  }

  let entry_colon = transition_for(0x3A, CsiEntry)
  guard entry_colon.state == CsiIgnore && entry_colon.action == None else {
    fail("expected CSI entry colon to go to ignore state")
  }

  let param_colon = transition_for(0x3A, CsiParam)
  guard param_colon.state == CsiParam && param_colon.action == Param else {
    fail("expected CSI param colon to be preserved")
  }

  let dispatch = transition_for(0x41, CsiParam)
  guard dispatch.state == Ground && dispatch.action == CsiDispatch else {
    fail("expected CSI final byte dispatch")
  }

  let delete = transition_for(0x7F, CsiParam)
  guard delete.state == CsiParam && delete.action == Ignore else {
    fail("expected DEL to be ignored in CSI param")
  }
}

///|
test "parse table/dcs transitions" {
  let entry = transition_for(0x50, Escape)
  guard entry.state == DcsEntry && entry.action == None else {
    fail("expected ESC P to enter DCS")
  }

  let entry_colon = transition_for(0x3A, DcsEntry)
  guard entry_colon.state == DcsIgnore && entry_colon.action == None else {
    fail("expected DCS entry colon to ignore")
  }

  let passthrough = transition_for(0x41, DcsPassthrough)
  guard passthrough.state == DcsPassthrough && passthrough.action == Put else {
    fail("expected DCS passthrough put")
  }

  let fallback = transition_for(0x30, DcsIgnore)
  guard fallback.state == DcsIgnore && fallback.action == None else {
    fail("expected DCS ignore fallback")
  }
}

///|
test "parse table/osc and apc transitions" {
  let osc_put = transition_for(0x41, OscString)
  guard osc_put.state == OscString && osc_put.action == OscPut else {
    fail("expected OSC payload byte")
  }

  let osc_bel = transition_for(0x07, OscString)
  guard osc_bel.state == Ground && osc_bel.action == None else {
    fail("expected BEL to terminate OSC")
  }

  let apc_put = transition_for(0x41, SosPmApcString)
  guard apc_put.state == SosPmApcString && apc_put.action == ApcPut else {
    fail("expected APC payload byte")
  }
}

///|
test "parse table/decode transition unpacks state and action nibbles" {
  let decoded = decode_transition(0x58)
  guard decoded.state == CsiParam && decoded.action == Put else {
    fail("expected packed transition decode")
  }
}

///|
test "panic parse table/decode transition rejects invalid state nibble" {
  ignore(decode_transition(0xE0))
}

///|
test "panic parse table/decode transition rejects invalid action nibble" {
  ignore(decode_transition(0x0B))
}
