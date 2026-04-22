///|
struct TerminalMetadataState {
  mut title : String?
  mut pwd : String?
  mut shell_redraws_prompt : SemanticPromptRedraw
} derive(Eq, Debug)

///|
pub fn TerminalMetadataState::new() -> TerminalMetadataState {
  {
    title: None,
    pwd: None,
    shell_redraws_prompt: SemanticPromptRedraw::Enabled,
  }
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
fn TerminalMetadataState::pwd(self : TerminalMetadataState) -> String? {
  self.pwd
}

///|
fn TerminalMetadataState::set_pwd(
  self : TerminalMetadataState,
  pwd : String,
) -> Unit {
  if pwd == "" {
    self.pwd = None
  } else {
    self.pwd = Some(pwd)
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
  self.pwd = None
  self.shell_redraws_prompt = SemanticPromptRedraw::Enabled
}
