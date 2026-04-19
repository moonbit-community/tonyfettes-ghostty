///|
const ActionMask : Int = 0x0F

///|
fn decode_transition(code : Byte) -> Transition {
  let packed = code.to_int()
  let state = match parser_state_from_int(packed >> 4) {
    Some(state) => state
    None => abort("invalid parse table state code")
  }
  let action = match transition_action_from_int(packed & ActionMask) {
    Some(action) => action
    None => abort("invalid parse table action code")
  }
  { state, action }
}

///|
pub fn transition_for(byte : Byte, state : ParserState) -> Transition {
  let index = byte.to_int() * parser_state_count() + state.ordinal()
  decode_transition(transition_codes[index])
}
