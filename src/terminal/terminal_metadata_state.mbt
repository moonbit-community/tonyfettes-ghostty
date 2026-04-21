///|
struct TerminalMetadataState {
  mut title : String?
  mut shell_redraws_prompt : SemanticPromptRedraw
} derive(Eq, Debug)

///|
pub fn TerminalMetadataState::new() -> TerminalMetadataState {
  { title: None, shell_redraws_prompt: SemanticPromptRedraw::Enabled }
}

///|
pub fn TerminalMetadataState::title(self : TerminalMetadataState) -> String? {
  self.title
}

///|
pub fn TerminalMetadataState::set_title(
  self : TerminalMetadataState,
  title : String,
) -> Unit {
  if title == "" {
    self.title = None
  } else {
    self.title = Some(title)
  }
}

///|
pub fn TerminalMetadataState::shell_redraws_prompt(
  self : TerminalMetadataState,
) -> SemanticPromptRedraw {
  self.shell_redraws_prompt
}

///|
pub fn TerminalMetadataState::set_shell_redraws_prompt(
  self : TerminalMetadataState,
  value : SemanticPromptRedraw,
) -> Unit {
  self.shell_redraws_prompt = value
}

///|
pub fn TerminalMetadataState::full_reset(self : TerminalMetadataState) -> Unit {
  self.title = None
  self.shell_redraws_prompt = SemanticPromptRedraw::Enabled
}
