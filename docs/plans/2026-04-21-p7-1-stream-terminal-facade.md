# P7.1 Stream Terminal Facade

## Goal

Add the first real host-facing VT API for the translated parser stack: one
opaque owner that accepts `Byte` and `Bytes`, preserves split-sequence parser
state across calls, and exposes only a small read-only observation surface plus
effect callbacks.

## Upstream files

- `upstream/ghostty/src/terminal/stream_terminal.zig`
- `upstream/ghostty/src/terminal/Terminal.zig`
- `upstream/ghostty/src/terminal/c/terminal.zig`

## MoonBit target files

- `src/terminal/stream_terminal.mbt`
- `src/terminal/stream_terminal_test.mbt`
- `src/terminal/stream_terminal_bridge.mbt`
- `src/terminal/stream_terminal_bridge_wbtest.mbt`
- `docs/plan.md`

## Dependency notes

- `P7.0` fixed the intended ownership boundary before implementation:
  `StreamTerminal` should own both the persistent `Stream` parser state and the
  translated terminal bridge state instead of exposing those staging layers
  directly.
- The detailed bridge coverage from Phase 6 remains valuable, but it is
  implementation-detail coverage now, so that suite moved from blackbox to
  whitebox form.
- Upstream host-boundary behavior around missing device-attribute callbacks
  uses the default terminal identity instead of silently ignoring the query; we
  aligned the bridge with that behavior in this slice.

## Acceptance criteria

- A public opaque `StreamTerminal` type exists and owns the persistent stream
  parser plus translated terminal state.
- Public callers can feed single bytes and byte slices without assembling
  `StreamAction` or `StreamTerminalBridgeState` manually.
- Blackbox tests cover split escape handling, effect callbacks, query replies,
  readonly fallbacks, and the small public observation surface.
- Bridge staging types are removed from the public package surface.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze -p tonyfettes/ghostty/src/terminal`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream_terminal.mbt`
  - fully covered by blackbox tests
- `src/terminal/stream_terminal_bridge.mbt`
  - covered except for invariant-only internal branches already tracked in
    Phase 6:
    - line 910: `print_repeat` width-`<= 0` return remains unreachable because
      `previous_char` is only set after a successful positive-width print
    - line 1056: `EndInputStartOutput` row lookup `None` branch remains
      unreachable while cursor/grid invariants hold
    - line 1088: `sync_current_row_prompt` row lookup `None` branch remains
      unreachable while cursor/grid invariants hold
    - line 1106: `apply_semantic_after_newline` row lookup `None` branch
      remains unreachable while cursor/grid invariants hold
    - line 1133: `active_hyperlink` cannot observe `uri != None` with both
      hyperlink ids unset because `ScreenHyperlinkState::start` always assigns
      one
    - line 1603: `cursor_left` previous-row lookup `None` branch remains
      unreachable because `y == 0` returns earlier and `y > 0` keeps the row
      index in bounds
- `src/terminal/stream.mbt`
  - line 222 remains the pre-existing uncovered parser branch already tracked
    before Phase 7

## Commit scope

- `feat(api): add stream terminal facade`

## Review findings

- Public API shape improved materially:
  - removed `StreamTerminalBridgeState` and `StreamTerminalBridgeEffects` from
    `.mbti`
  - added the opaque `StreamTerminal` façade with only the planned host-facing
    methods
- The detailed bridge test suite was intentionally moved to
  `stream_terminal_bridge_wbtest.mbt` so the bridge can stay internal without
  weakening coverage.
- `StreamAction` remains public after this slice. That is deliberate for now:
  it is still the lower-level API of the public `Stream`/`StreamHandler` layer.
  Shrinking that surface would be a broader parser-layer API decision, not a
  host-facade patch.

## Audit/result notes after implementation

- Added `StreamTerminal` as the first public VT façade with:
  - callback-configured constructor
  - `next(Byte)` and `next_slice(Bytes)`
  - `deinit()`
  - title, cursor, palette-dirty, and row/cell snapshot accessors
- Moved the former blackbox bridge suite to whitebox form and added a smaller
  public blackbox suite that exercises the actual host boundary.
- Fixed device-attribute fallback behavior so missing callbacks report the
  default terminal identity, matching upstream host-boundary behavior.
