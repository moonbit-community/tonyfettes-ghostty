///|
test "terminal metadata state/defaults" {
  let state = TerminalMetadataState::new()
  guard state.title() == None &&
    state.shell_redraws_prompt() == SemanticPromptRedraw::Enabled else {
    fail("expected terminal metadata defaults")
  }
}

///|
test "terminal metadata state/set title stores non-empty strings and clears empty title" {
  let state = TerminalMetadataState::new()
  state.set_title("Hello World")
  guard state.title() == Some("Hello World") else {
    fail("expected non-empty title storage")
  }

  state.set_title("")
  guard state.title() == None else {
    fail("expected empty title to clear title state")
  }
}

///|
test "terminal metadata state/prompt redraw and full reset" {
  let state = TerminalMetadataState::new()
  state.set_title("Prompt")
  state.set_shell_redraws_prompt(SemanticPromptRedraw::Last)
  guard state.title() == Some("Prompt") &&
    state.shell_redraws_prompt() == SemanticPromptRedraw::Last else {
    fail("expected metadata mutation before reset")
  }

  state.full_reset()
  guard state.title() == None &&
    state.shell_redraws_prompt() == SemanticPromptRedraw::Enabled else {
    fail("expected metadata full reset defaults")
  }
}
