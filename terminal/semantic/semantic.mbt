///|
pub(all) enum SemanticClickMode {
  None
  ClickEvents
  Cl(@osc.SemanticPromptClick)
} derive(Eq, Debug)

///|
struct ScreenSemanticState {
  mut seen : Bool
  mut click : SemanticClickMode
  mut cursor_content : @page.SemanticContent
  mut cursor_content_clear_eol : Bool
  mut row_prompt : @page.RowSemanticPrompt
} derive(Eq, Debug)

///|
pub fn ScreenSemanticState::new() -> ScreenSemanticState {
  {
    seen: false,
    click: None,
    cursor_content: Output,
    cursor_content_clear_eol: false,
    row_prompt: None,
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
) -> @page.SemanticContent {
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
) -> @page.RowSemanticPrompt {
  self.row_prompt
}

///|
pub fn ScreenSemanticState::apply_fresh_line_new_prompt(
  self : ScreenSemanticState,
  prompt : @osc.SemanticPrompt,
) -> Unit {
  self.apply_prompt_start(prompt)
  if prompt.click_events() == Some(true) {
    self.click = ClickEvents
    return
  }
  if prompt.cl() is Some(click) {
    self.click = Cl(click)
  }
}

///|
pub fn ScreenSemanticState::apply_prompt_start(
  self : ScreenSemanticState,
  prompt : @osc.SemanticPrompt,
) -> Unit {
  let kind = match prompt.prompt_kind() {
    Some(kind) => kind
    None => Initial
  }
  self.set_prompt_kind(kind)
}

///|
pub fn ScreenSemanticState::start_input(
  self : ScreenSemanticState,
  clear_eol : Bool,
) -> Unit {
  self.cursor_content = Input
  self.cursor_content_clear_eol = clear_eol
}

///|
pub fn ScreenSemanticState::set_output(self : ScreenSemanticState) -> Unit {
  self.cursor_content = Output
  self.cursor_content_clear_eol = false
}

///|
pub fn ScreenSemanticState::clear_row_prompt(
  self : ScreenSemanticState,
) -> Unit {
  self.row_prompt = None
}

///|
pub fn ScreenSemanticState::set_row_prompt(
  self : ScreenSemanticState,
  prompt : @page.RowSemanticPrompt,
) -> Unit {
  self.row_prompt = prompt
}

///|
pub fn ScreenSemanticState::full_reset(self : ScreenSemanticState) -> Unit {
  self.seen = false
  self.click = None
  self.cursor_content = Output
  self.cursor_content_clear_eol = false
  self.row_prompt = None
}

///|
fn ScreenSemanticState::set_prompt_kind(
  self : ScreenSemanticState,
  kind : @osc.SemanticPromptKind,
) -> Unit {
  self.seen = true
  self.cursor_content = Prompt
  self.cursor_content_clear_eol = false
  self.row_prompt = match kind {
    Initial | Right => Prompt
    Continuation | Secondary => PromptContinuation
  }
}
