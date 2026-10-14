///|
pub(all) enum TerminalResultCode {
  Success
  OutOfMemory
  InvalidValue
  OutOfSpace
  NoValue
} derive(Eq, Debug)

///|
pub fn TerminalResultCode::code(self : TerminalResultCode) -> Int32 {
  match self {
    Success => 0
    OutOfMemory => -1
    InvalidValue => -2
    OutOfSpace => -3
    NoValue => -4
  }
}

///|
pub fn terminal_result_code_from_int(value : Int32) -> TerminalResultCode? {
  match value {
    0 => Some(Success)
    -1 => Some(OutOfMemory)
    -2 => Some(InvalidValue)
    -3 => Some(OutOfSpace)
    -4 => Some(NoValue)
    _ => None
  }
}

///|
pub extend TerminalResultCode with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend TerminalResultCode with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend TerminalResultCode with @debug.Debug::{to_repr}
