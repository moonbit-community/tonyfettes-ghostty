///|
priv enum ParserState {
  Ground
  Escape
  EscapeIntermediate
  CsiEntry
  CsiIntermediate
  CsiParam
  CsiIgnore
  DcsEntry
  DcsParam
  DcsIntermediate
  DcsPassthrough
  DcsIgnore
  OscString
  SosPmApcString
} derive(Eq)

///|
const ParserStateCount : Int = 14

///|
fn ParserState::ordinal(self : ParserState) -> Int {
  match self {
    Ground => 0
    Escape => 1
    EscapeIntermediate => 2
    CsiEntry => 3
    CsiIntermediate => 4
    CsiParam => 5
    CsiIgnore => 6
    DcsEntry => 7
    DcsParam => 8
    DcsIntermediate => 9
    DcsPassthrough => 10
    DcsIgnore => 11
    OscString => 12
    SosPmApcString => 13
  }
}

///|
fn parser_state_from_int(value : Int) -> ParserState {
  match value {
    0 => Ground
    1 => Escape
    2 => EscapeIntermediate
    3 => CsiEntry
    4 => CsiIntermediate
    5 => CsiParam
    6 => CsiIgnore
    7 => DcsEntry
    8 => DcsParam
    9 => DcsIntermediate
    10 => DcsPassthrough
    11 => DcsIgnore
    12 => OscString
    13 => SosPmApcString
    _ => abort("invalid parse table state code")
  }
}

///|
priv enum TransitionAction {
  None
  Ignore
  Print
  Execute
  Collect
  Param
  EscDispatch
  CsiDispatch
  Put
  OscPut
  ApcPut
}

///|
fn transition_action_from_int(value : Int) -> TransitionAction {
  match value {
    0 => None
    1 => Ignore
    2 => Print
    3 => Execute
    4 => Collect
    5 => Param
    6 => EscDispatch
    7 => CsiDispatch
    8 => Put
    9 => OscPut
    10 => ApcPut
    _ => abort("invalid parse table action code")
  }
}

///|
#valtype
priv struct Transition {
  state : ParserState
  action : TransitionAction
}
