# P2.A UTF-8 Decoder

## Goal

Port `upstream/ghostty/src/terminal/UTF8Decoder.zig` into MoonBit with the same
Hoehrmann DFA tables and the same replacement-and-retry behavior.

## Upstream files

- `upstream/ghostty/src/terminal/UTF8Decoder.zig`

## MoonBit target files

- `src/terminal/utf8_decoder.mbt`
- `src/terminal/utf8_decoder_wbtest.mbt`

## Dependency notes

- Depends on `P2.0` contract notes in
  `docs/plans/2026-04-19-p2-parser-prereqs.md`.
- This slice is intentionally self-contained and must not pull in `Parser`,
  `parse_table`, or OSC modules.
- The upstream `next` contract returns both an optional codepoint and a
  `consumed` flag. That retry contract is the main fidelity constraint.

## Acceptance criteria

- Preserve the upstream DFA tables exactly.
- Preserve the `Utf8Decoder::next` result contract:
  - complete sequence emits a codepoint and consumes the byte
  - invalid leading byte emits U+FFFD and consumes the byte
  - invalid continuation byte emits U+FFFD and does not consume the byte
- Cover ASCII, valid multibyte input, partially invalid input, and explicit
  retry of the same byte after an invalid continuation.

## Validation commands

- `moon check`
- `moon test`
- `moon fmt`
- `moon info`

## Commit scope

- `feat(parser-core): add utf8 decoder`

## Review findings

- Main-agent review confirmed the MoonBit decoder keeps the upstream DFA
  tables and reject/reset behavior.
- Reviewer subagent found no concrete decoder logic mismatches, but identified
  two missing contract-level tests:
  - valid multibyte input must always consume on the first call
  - an invalid leading byte must emit U+FFFD and consume the byte
- Added both tests before closing the lane.

## Audit/result notes

- Added `Utf8Decoder::new` and `Utf8Decoder::next` in
  `src/terminal/utf8_decoder.mbt`.
- Added translated whitebox tests in `src/terminal/utf8_decoder_wbtest.mbt`.
- Ran `moon info`, `moon fmt`, `moon check`, and `moon test` successfully at
  the end of the slice.
