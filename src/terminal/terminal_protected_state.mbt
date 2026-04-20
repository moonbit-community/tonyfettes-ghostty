///|
struct ScreenProtectedState {
  mut mode : ProtectedMode
  mut cursor_protected : Bool
} derive(Eq, Debug)

///|
pub fn ScreenProtectedState::new() -> ScreenProtectedState {
  { mode: ProtectedMode::Off, cursor_protected: false }
}

///|
pub fn ScreenProtectedState::mode(self : ScreenProtectedState) -> ProtectedMode {
  self.mode
}

///|
pub fn ScreenProtectedState::cursor_protected(
  self : ScreenProtectedState,
) -> Bool {
  self.cursor_protected
}

///|
pub fn ScreenProtectedState::set(
  self : ScreenProtectedState,
  mode : ProtectedMode,
) -> Unit {
  match mode {
    Off => self.cursor_protected = false
    Iso => {
      self.cursor_protected = true
      self.mode = ProtectedMode::Iso
    }
    Dec => {
      self.cursor_protected = true
      self.mode = ProtectedMode::Dec
    }
  }
}

///|
pub fn ScreenProtectedState::reset(self : ScreenProtectedState) -> Unit {
  self.mode = ProtectedMode::Off
  self.cursor_protected = false
}
