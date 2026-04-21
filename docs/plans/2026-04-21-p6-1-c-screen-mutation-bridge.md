# P6.1.C Screen Mutation Bridge

## Goal

Complete the `stream_terminal.zig` bridge slice that mutates translated
terminal screen state directly: printable text, line-motion mutations,
erase/insert/delete/scroll actions, hyperlink and semantic prompt state,
kitty-color mutations, DECALN, and full reset.

## Upstream files

- `upstream/ghostty/src/terminal/stream_terminal.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`
- `upstream/ghostty/src/terminal/Screen.zig`

## MoonBit target files

- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/stream_terminal_bridge_test.mbt`
- `src/terminal/screen_semantic_state_test.mbt`
- `src/terminal/stream_wbtest.mbt`
- `docs/plans/2026-04-20-p6-1-bridge-roadmap.md`
- `docs/plan.md`

## Dependency notes

- `P6.C` had to land first so the bridge could target real page, hyperlink,
  semantic, and grid state rather than temporary placeholders.
- Reverse-wrap behavior that depends on row wrap markers moved here from
  `P6.1.B` because it is screen-state dependent.
- Query and host-side effect responses remain deferred to `P6.1.D`.

## Acceptance criteria

- `StreamTerminalBridgeState::apply` handles the screen-mutation action set
  from `stream_terminal.zig`.
- Printable writes update cursor, row/cell snapshots, hyperlink metadata,
  semantic metadata, and style state through the translated screen model.
- Erase/insert/delete/scroll actions dispatch into the translated grid model.
- DECALN and full reset follow upstream model ownership boundaries.
- Blackbox bridge tests exercise the new public observation surface and the
  stream-to-bridge path for payload-bearing OSC actions.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream_terminal_bridge.mbt`
  - covered except for invariant-only internal branches:
    - line 803: `print_repeat` width-`<= 0` return is unreachable through the
      public bridge because `previous_char` is only updated after a successful
      positive-width print
    - line 949: `EndInputStartOutput` row lookup `None` branch is unreachable
      while cursor invariants hold
    - line 981: `sync_current_row_prompt` row lookup `None` branch is
      unreachable while cursor invariants hold
    - line 999: `apply_semantic_after_newline` row lookup `None` branch is
      unreachable while cursor invariants hold
    - line 1026: `active_hyperlink` cannot observe `uri != None` with both
      hyperlink ids unset because `ScreenHyperlinkState::start` always assigns
      one
    - line 1327: `cursor_left` previous-row lookup `None` branch is
      unreachable because `y == 0` returns earlier and `y > 0` keeps the row
      index in bounds
- `src/terminal/stream.mbt`
  - line 222 remains the pre-existing uncovered parser branch already tracked
    before this slice

## Commit scope

- `feat(terminal): bridge screen mutation actions`

## Review findings

- No correctness issues found after the blackbox coverage expansion.
- The added recorder type in blackbox bridge tests created an inference
  ambiguity for other test-local `StreamHandler` record literals, so those test
  helpers were updated to use explicit recorder annotations instead of relying
  on structural inference.

## Audit/result notes after implementation

- Added bridge-owned observation helpers for current style, semantic state,
  hyperlink state, title metadata, and screen row/cell snapshots so blackbox
  tests can validate the model without reopening internal state.
- Wired printable actions, linefeed/index/reverse-index, erase/insert/delete,
  scroll, hyperlink start/end, OSC 133 semantic prompt actions, kitty color
  mutation actions, DECALN, and full reset.
- Added blackbox bridge coverage for:
  - printable text, repeat print, wide characters, and status-display guards
  - semantic prompt variants and hyperlink flows
  - reverse index, linefeed mode, and reverse-wrap cursor-left modes
  - erase/insert/delete/scroll wiring
  - kitty color set/query/reset branches
  - DECALN and full reset
