///|
pub(all) enum MouseAction {
  Press
  Release
  Motion
} derive(Eq, Debug)

///|
pub(all) enum MouseButton {
  Unknown
  Left
  Right
  Middle
  Four
  Five
  Six
  Seven
  Eight
  Nine
  Ten
  Eleven
} derive(Eq, Debug)

///|
struct MousePosition {
  x : Float
  y : Float
} derive(Eq, Debug)

///|
struct MouseInputEvent {
  mut action : MouseAction
  mut button : MouseButton?
  mut mods : KeyMods
  mut position : MousePosition
} derive(Eq, Debug)

///|
pub fn MousePosition::new(x : Float, y : Float) -> MousePosition {
  { x, y }
}

///|
pub fn MousePosition::x(self : MousePosition) -> Float {
  self.x
}

///|
pub fn MousePosition::y(self : MousePosition) -> Float {
  self.y
}

///|
pub fn MouseInputEvent::new() -> MouseInputEvent {
  {
    action: MouseAction::Press,
    button: None,
    mods: KeyMods::new(),
    position: MousePosition::new(0.0F, 0.0F),
  }
}

///|
pub fn MouseInputEvent::action(self : MouseInputEvent) -> MouseAction {
  self.action
}

///|
pub fn MouseInputEvent::set_action(
  self : MouseInputEvent,
  value : MouseAction,
) -> Unit {
  self.action = value
}

///|
pub fn MouseInputEvent::button(self : MouseInputEvent) -> MouseButton? {
  self.button
}

///|
pub fn MouseInputEvent::set_button(
  self : MouseInputEvent,
  value : MouseButton,
) -> Unit {
  self.button = Some(value)
}

///|
pub fn MouseInputEvent::clear_button(self : MouseInputEvent) -> Unit {
  self.button = None
}

///|
pub fn MouseInputEvent::mods(self : MouseInputEvent) -> KeyMods {
  self.mods
}

///|
pub fn MouseInputEvent::set_mods(
  self : MouseInputEvent,
  value : KeyMods,
) -> Unit {
  self.mods = value
}

///|
pub fn MouseInputEvent::position(self : MouseInputEvent) -> MousePosition {
  self.position
}

///|
pub fn MouseInputEvent::set_position(
  self : MouseInputEvent,
  value : MousePosition,
) -> Unit {
  self.position = value
}
