///|
pub(all) enum SemanticContent {
  Output
  Input
  Prompt
} derive(Eq, Debug)

///|
pub(all) enum RowSemanticPrompt {
  None
  Prompt
  PromptContinuation
} derive(Eq, Debug)

///|
pub(all) enum SemanticClickMode {
  None
  ClickEvents
  Cl(SemanticPromptClick)
} derive(Eq, Debug)

///|
struct ScreenSemanticState {
  mut seen : Bool
  mut click : SemanticClickMode
  mut cursor_content : SemanticContent
  mut cursor_content_clear_eol : Bool
  mut row_prompt : RowSemanticPrompt
} derive(Eq, Debug)

///|
pub fn ScreenSemanticState::new() -> ScreenSemanticState {
  {
    seen: false,
    click: SemanticClickMode::None,
    cursor_content: SemanticContent::Output,
    cursor_content_clear_eol: false,
    row_prompt: RowSemanticPrompt::None,
  }
}

///|
pub fn ScreenSemanticState::seen(self : ScreenSemanticState) -> Bool {
  self.seen
}

///|
pub fn ScreenSemanticState::click(
  self : ScreenSemanticState,
) -> SemanticClickMode {
  self.click
}

///|
pub fn ScreenSemanticState::cursor_content(
  self : ScreenSemanticState,
) -> SemanticContent {
  self.cursor_content
}

///|
pub fn ScreenSemanticState::cursor_content_clear_eol(
  self : ScreenSemanticState,
) -> Bool {
  self.cursor_content_clear_eol
}

///|
pub fn ScreenSemanticState::row_prompt(
  self : ScreenSemanticState,
) -> RowSemanticPrompt {
  self.row_prompt
}

///|
pub fn ScreenSemanticState::apply_fresh_line_new_prompt(
  self : ScreenSemanticState,
  prompt : SemanticPrompt,
) -> Unit {
  self.apply_prompt_start(prompt)
  if prompt.click_events() == Some(true) {
    self.click = SemanticClickMode::ClickEvents
    return
  }
  if prompt.cl() is Some(click) {
    self.click = SemanticClickMode::Cl(click)
  }
}

///|
pub fn ScreenSemanticState::apply_prompt_start(
  self : ScreenSemanticState,
  prompt : SemanticPrompt,
) -> Unit {
  let kind = match prompt.prompt_kind() {
    Some(kind) => kind
    None => SemanticPromptKind::Initial
  }
  self.set_prompt_kind(kind)
}

///|
pub fn ScreenSemanticState::start_input(
  self : ScreenSemanticState,
  clear_eol : Bool,
) -> Unit {
  self.cursor_content = SemanticContent::Input
  self.cursor_content_clear_eol = clear_eol
}

///|
pub fn ScreenSemanticState::set_output(self : ScreenSemanticState) -> Unit {
  self.cursor_content = SemanticContent::Output
  self.cursor_content_clear_eol = false
}

///|
pub fn ScreenSemanticState::clear_row_prompt(
  self : ScreenSemanticState,
) -> Unit {
  self.row_prompt = RowSemanticPrompt::None
}

///|
pub fn ScreenSemanticState::full_reset(self : ScreenSemanticState) -> Unit {
  self.seen = false
  self.click = SemanticClickMode::None
  self.cursor_content = SemanticContent::Output
  self.cursor_content_clear_eol = false
  self.row_prompt = RowSemanticPrompt::None
}

///|
fn ScreenSemanticState::set_prompt_kind(
  self : ScreenSemanticState,
  kind : SemanticPromptKind,
) -> Unit {
  self.seen = true
  self.cursor_content = SemanticContent::Prompt
  self.cursor_content_clear_eol = false
  self.row_prompt = match kind {
    Initial | Right => RowSemanticPrompt::Prompt
    Continuation | Secondary => RowSemanticPrompt::PromptContinuation
  }
}
