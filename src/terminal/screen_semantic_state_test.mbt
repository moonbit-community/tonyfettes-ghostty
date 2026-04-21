///|
struct ScreenSemanticPromptRecorder {
  actions : Array[StreamAction]
}

///|
impl StreamHandler for ScreenSemanticPromptRecorder with vt(self, action) {
  self.actions.push(action)
}

///|
impl StreamHandler for ScreenSemanticPromptRecorder with deinit(_self) {
  ()
}

///|
fn expect_screen_semantic_prompt(bytes : Bytes) -> SemanticPrompt raise {
  let actions : Array[StreamAction] = []
  let stream = Stream::new({ actions, })
  stream.next_slice(bytes)
  stream.deinit()

  guard actions.length() == 1 else {
    fail("expected exactly one semantic prompt action")
  }
  guard actions.get(0) is Some(StreamSemanticPrompt(prompt)) else {
    fail("expected semantic prompt action")
  }
  prompt
}

///|
test "screen semantic state/defaults" {
  let state = ScreenSemanticState::new()
  guard !state.seen() else { fail("expected semantic state to start unseen") }
  guard state.click() == SemanticClickMode::None &&
    state.cursor_content() == SemanticContent::Output &&
    !state.cursor_content_clear_eol() &&
    state.row_prompt() == RowSemanticPrompt::None else {
    fail("expected default semantic state")
  }
}

///|
test "screen semantic state/fresh line new prompt applies prompt and click_events priority" {
  let prompt = expect_screen_semantic_prompt(
    b"\x1B]133;A;click_events=1;cl=line\x07",
  )
  let state = ScreenSemanticState::new()
  state.apply_fresh_line_new_prompt(prompt)

  guard state.seen() &&
    state.click() == SemanticClickMode::ClickEvents &&
    state.cursor_content() == SemanticContent::Prompt &&
    state.row_prompt() == RowSemanticPrompt::Prompt else {
    fail("expected fresh-line-new-prompt semantic state")
  }
}

///|
test "screen semantic state/prompt start maps continuation kinds" {
  let prompt = expect_screen_semantic_prompt(b"\x1B]133;P;k=c\x07")
  let state = ScreenSemanticState::new()
  state.apply_prompt_start(prompt)

  guard state.seen() &&
    state.click() == SemanticClickMode::None &&
    state.cursor_content() == SemanticContent::Prompt &&
    state.row_prompt() == RowSemanticPrompt::PromptContinuation else {
    fail("expected prompt start continuation semantic state")
  }
}

///|
test "screen semantic state/cl fallback and disabled click_events preserve existing mode" {
  let click_prompt = expect_screen_semantic_prompt(b"\x1B]133;A;cl=w\x07")
  let disabled_prompt = expect_screen_semantic_prompt(
    b"\x1B]133;A;click_events=0\x07",
  )
  let state = ScreenSemanticState::new()
  state.apply_fresh_line_new_prompt(click_prompt)
  guard state.click() == SemanticClickMode::Cl(SmartVertical) else {
    fail("expected cl fallback click mode")
  }

  state.apply_fresh_line_new_prompt(disabled_prompt)
  guard state.click() == SemanticClickMode::Cl(SmartVertical) else {
    fail("expected disabled click_events without cl to preserve click mode")
  }
}

///|
test "screen semantic state/input output row clear and full reset" {
  let state = ScreenSemanticState::new()
  let prompt = expect_screen_semantic_prompt(b"\x1B]133;P;k=i\x07")
  state.apply_prompt_start(prompt)
  state.start_input(true)
  guard state.cursor_content() == SemanticContent::Input &&
    state.cursor_content_clear_eol() &&
    state.row_prompt() == RowSemanticPrompt::Prompt else {
    fail("expected input semantic state")
  }

  state.set_output()
  guard state.cursor_content() == SemanticContent::Output &&
    !state.cursor_content_clear_eol() &&
    state.row_prompt() == RowSemanticPrompt::Prompt else {
    fail("expected output semantic state without row change")
  }

  state.clear_row_prompt()
  guard state.row_prompt() == RowSemanticPrompt::None else {
    fail("expected row prompt clear")
  }

  state.full_reset()
  guard !state.seen() &&
    state.click() == SemanticClickMode::None &&
    state.cursor_content() == SemanticContent::Output &&
    !state.cursor_content_clear_eol() &&
    state.row_prompt() == RowSemanticPrompt::None else {
    fail("expected semantic state full reset")
  }
}
