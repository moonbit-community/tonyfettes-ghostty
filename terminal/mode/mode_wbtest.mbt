///|
/// Exercises the save/restore round-trip directly via `saved_value`, the
/// internal save-slot accessor.
test "modes/save captures the current value for later restore" {
  let mut state = ModeState::new()
  state = state.set(CursorKeys, true)
  state = state.save(CursorKeys)
  state = state.set(CursorKeys, false)
  guard !state.get(CursorKeys) else { fail("expected cleared cursor_keys") }
  let restored = state.saved_value(CursorKeys)
  guard restored else { fail("expected saved value to be true") }
  state = state.set(CursorKeys, restored)
  guard state.get(CursorKeys) else { fail("expected restored cursor_keys") }
}

///|
test "modes/saved_value for a never-saved mode is false" {
  let state = ModeState::new()
  guard !state.saved_value(ReverseWrap) else {
    fail("expected unsaved mode to remain false")
  }
}
