///|
pub(all) enum TerminalResultCode {
  Success
  OutOfMemory
  InvalidValue
  OutOfSpace
  NoValue
} derive(Eq, Debug)

///|
pub fn TerminalResultCode::code(self : TerminalResultCode) -> Int {
  match self {
    Success => 0
    OutOfMemory => -1
    InvalidValue => -2
    OutOfSpace => -3
    NoValue => -4
  }
}

///|
pub fn terminal_result_code_from_int(value : Int) -> TerminalResultCode? {
  match value {
    0 => Some(TerminalResultCode::Success)
    -1 => Some(TerminalResultCode::OutOfMemory)
    -2 => Some(TerminalResultCode::InvalidValue)
    -3 => Some(TerminalResultCode::OutOfSpace)
    -4 => Some(TerminalResultCode::NoValue)
    _ => None
  }
}
