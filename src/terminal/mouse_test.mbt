///|
test "mouse/event sends motion" {
  guard !mouse_event_sends_motion(None) else {
    fail("none should not send motion")
  }
  guard !mouse_event_sends_motion(Normal) else {
    fail("normal should not send motion")
  }
  guard mouse_event_sends_motion(Button) else {
    fail("button should send motion")
  }
  guard mouse_event_sends_motion(Any) else { fail("any should send motion") }
}

///|
test "mouse/shape lookup covers w3c and xterm aliases" {
  guard MouseShape::from_string("default") == Some(Default) else {
    fail("expected default cursor")
  }
  guard MouseShape::from_string("zoom-in") == Some(ZoomIn) else {
    fail("expected zoom-in cursor")
  }
  guard MouseShape::from_string("left_ptr") == Some(Default) else {
    fail("expected left_ptr alias")
  }
  guard MouseShape::from_string("xterm") == Some(Text) else {
    fail("expected xterm alias")
  }
  guard MouseShape::from_string("fleur") == Some(AllScroll) else {
    fail("expected fleur alias")
  }
  guard MouseShape::from_string("nosuchshape") == None else {
    fail("unexpected unknown shape")
  }
}
