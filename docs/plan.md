# Ghostty Parser Translation Plan

## Goal

Translate the upstream Ghostty terminal parser stack from Zig to MoonBit as
faithfully as possible, preserving the upstream architecture described in
`docs/architecture.md`.

The target scope is the parser slice under `upstream/ghostty`, centered on:

- `src/terminal/Parser.zig`
- `src/terminal/parse_table.zig`
- `src/terminal/UTF8Decoder.zig`
- `src/terminal/stream.zig`
- `src/terminal/osc.zig`
- `src/terminal/dcs.zig`
- `src/terminal/sgr.zig`
- `src/terminal/stream_terminal.zig`
- directly required terminal model files that those modules depend on

Non-goals for now:

- renderer translation
- GTK/macOS frontend translation
- subprocess or PTY backend translation beyond the parser-facing bridge
- packaging or distribution parity with upstream Ghostty

## Working rules

1. Complete tasks in order.
2. Keep one atomic Conventional Commit per completed task.
3. Update this file when a task starts or finishes.
4. Prefer direct translation of upstream types, enums, unions, and control flow.
5. Add tests as each parser layer lands; do not defer all validation to the
   end.

## Task list

- [x] 1. Add repository workflow instructions for conventional commits and
  atomic step-by-step history.
- [x] 2. Add `upstream/ghostty` as the source-of-truth git submodule.
- [x] 3. Write `docs/architecture.md` describing the upstream parser pipeline,
  module boundaries, and runtime data flow.
- [ ] 4. Create the MoonBit package layout for the parser translation and write
  an upstream-to-MoonBit file mapping table.
- [ ] 5. Port foundational value modules used by the parser surface:
  `ansi`, `charsets`, `modes`, `point`, `color`, `mouse`,
  `device_attributes`, `device_status`, and `size_report`.
- [ ] 6. Port `UTF8Decoder.zig` line-by-line, including retry-on-error
  semantics, and bring over its tests.
- [ ] 7. Port `parse_table.zig` as a table-driven parser transition module.
  Preserve the generated-table structure and the SGR colon extension.
- [ ] 8. Port `Parser.zig` state, action types, parameter accumulation, OSC
  embedding, and ordered three-action `next` contract.
- [ ] 9. Port `Parser.zig` tests, especially mixed colon/semicolon SGR cases,
  OSC termination, DCS hooks, and parameter overflow behavior.
- [ ] 10. Port `sgr.zig` attribute types and iterator parser, including colon
  and semicolon forms, unknown tails, underline variants, and direct/256-color
  support.
- [ ] 11. Port the OSC core in `osc.zig`: command union, terminator handling,
  prefix-state machine, fixed capture buffer, optional allocating capture, and
  parser reset/deinit behavior.
- [ ] 12. Port high-frequency OSC subparsers first:
  change window title, change icon, hyperlink, report pwd, color operations,
  semantic prompt, and mouse shape.
- [ ] 13. Port the remaining OSC subparsers needed for fidelity, including
  clipboard operations, kitty color, kitty clipboard, iTerm2, rxvt extension,
  context signal, and text sizing.
- [ ] 14. Port `dcs.zig` with incremental `hook` / `put` / `unhook` handling
  for XTGETTCAP, DECRQSS, and tmux control mode.
- [ ] 15. Port APC handling and any parser-facing kitty/APC support modules
  required by `stream_terminal.zig`.
- [ ] 16. Port the `Stream.Action` union and the generic stream driver in
  `stream.zig`, including:
  - UTF-8 ground-state fast path
  - parser replay in emitted-action order
  - `execute`
  - `escDispatch`
  - `csiDispatch`
  - `oscDispatch`
  - DCS/APC passthrough
- [ ] 17. Port the `stream.zig` tests in batches so dispatch behavior is
  checked while the module is being translated.
- [ ] 18. Port the minimum terminal model needed to consume parser actions
  faithfully: style, tabstops, screen/page structures, cursor state, hyperlink
  state, mode state, and terminal mutation entry points.
- [ ] 19. Port `stream_terminal.zig` so parser actions can be applied to a
  MoonBit terminal model with effect callbacks separated from pure state
  mutation.
- [ ] 20. Add a parser-facing host bridge that accepts byte slices and exposes
  a stable MoonBit API similar to Ghostty's VT library boundary.
- [ ] 21. Build differential validation against upstream behavior:
  parser fixtures, translated unit tests, snapshot tests, and focused
  end-to-end byte-stream comparisons.
- [ ] 22. Add targeted performance checks for the parser hot path and document
  any places where MoonBit requires a structurally different implementation.

## Definition of done

The parser translation is ready for review when:

- the upstream parser modules above have MoonBit counterparts
- translated tests cover parser, SGR, OSC, DCS, UTF-8, and stream behavior
- the MoonBit API can accept PTY byte slices and produce the same parser and
  terminal effects as upstream for the covered cases
- the repository history remains task-by-task and atomic
