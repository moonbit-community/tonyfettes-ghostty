///|
test "mouse input event/defaults and setters roundtrip" {
  let event = MouseInputEvent::new()
  guard event.action() == MouseAction::Press else {
    fail("mouse events should default to press")
  }
  guard event.button() == None else {
    fail("mouse events should start without a button")
  }
  guard event.mods() == KeyMods::new() else {
    fail("mouse events should start with empty modifiers")
  }
  guard event.position() == MousePosition::new(0.0F, 0.0F) else {
    fail("mouse events should start at the origin")
  }

  let mods = KeyMods::new().with_shift(true).with_ctrl(true)
  let position = MousePosition::new(12.5F, -4.0F)
  event.set_action(MouseAction::Motion)
  event.set_button(MouseButton::Left)
  event.set_mods(mods)
  event.set_position(position)

  guard event.action() == MouseAction::Motion else {
    fail("expected motion action")
  }
  guard event.button() == Some(MouseButton::Left) else {
    fail("expected stored left button")
  }
  guard event.mods() == mods else { fail("expected stored modifiers") }
  guard event.position() == position else { fail("expected stored position") }

  event.clear_button()
  guard event.button() == None else {
    fail("clearing the button should reset the optional button")
  }
}

///|
test "mouse position/exposes float coordinates" {
  let position = MousePosition::new(3.25F, 9.5F)
  assert_eq(position.x(), 3.25F)
  assert_eq(position.y(), 9.5F)
}
