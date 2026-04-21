# P6.1.D Query And Side-Effect Bridge

## Goal

Complete the remaining `stream_terminal.zig` bridge actions that do not mutate
screen storage directly: PTY replies, host-side callbacks, title changes, and
pass-through effect actions that are intentionally no-op for terminal state.

## Upstream files

- `upstream/ghostty/src/terminal/stream_terminal.zig`

## MoonBit target files

- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/stream_terminal_bridge_test.mbt`
- `docs/plans/2026-04-20-p6-1-bridge-roadmap.md`
- `docs/plan.md`

## Dependency notes

- `P6.1.A`, `P6.1.B`, and `P6.1.C` had to land first so the bridge already
  owned the translated terminal state and action dispatch skeleton.
- Upstream keeps these paths callback-oriented instead of storing their effects
  inside terminal state; the MoonBit bridge mirrors that split with an explicit
  `StreamTerminalBridgeEffects` record.
- Clipboard, notification, APC, and DCS pass-through actions are terminal-state
  no-ops in this phase. Their host behavior remains outside the scoped parser
  translation.

## Acceptance criteria

- `StreamTerminalBridgeState::apply` handles the remaining query and side-effect
  action set from `stream_terminal.zig`.
- PTY replies for device attributes, device status, mode reports, ENQ,
  XTWINOPS, XTVERSION, and kitty-keyboard queries encode through the bridge
  using `Bytes`.
- Window-title actions update translated metadata and fire the host-side title
  callback.
- Passive effect actions are handled deliberately so the bridge no longer
  reports them as unsupported.
- Blackbox tests cover the new effect surface without widening the model-facing
  public API beyond the callback carrier needed by external hosts.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze -p tonyfettes/ghostty/src/terminal`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream_terminal_bridge.mbt`
  - covered except for invariant-only internal branches:
    - line 910: `print_repeat` width-`<= 0` return is unreachable through the
      public bridge because `previous_char` is only updated after a successful
      positive-width print
    - line 1056: `EndInputStartOutput` row lookup `None` branch is unreachable
      while cursor/grid invariants hold
    - line 1088: `sync_current_row_prompt` row lookup `None` branch is
      unreachable while cursor/grid invariants hold
    - line 1106: `apply_semantic_after_newline` row lookup `None` branch is
      unreachable while cursor/grid invariants hold
    - line 1133: `active_hyperlink` cannot observe `uri != None` with both
      hyperlink ids unset because `ScreenHyperlinkState::start` always assigns
      one
    - line 1603: `cursor_left` previous-row lookup `None` branch is
      unreachable because `y == 0` returns earlier and `y > 0` keeps the row
      index in bounds
- `src/terminal/stream.mbt`
  - line 222 remains the pre-existing uncovered parser branch already tracked
    before this slice

## Commit scope

- `feat(terminal): bridge query and side-effect actions`

## Review findings

- No correctness issues found in the remaining query/effect dispatch after the
  blackbox test expansion.
- The new public `StreamTerminalBridgeEffects` type and
  `StreamTerminalBridgeState::with_effects` constructor are justified public
  surface: external hosts need a stable way to supply PTY write callbacks,
  bell delivery, optional device metadata, and title-change hooks.
- No additional internal parser or terminal state was exposed to support this
  slice.

## Audit/result notes after implementation

- Added an effect carrier so bridge-owned side effects stay callback-based
  instead of leaking into terminal model state.
- Wired bell, device-attribute replies, device-status replies, mode reports,
  ENQ, XTWINOPS size replies, XTVERSION, window-title mutation, and kitty
  keyboard query handling.
- Added blackbox coverage for:
  - bell delivery and title-changed callbacks
  - operating-status, cursor-position, mode, device-attribute, size, ENQ,
    XTVERSION, kitty-keyboard, and color-scheme replies
  - truncation/default/fallback branches for title, ENQ, XTVERSION, and size
    queries
  - passive clipboard/notification/title-stack/APC/DCS actions remaining
    handled as terminal-state no-ops
