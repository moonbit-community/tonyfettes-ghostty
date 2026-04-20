///|
test "terminal state/protected mode defaults and reset" {
  let state = ScreenProtectedState::new()
  guard state.mode() == ProtectedMode::Off && !state.cursor_protected() else {
    fail("expected protected state defaults")
  }

  state.set(ProtectedMode::Iso)
  guard state.mode() == ProtectedMode::Iso && state.cursor_protected() else {
    fail("expected iso protected mode to set cursor protection")
  }

  state.reset()
  guard state.mode() == ProtectedMode::Off && !state.cursor_protected() else {
    fail("expected protected state reset")
  }
}

///|
test "terminal state/protected off preserves last non-off mode" {
  let state = ScreenProtectedState::new()
  state.set(ProtectedMode::Iso)
  state.set(ProtectedMode::Off)
  guard state.mode() == ProtectedMode::Iso && !state.cursor_protected() else {
    fail("expected off to clear cursor protection without clearing last mode")
  }

  state.set(ProtectedMode::Dec)
  guard state.mode() == ProtectedMode::Dec && state.cursor_protected() else {
    fail("expected dec protected mode to become current")
  }
}

///|
test "terminal state/display defaults and setters" {
  let state = TerminalDisplayState::new()
  guard state.status_display() == StatusDisplay::Main &&
    state.mouse_shape() == MouseShape::Text else {
    fail("expected terminal display defaults")
  }

  state.set_status_display(StatusDisplay::StatusLine)
  state.set_mouse_shape(MouseShape::Pointer)
  guard state.status_display() == StatusDisplay::StatusLine &&
    state.mouse_shape() == MouseShape::Pointer else {
    fail("expected terminal display setters to update state")
  }
}

///|
test "terminal state/full reset restores main status display only" {
  let state = TerminalDisplayState::new()
  state.set_status_display(StatusDisplay::StatusLine)
  state.set_mouse_shape(MouseShape::Wait)
  state.full_reset()
  guard state.status_display() == StatusDisplay::Main else {
    fail("expected full reset to restore main status display")
  }
  guard state.mouse_shape() == MouseShape::Wait else {
    fail("expected full reset to preserve mouse shape")
  }
}
