///|
/// The per-cell semantic content tag (OSC 133 shell-integration), packed into the
/// cell's flag bits. Lives in the `page` package beside the cell/row value types
/// that store it — mirroring upstream Ghostty, where the equivalent lives in
/// `page.zig` alongside `Cell`/`Row`. The screen-level state machine that drives
/// it (`ScreenSemanticState`) stays in the `terminal` package.
pub(all) enum SemanticContent {
  Output
  Input
  Prompt
} derive(Eq, Debug)

///|
/// The per-row semantic-prompt tag, packed into `PageRowState`. As with
/// `SemanticContent`, it lives here next to the row descriptor that carries it
/// (upstream `Row.semantic_prompt` in `page.zig`).
pub(all) enum RowSemanticPrompt {
  None
  Prompt
  PromptContinuation
} derive(Eq, Debug)
