# P4.C High-Frequency OSC Closeout Audit

## Goal

Close the `P4.C` lane by proving the translated high-frequency OSC surface is
fully represented in MoonBit and by documenting every remaining upstream OSC
parser as an intentional `P4.D` defer rather than an untracked gap.

## Upstream reference points

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/color.zig`
- `upstream/ghostty/src/terminal/osc/parsers/report_pwd.zig`
- `upstream/ghostty/src/terminal/osc/parsers/hyperlink.zig`
- `upstream/ghostty/src/terminal/osc/parsers/semantic_prompt.zig`

## MoonBit reference points

- `src/terminal/osc.mbt`
- `src/terminal/osc_wbtest.mbt`
- `src/terminal/parser_wbtest.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/osc_semantic_prompt.mbt`
- `docs/plans/2026-04-19-p4-c-hyperlink.md`
- `docs/plans/2026-04-20-p4-c-semantic-prompt.md`

## Scope boundary

Per the decoder contracts doc, `P4.C` owns the high-frequency OSC lane only:

- window title (`OSC 0`, `OSC 2`)
- window icon (`OSC 1`)
- color operations (`OSC 4`, `OSC 5`, `OSC 10-19`, `OSC 104`, `OSC 105`,
  `OSC 110-119`)
- report pwd (`OSC 7`)
- hyperlink start/end (`OSC 8`)
- mouse shape (`OSC 22`)
- semantic prompt (`OSC 133`)

Everything else upstream routes through the OSC parser but belongs to `P4.D`.

## Translation matrix

Implemented high-frequency surface:

- `change_window_title` -> `Command::ChangeWindowTitle(String)`
- `change_window_icon` -> `Command::ChangeWindowIcon(String)`
- `color_operation` -> `Command::ColorOperation(ColorCommand)`
- `report_pwd` -> `Command::ReportPwd(String)`
- `hyperlink_start` / `hyperlink_end` ->
  `Command::HyperlinkStart(HyperlinkStart)` / `Command::HyperlinkEnd`
- `mouse_shape` -> `Command::MouseShape(String)`
- `semantic_prompt` -> `Command::SemanticPrompt(SemanticPrompt)`

Evidence:

- direct parser coverage in `src/terminal/osc_wbtest.mbt`
- parser integration coverage in `src/terminal/parser_wbtest.mbt`
- stream-level regression coverage for the currently wired OSC actions in
  `src/terminal/stream_test.mbt`

## Intentional defers to P4.D

These upstream OSC parser families are not part of the `P4.C` closeout and are
tracked as `P4.D` work:

- `OSC 9` family (`osc9.zig`): desktop notifications, ConEmu variants, plus the
  compatibility forms that can emit pwd / semantic-prompt-like payloads
- `OSC 21`: kitty color protocol
- `OSC 52`: clipboard operations
- `OSC 66`: kitty text sizing
- `OSC 3008`: context signalling
- `OSC 777`: rxvt extension parsing
- `OSC 1337`: iTerm2 extension parsing
- `OSC 5522`: kitty clipboard protocol
- any parser files under `upstream/ghostty/src/terminal/osc/parsers/` not
  required by the high-frequency contract list above

These are intentional plan-level defers, not missing work inside `P4.C`.

## Validation evidence

`P4.C` closes on the back of the latest high-frequency implementation slice
validation:

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`
- `moon fmt`

Latest result at closeout time:

- parser/tests pass with `199` passing tests
- no uncovered lines remain in the touched high-frequency OSC parser files
- only two pre-existing uncovered lines remain in `src/terminal/stream.mbt`,
  outside the `P4.C` parser write set

## Review findings

- No untracked high-frequency OSC parser outputs remain in the current MoonBit
  `osc.Command` surface.
- The public API delta introduced by `P4.C` is intentional:
  `HyperlinkStart`, `SemanticPrompt`, and the semantic-prompt enums/errors all
  support typed parser output.
- `SemanticPrompt` stream dispatch is still intentionally silent. That is not a
  `P4.C` blocker because dispatch behavior belongs to the Phase 5 stream lane,
  specifically `P5.B3`.

## Result

`P4.C` is complete.

The next OSC implementation lane is `P4.D`, while the immediate downstream
stream-integration follow-up for the new parser output is `P5.B3`.
