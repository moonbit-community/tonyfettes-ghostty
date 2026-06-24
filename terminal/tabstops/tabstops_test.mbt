///|
test "terminal tabstops state/default reset interval matches terminal" {
  let state = TerminalTabstopsState::new(30)
  guard !state.get(0) &&
    state.get(8) &&
    state.get(16) &&
    state.get(24) &&
    !state.get(29) else {
    fail("expected default tabstop interval of eight columns")
  }
}

///|
test "terminal tabstops state/set unset and zero reset" {
  let state = TerminalTabstopsState::new(30)
  guard !state.get(5) else { fail("expected unset tabstop before set") }

  state.set(5)
  guard state.get(5) else { fail("expected set to add a tabstop") }

  state.unset(5)
  guard !state.get(5) else {
    fail("expected unset to clear the current tabstop")
  }

  state.reset(0)
  for i in 0..<30 {
    guard !state.get(i.to_uint16()) else {
      fail("expected zero-interval reset to clear all tabstops")
    }
  }
}

///|
test "terminal tabstops state/reset applies custom interval and skips last column" {
  let state = TerminalTabstopsState::new(30)
  state.reset(4)
  guard !state.get(0) &&
    state.get(4) &&
    state.get(8) &&
    state.get(12) &&
    state.get(16) &&
    state.get(20) &&
    state.get(24) &&
    state.get(28) &&
    !state.get(29) else {
    fail("expected custom interval reset to skip the last column")
  }
}

///|
test "terminal tabstops state/count on eighty columns matches upstream" {
  let state = TerminalTabstopsState::new(80)
  let mut count = 0
  for i in 0..<80 {
    if state.get(i.to_uint16()) {
      count += 1
    }
  }
  guard count == 9 else {
    fail("expected nine default tabstops on an eighty column terminal")
  }
}

///|
test "terminal tabstops state/out of range access is ignored safely" {
  let empty = TerminalTabstopsState::new(0)
  guard !empty.get(0) else { fail("expected zero-column state to stay empty") }

  empty.set(0)
  empty.unset(0)
  empty.reset(8)
  guard !empty.get(0) else {
    fail("expected zero-column state operations to remain no-op")
  }

  let state = TerminalTabstopsState::new(1)
  guard !state.get(0) && !state.get(1) else {
    fail("expected no default tabstops for a one-column state")
  }

  state.set(1)
  guard !state.get(1) else { fail("expected out-of-range set to be ignored") }

  state.unset(1)
  guard !state.get(1) else { fail("expected out-of-range unset to be ignored") }
}
