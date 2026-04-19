# P4.C1 Hyperlink Parser

## Goal

Land the first bounded `P4.C` slice by translating upstream `OSC 8` hyperlink
parsing into typed MoonBit `osc.Command` output.

## Upstream files

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/hyperlink.zig`

## MoonBit target files

- `src/terminal/osc.mbt`
- `src/terminal/osc_wbtest.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p4-c-roadmap.md`
- `docs/plans/2026-04-19-p4-c-hyperlink.md`

## Dependency notes

- This slice is intentionally limited to `OSC 8`.
- `OSC 133` semantic prompt parsing remains separate because its option model
  is substantially larger.

## Acceptance criteria

- `OSC 8` is recognized by the prefix-state machine
- typed hyperlink-start output includes URI and optional `id`
- `OSC 8;;` yields hyperlink-end output
- unknown or malformed key/value options are ignored like upstream
- empty URI with a non-empty `id` is rejected
- tests cover the accepted and rejected upstream cases

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` returns the same two pre-existing structural
  residuals in `src/terminal/stream.mbt`:
  - the inner `consume_until_ground` path in `next_slice_capped`
  - the `Some(Print(codepoint))` path in `next_non_utf8`
- no new residual line remains in the touched hyperlink parser logic in
  `src/terminal/osc.mbt`
- temporary no-op handling for hyperlink commands in `stream` is covered by a
  blackbox stream test so the parser slice does not introduce fresh stream
  residuals

## Commit scope

- `feat(parser-protocols)`

## Review findings

- public API review:
  - `HyperlinkStart` is intentionally opaque, with `uri()` and `id()`
    accessors, because external consumers only need to inspect parsed payloads
    and do not need field-level construction
  - `Command::HyperlinkStart` and `Command::HyperlinkEnd` are intentional
    additions to the typed OSC command surface
- behavioral review:
  - malformed or unknown hyperlink options are ignored
  - empty URI with no `id` becomes `HyperlinkEnd`
  - empty URI with a non-empty `id` is rejected
  - `stream` still treats hyperlink commands as no-op until a later `P5.B`
    dispatch slice wires them into typed stream actions

## Audit / result notes

- Implemented:
  - `OSC 8` prefix-state support
  - typed hyperlink start output with optional `id`
  - typed hyperlink end output
  - rejection of malformed empty-URI-with-id form
- Added tests for:
  - hyperlink start with and without `id`
  - empty `id`
  - malformed and unknown option forms
  - hyperlink end
  - invalid missing-second-semicolon form
  - parser-level `OscDispatch` for hyperlink start/end
  - stream-level no-op coverage while dispatch remains deferred
- Validation result:
  - `moon fmt`: pass
  - `moon check`: pass
  - `moon test`: pass (`193` tests)
  - `moon coverage analyze`: pass, no new touched-line residuals
  - `moon info`: pass
- Result:
  - `P4.C1` is complete
  - overall `P4.C` remains active for `P4.C2` semantic prompt and `P4.C3`
    closeout audit
