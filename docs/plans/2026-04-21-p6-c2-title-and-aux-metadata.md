# P6.C2 Title And Aux Metadata

## Goal

Translate the small terminal-owned metadata that the later bridge needs
 without pulling in row or cell storage: window title state and the
 semantic-prompt redraw flag.

## Upstream files

- `upstream/ghostty/src/terminal/Terminal.zig`
- `upstream/ghostty/src/terminal/stream_terminal.zig`

## MoonBit target files

- `src/terminal/terminal_metadata_state.mbt`
- `src/terminal/terminal_metadata_state_test.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-21-p6-c-roadmap.md`
- `docs/plans/2026-04-21-p6-c2-title-and-aux-metadata.md`

## Dependency notes

- upstream stores both fields on `Terminal`, not `Screen`, but this slice
  stays under `P6.C` because the current roadmap groups remaining model
  carriers needed before `P6.1.C` and `P6.1.D`
- title push and title pop remain intentionally outside the terminal model for
  now, matching the dependency checklist
- the redraw flag is terminal-owned even though it originates from semantic
  prompt OSC options

## Acceptance criteria

- an opaque metadata carrier exists for terminal title and prompt-redraw state
- empty-title handling matches upstream `setTitle` semantics by clearing the
  stored title instead of keeping an empty string
- the prompt-redraw flag preserves the translated `SemanticPromptRedraw` enum
- blackbox tests cover defaults, title set/clear behavior, prompt-redraw
  mutation, and full reset behavior
- public API review confirms there are no public mutable fields or storage
  leaks

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/terminal_metadata_state.mbt` is fully covered by the added
  blackbox tests
- `moon coverage analyze` still reports the pre-existing uncovered branch in
  `src/terminal/stream.mbt:222`; this slice does not touch that code path

## Commit scope

- `feat(terminal)`

## Review findings

- the public surface is one opaque carrier with method-based access; there are
  no public mutable fields or raw buffers exposed in `.mbti`
- title storage follows upstream terminal behavior by treating an empty title
  as cleared state rather than preserving an empty string payload
- the redraw flag reuses the existing public `SemanticPromptRedraw` enum so
  later semantic-prompt bridge logic can stay faithful without inventing a new
  MoonBit-specific flag type

## Audit / result notes

- added `TerminalMetadataState` with nullable title storage and
  `shell_redraws_prompt` state
- preserved upstream empty-title clearing semantics in `set_title`
- preserved upstream full-reset behavior by clearing the title and restoring
  prompt redraw to `SemanticPromptRedraw::Enabled`
- added blackbox tests for default state, title set/clear behavior, redraw
  mutation, and full reset
- validation completed with `moon fmt`, `moon check`, `moon test`,
  `moon coverage analyze`, and `moon info`
