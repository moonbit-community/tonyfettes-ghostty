///|
/// An incomplete internal state — a URI was recorded but no cell hyperlink was
/// ever resolved — is not reachable through `start`/`end`, but the readers must
/// still report "no active hyperlink" defensively. Poking the private fields is
/// legitimate here because the test lives in the type's own package.
test "screen hyperlink state/incomplete state reports no active cell" {
  let state = ScreenHyperlinkState::new()
  state.uri = Some("https://example.com")
  state.explicit_id = None
  state.implicit_id = None
  guard state.cell_hyperlink() is None else {
    fail("expected incomplete hyperlink state to have no active cell")
  }
}
