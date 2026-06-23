///|
struct TerminalDisplayState {
  mut status_display : @ansi.StatusDisplay
  mut mouse_shape : @input.MouseShape
} derive(Eq, Debug)

///|
pub fn TerminalDisplayState::new() -> TerminalDisplayState {
  { status_display: Main, mouse_shape: Text }
}

///|
pub fn TerminalDisplayState::status_display(
  self : TerminalDisplayState,
) -> @ansi.StatusDisplay {
  self.status_display
}

///|
pub fn TerminalDisplayState::mouse_shape(
  self : TerminalDisplayState,
) -> @input.MouseShape {
  self.mouse_shape
}

///|
pub fn TerminalDisplayState::set_status_display(
  self : TerminalDisplayState,
  status_display : @ansi.StatusDisplay,
) -> Unit {
  self.status_display = status_display
}

///|
pub fn TerminalDisplayState::set_mouse_shape(
  self : TerminalDisplayState,
  mouse_shape : @input.MouseShape,
) -> Unit {
  self.mouse_shape = mouse_shape
}

///|
pub fn TerminalDisplayState::full_reset(self : TerminalDisplayState) -> Unit {
  self.status_display = Main
}
