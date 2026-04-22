# P13.B Formatter Surface

## Goal

Translate `src/terminal/c/formatter.zig` into a typed MoonBit formatter owner
that formats terminal content directly to owned `Bytes`.

## Upstream files

- `upstream/ghostty/src/terminal/c/formatter.zig`
- `upstream/ghostty/src/terminal/Terminal.zig` formatting-facing screen/query
  behavior

## MoonBit targets

- `src/terminal/formatter.mbt`
- `src/terminal/formatter_test.mbt`
- `src/terminal/formatter_wbtest.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-22-p13-b-formatter-surface.md`

## Public surface

- `Format`
- `FormatterScreenExtra`
- `FormatterTerminalExtra`
- `FormatterOptions`
- `Formatter`

The public owner API stays typed and MoonBit-owned:

- `FormatterScreenExtra::{new, none, styles, all}`
- `FormatterTerminalExtra::{new, none, styles, all}`
- `FormatterOptions::new`
- `Formatter::new_terminal`
- `Formatter::format() -> Bytes`

The upstream C wrapper's allocator/output-buffer ownership helpers are absorbed
into direct `Bytes` return values.

## Fidelity notes

- Formatting reads from the translated `StreamTerminal` host/query surface
  rather than introducing a separate C-style terminal pointer wrapper.
- Selection handling remains `GridRef`-based, matching the translated host
  model instead of the upstream wrapper's nullable pointer discipline.
- VT output preserves palette, mode, margin, tabstop, pwd, keyboard, style,
  hyperlink, protection, charset, and cursor extras that already exist in the
  translated terminal state.
- HTML output stays deliberately simple and inline:
  escaped text, hyperlink tags, inline style spans, and palette CSS variables.
- The formatter returns owned `Bytes` for all formats, including HTML and VT,
  instead of exposing allocation/free callbacks.

## Validation

Ran:

- `moon check`
- `moon test src/terminal/formatter_test.mbt`
- `moon test src/terminal/formatter_wbtest.mbt`
- `moon test`
- `moon coverage analyze -p tonyfettes/ghostty/src/terminal`
- `moon fmt`
- `moon info`

## Coverage review

Touched-file coverage is complete for the reachable formatter behavior. The
remaining uncovered formatter lines are invariant-only fallbacks:

- `src/terminal/formatter.mbt:346`
- `src/terminal/formatter.mbt:421`
- `src/terminal/formatter.mbt:737`
- `src/terminal/formatter.mbt:748`

Why they remain:

- `formatter.mbt:346` is the `state.scrollback.cell(...) == None` arm inside
  `formatter_write_content`. For a row that already resolved through
  `state.scrollback.row(...)`, the same `(row, col)` lookup cannot become
  missing without breaking internal grid/scrollback invariants.
- `formatter.mbt:421` clamps `start_x < 0`, but `Coordinate.x` is `UInt16` in
  the translated host model, so the branch is structurally unreachable.
- `formatter.mbt:737` is the `Slots::G0` match arm under
  `if state.charset.gl() != Slots::G0`, so the guard excludes the arm.
- `formatter.mbt:748` is the `Slots::G2` match arm under
  `if state.charset.gr() != Slots::G2`, so the guard excludes the arm.

Remaining uncovered lines outside this task stay tracked in earlier audits.

## API review

Intentional new public surface:

- `Format`
- `FormatterScreenExtra`
- `FormatterTerminalExtra`
- `FormatterOptions`
- `Formatter`

Kept out of the public API on purpose:

- C-style allocator/free helpers
- enum-keyed `get/get_multi` formatter dispatch
- direct exposure of terminal bridge internals
- mutable formatter state fields

## Notes

- Whitebox coverage exists only to keep formatter internals private while still
  exercising helper branches that cannot be reached cleanly from the public
  host surface.
