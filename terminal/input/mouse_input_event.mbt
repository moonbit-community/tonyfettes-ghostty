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
pub(all) struct MousePosition {
  x : Float
  y : Float
} derive(Eq, Debug)

///|
/// Abstract (no `pub`): a host mouse event built with `new` + the `set_*`
/// mutators and read through the getters, so callers can't assemble arbitrary
/// action/button/modifier/position combinations as part of the ABI.
struct MouseInputEvent {
  mut action : MouseAction
  mut button : MouseButton?
  mut mods : KeyMods
  mut position : MousePosition
} derive(Eq, Debug)

///|
pub fn MousePosition::new(x : Float, y : Float) -> MousePosition {
  { x, y, }
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
    action: Press,
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

///|
pub extend MouseAction with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend MouseAction with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend MouseAction with @debug.Debug::{to_repr}

///|
pub extend MouseButton with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend MouseButton with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend MouseButton with @debug.Debug::{to_repr}

///|
pub extend MousePosition with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend MousePosition with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend MousePosition with @debug.Debug::{to_repr}

///|
pub extend MouseInputEvent with Eq::{equal}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend MouseInputEvent with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend MouseInputEvent with @debug.Debug::{to_repr}
