///|
struct TerminalDisplayState {
  mut status_display : StatusDisplay
  mut mouse_shape : MouseShape
} derive(Eq, Debug)

///|
pub fn TerminalDisplayState::new() -> TerminalDisplayState {
  { status_display: StatusDisplay::Main, mouse_shape: MouseShape::Text }
}

///|
pub fn TerminalDisplayState::status_display(
  self : TerminalDisplayState,
) -> StatusDisplay {
  self.status_display
}

///|
pub fn TerminalDisplayState::mouse_shape(
  self : TerminalDisplayState,
) -> MouseShape {
  self.mouse_shape
}

///|
pub fn TerminalDisplayState::set_status_display(
  self : TerminalDisplayState,
  status_display : StatusDisplay,
) -> Unit {
  self.status_display = status_display
}

///|
pub fn TerminalDisplayState::set_mouse_shape(
  self : TerminalDisplayState,
  mouse_shape : MouseShape,
) -> Unit {
  self.mouse_shape = mouse_shape
}

///|
pub fn TerminalDisplayState::full_reset(self : TerminalDisplayState) -> Unit {
  self.status_display = StatusDisplay::Main
}
