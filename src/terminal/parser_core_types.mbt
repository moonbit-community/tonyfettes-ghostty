///|
pub enum ParserState {
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
} derive(Eq, Debug)

///|
const ParserStateCount : Int = 14

///|
pub fn ParserState::ordinal(self : ParserState) -> Int {
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
pub fn parser_state_from_int(value : Int) -> ParserState? {
  match value {
    0 => Some(Ground)
    1 => Some(Escape)
    2 => Some(EscapeIntermediate)
    3 => Some(CsiEntry)
    4 => Some(CsiIntermediate)
    5 => Some(CsiParam)
    6 => Some(CsiIgnore)
    7 => Some(DcsEntry)
    8 => Some(DcsParam)
    9 => Some(DcsIntermediate)
    10 => Some(DcsPassthrough)
    11 => Some(DcsIgnore)
    12 => Some(OscString)
    13 => Some(SosPmApcString)
    _ => None
  }
}

///|
pub fn parser_state_count() -> Int {
  ParserStateCount
}

///|
pub enum TransitionAction {
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
} derive(Eq, Debug)

///|
pub fn TransitionAction::ordinal(self : TransitionAction) -> Int {
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
pub fn transition_action_from_int(value : Int) -> TransitionAction? {
  match value {
    0 => Some(None)
    1 => Some(Ignore)
    2 => Some(Print)
    3 => Some(Execute)
    4 => Some(Collect)
    5 => Some(Param)
    6 => Some(EscDispatch)
    7 => Some(CsiDispatch)
    8 => Some(Put)
    9 => Some(OscPut)
    10 => Some(ApcPut)
    _ => None
  }
}

///|
pub struct Transition {
  state : ParserState
  action : TransitionAction
} derive(Eq, Debug)
