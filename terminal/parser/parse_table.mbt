///|
const ActionMask : Int = 0x0F

///|
fn decode_transition(code : Byte) -> Transition {
  let packed = code.to_int()
  let state = parser_state_from_int(packed >> 4)
  let action = transition_action_from_int(packed & ActionMask)
  { state, action }
}

///|
fn transition_for(byte : Byte, state : ParserState) -> Transition {
  let index = byte.to_int() * ParserStateCount + state.ordinal()
  decode_transition(transition_codes[index])
}
