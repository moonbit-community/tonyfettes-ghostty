///|
struct StreamTerminalBridgeState {
  protected_state : ScreenProtectedState
  display_state : TerminalDisplayState
  colors : TerminalColors
  mut palette_dirty : Bool
} derive(Eq, Debug)

///|
pub fn StreamTerminalBridgeState::new() -> StreamTerminalBridgeState {
  {
    protected_state: ScreenProtectedState::new(),
    display_state: TerminalDisplayState::new(),
    colors: TerminalColors::new(),
    palette_dirty: false,
  }
}

///|
pub fn StreamTerminalBridgeState::protected_state(
  self : StreamTerminalBridgeState,
) -> ScreenProtectedState {
  self.protected_state
}

///|
pub fn StreamTerminalBridgeState::display_state(
  self : StreamTerminalBridgeState,
) -> TerminalDisplayState {
  self.display_state
}

///|
pub fn StreamTerminalBridgeState::colors(
  self : StreamTerminalBridgeState,
) -> TerminalColors {
  self.colors
}

///|
pub fn StreamTerminalBridgeState::palette_dirty(
  self : StreamTerminalBridgeState,
) -> Bool {
  self.palette_dirty
}

///|
pub fn StreamTerminalBridgeState::clear_palette_dirty(
  self : StreamTerminalBridgeState,
) -> Unit {
  self.palette_dirty = false
}

///|
pub fn StreamTerminalBridgeState::apply(
  self : StreamTerminalBridgeState,
  action : StreamAction,
) -> Bool {
  match action {
    StreamProtectedModeOff => {
      self.protected_state.set(ProtectedMode::Off)
      true
    }
    StreamProtectedModeIso => {
      self.protected_state.set(ProtectedMode::Iso)
      true
    }
    StreamProtectedModeDec => {
      self.protected_state.set(ProtectedMode::Dec)
      true
    }
    StreamActiveStatusDisplay(display) => {
      self.display_state.set_status_display(display)
      true
    }
    StreamMouseShape(shape) => {
      self.display_state.set_mouse_shape(shape)
      true
    }
    StreamColorOperation(command) => {
      self.apply_color_operation(command)
      true
    }
    _ => false
  }
}

///|
fn StreamTerminalBridgeState::apply_color_operation(
  self : StreamTerminalBridgeState,
  command : ColorCommand,
) -> Unit {
  let _ = command.op()
  let requests = command.requests()
  if requests.length() == 0 {
    return
  }

  for request in requests {
    match request {
      Set(set) => self.apply_color_set(set)
      Query(_) => ()
      Reset(target) => self.apply_color_reset(target)
      ResetPalette =>
        if self.colors.has_palette_changes() {
          self.colors.reset_palette()
          self.palette_dirty = true
        }
    }
  }
}

///|
fn StreamTerminalBridgeState::apply_color_set(
  self : StreamTerminalBridgeState,
  set : ColoredTarget,
) -> Unit {
  match set.target() {
    Palette(index) => {
      self.colors.set_palette_color(index, set.color())
      self.palette_dirty = true
    }
    Dynamic(dynamic) =>
      match dynamic {
        Foreground => self.colors.set_foreground(set.color())
        Background => self.colors.set_background(set.color())
        Cursor => self.colors.set_cursor(set.color())
        PointerForeground
        | PointerBackground
        | TektronixForeground
        | TektronixBackground
        | HighlightBackground
        | TektronixCursor
        | HighlightForeground => ()
      }
    Special(_) => ()
  }
}

///|
fn StreamTerminalBridgeState::apply_color_reset(
  self : StreamTerminalBridgeState,
  target : ColorTarget,
) -> Unit {
  match target {
    Palette(index) => {
      self.colors.reset_palette_color(index)
      self.palette_dirty = true
    }
    Dynamic(dynamic) =>
      match dynamic {
        Foreground => self.colors.reset_foreground()
        Background => self.colors.reset_background()
        Cursor => self.colors.reset_cursor()
        PointerForeground
        | PointerBackground
        | TektronixForeground
        | TektronixBackground
        | HighlightBackground
        | TektronixCursor
        | HighlightForeground => ()
      }
    Special(_) => ()
  }
}
