///|
test "mouse/event sends motion" {
  guard !mouse_event_sends_motion(MouseEvent::None) else {
    fail("none should not send motion")
  }
  guard !mouse_event_sends_motion(MouseEvent::Normal) else {
    fail("normal should not send motion")
  }
  guard mouse_event_sends_motion(MouseEvent::Button) else {
    fail("button should send motion")
  }
  guard mouse_event_sends_motion(MouseEvent::Any) else {
    fail("any should send motion")
  }
}

///|
test "mouse/shape lookup covers w3c and xterm aliases" {
  guard MouseShape::from_string("default") == Some(MouseShape::Default) else {
    fail("expected default cursor")
  }
  guard MouseShape::from_string("zoom-in") == Some(MouseShape::ZoomIn) else {
    fail("expected zoom-in cursor")
  }
  guard MouseShape::from_string("left_ptr") == Some(MouseShape::Default) else {
    fail("expected left_ptr alias")
  }
  guard MouseShape::from_string("xterm") == Some(MouseShape::Text) else {
    fail("expected xterm alias")
  }
  guard MouseShape::from_string("fleur") == Some(MouseShape::AllScroll) else {
    fail("expected fleur alias")
  }
  guard MouseShape::from_string("nosuchshape") == None else {
    fail("unexpected unknown shape")
  }
}
