# P4.C2 Semantic Prompt Parser

## Goal

Land typed `OSC 133` semantic-prompt parsing in the MoonBit OSC decoder,
including option accessors and command-line decoding behavior that matches the
upstream parser contracts.

## Upstream files

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/semantic_prompt.zig`
- `upstream/ghostty/src/os/string_encoding.zig`

## MoonBit target files

- `src/terminal/osc.mbt`
- `src/terminal/osc_semantic_prompt.mbt`
- `src/terminal/osc_wbtest.mbt`
- `src/terminal/parser_wbtest.mbt`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-19-p4-c-roadmap.md`
- `docs/plans/2026-04-20-p4-c-semantic-prompt.md`

## Dependency notes

- This slice extends the current `OSC` high-frequency decoder lane after
  `P4.C1` hyperlink support.
- `P5.B3` depends on this slice exposing a typed `Command::SemanticPrompt`
  payload.
- The terminal-side meaning of semantic prompts remains Phase 6 work; this
  slice is only about parser fidelity and typed parser outputs.

## Acceptance criteria

- `OSC 133` commands parse into a typed semantic-prompt payload
- valid actions preserve raw option storage and typed per-option accessors
- command-line decoding follows upstream `printf %q` and URL-percent decode
  behavior, including decode errors
- invalid extra content and malformed prefixes are rejected like upstream
- parser integration emits `OscDispatch(SemanticPrompt(...))`

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` after this slice leaves no uncovered lines in the
  touched semantic-prompt parser files.
- The run still reports two pre-existing residual lines in
  `src/terminal/stream.mbt`:
  - `next_slice_capped` fallback `consume_until_ground` branch
  - `next_non_utf8` direct `Print(codepoint)` branch
- Those `stream.mbt` residuals predate this slice and are not caused by the
  semantic-prompt parser changes.

## Commit scope

- `feat(parser-protocols)`

## Review findings

- `SemanticPrompt` stays opaque; callers only get the typed accessor surface.
- `SemanticPromptAction`, `SemanticPromptClick`, `SemanticPromptKind`,
  `SemanticPromptRedraw`, and `SemanticPromptDecodeError` are public because
  they appear in public method signatures.
- `Command::SemanticPrompt` is an intentional parser-surface expansion needed by
  downstream stream and terminal work.
- `Stream::osc_dispatch` intentionally ignores `SemanticPrompt(_)` for now; that
  no-op is covered by `stream_test.mbt` and deferred to later stream-terminal
  integration work.

## Audit / result notes

- Added `src/terminal/osc_semantic_prompt.mbt` as a faithful `OSC 133` parser
  slice with:
  - typed action decoding
  - raw option storage plus typed per-option accessors
  - exit-code extraction for `OSC 133;D`
  - `printf %q` decoding and URL-percent decoding
- Switched semantic-prompt byte-to-text decoding to
  `moonbitlang/core/encoding/utf8` so decoded command lines are built from raw
  bytes without relying on `Buffer::to_string()`.
- Extended `src/terminal/osc.mbt` with `OSC 133` prefix-state support and a
  typed `Command::SemanticPrompt` output.
- Added direct parser tests, parser integration coverage, and a stream-level
  test that locks in the current temporary no-op dispatch behavior.
- Validation run for this slice:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
