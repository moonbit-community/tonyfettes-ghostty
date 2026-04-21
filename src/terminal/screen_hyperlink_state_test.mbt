///|
test "screen hyperlink state/defaults" {
  let state = ScreenHyperlinkState::new()
  guard !state.active() else {
    fail("expected hyperlink state to start inactive")
  }
  guard state.uri() == None &&
    state.explicit_id() == None &&
    state.implicit_id() == None &&
    state.next_implicit_id() == 0 else {
    fail("expected default hyperlink state")
  }
}

///|
test "screen hyperlink state/explicit hyperlink does not consume implicit ids" {
  let state = ScreenHyperlinkState::new()
  state.start("https://example.com", Some("foo"))

  guard state.active() else {
    fail("expected explicit hyperlink to activate state")
  }
  guard state.uri() == Some("https://example.com") &&
    state.explicit_id() == Some("foo") &&
    state.implicit_id() == None &&
    state.next_implicit_id() == 0 else {
    fail("expected explicit hyperlink state")
  }
}

///|
test "screen hyperlink state/implicit hyperlink increments ids and end clears current state" {
  let state = ScreenHyperlinkState::new()
  state.start("https://one.example.com", None)

  guard state.uri() == Some("https://one.example.com") &&
    state.explicit_id() == None &&
    state.implicit_id() == Some(0) &&
    state.next_implicit_id() == 1 else {
    fail("expected first implicit hyperlink state")
  }

  state.end()
  guard !state.active() &&
    state.uri() == None &&
    state.explicit_id() == None &&
    state.implicit_id() == None &&
    state.next_implicit_id() == 1 else {
    fail("expected end to clear only current hyperlink state")
  }

  state.start("https://two.example.com", None)
  guard state.uri() == Some("https://two.example.com") &&
    state.implicit_id() == Some(1) &&
    state.next_implicit_id() == 2 else {
    fail("expected implicit id increment across hyperlinks")
  }
}

///|
test "screen hyperlink state/full reset clears current state and implicit counter" {
  let state = ScreenHyperlinkState::new()
  state.start("https://one.example.com", None)
  state.start("https://two.example.com", Some("bar"))
  state.full_reset()

  guard !state.active() &&
    state.uri() == None &&
    state.explicit_id() == None &&
    state.implicit_id() == None &&
    state.next_implicit_id() == 0 else {
    fail("expected full reset to restore defaults")
  }
}
