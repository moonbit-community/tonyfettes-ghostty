# P4.D6 Context Signal And Kitty Text Sizing

## Goal

Translate the remaining structured logging-only OSC protocols into typed
MoonBit payloads:

- `OSC 3008` hierarchical context signalling
- `OSC 66` kitty text sizing

Both protocols should parse faithfully, expose deliberate read-only accessors,
and remain intentionally silent at the Phase 4 stream layer.

## Upstream files

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/context_signal.zig`
- `upstream/ghostty/src/terminal/osc/parsers/kitty_text_sizing.zig`
- `upstream/ghostty/src/terminal/osc/encoding.zig`

## MoonBit target files

- `src/terminal/osc.mbt`
- `src/terminal/osc_context_signal.mbt`
- `src/terminal/osc_kitty_text_sizing.mbt`
- `src/terminal/osc_wbtest.mbt`
- `src/terminal/parser_wbtest.mbt`
- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`

## Dependency notes

- `OSC 3008` extends the numeric prefix ladder with `3 -> 30 -> 300 -> 3008`
  and parses to a typed raw-metadata carrier with lazy field readers.
- `OSC 66` extends the ladder with `6 -> 66` and parses to a typed payload
  carrying validated escape-safe UTF-8 text plus numeric/alignment parameters.
- The parser now distinguishes fixed-capture vs allocating-capture states so
  the `OSC 66` payload limit is enforced by the protocol parser rather than the
  generic fixed buffer.
- Stream integration remains a no-op for both protocols in this phase.

## Acceptance criteria

- `OscParser` recognizes `OSC 3008` and emits a typed context signal payload.
- `OscParser` recognizes `OSC 66` and emits a typed kitty text sizing payload.
- `OSC 3008` preserves action, validated context ID, and raw metadata with
  lazy readers for typed fields.
- `OSC 66` preserves numeric/alignment parameters, terminator, and validated
  escape-safe UTF-8 text.
- Parser integration and Phase 4 stream no-op behavior are covered by tests.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/osc.mbt`: newly added prefix states, allocating-capture path,
  and invalid-prefix branches are covered.
- `src/terminal/osc_context_signal.mbt`: start/end parsing, missing fields,
  numeric validation, overflow rejection, enum decoding, and raw metadata
  accessors are covered.
- `src/terminal/osc_kitty_text_sizing.mbt`: parameter decoding, invalid key and
  value handling, safe UTF-8 acceptance, malformed UTF-8 rejection, control
  rejection, and long payload handling are covered.
- `src/terminal/stream.mbt`: the new `ContextSignal(_) => ()` and
  `KittyTextSizing(_) => ()` branches are covered. One pre-existing uncovered
  line remains at `next_slice_capped` line 181, matching the prior residual
  carried across earlier Phase 4D audits.

## Commit scope

- `feat(parser-protocols): add osc 3008 and osc 66 parsing`

## Review findings

- The public API grows intentionally with two new opaque payload types plus the
  enums required to interpret their structured fields.
- Constructors remain package-private. Callers only get typed read access.
- The generic OSC parser now allows allocating-capture states to grow past the
  fixed buffer limit, which is required to stay faithful for `OSC 66` payload
  sizing and also improves fidelity for other allocating OSC branches.

## Audit/result notes

- `OSC 3008` now surfaces a typed context signal command with validated
  identifier handling and lazy metadata readers instead of disappearing into an
  untyped string surface.
- `OSC 66` now surfaces typed numeric/alignment fields and validated
  escape-safe UTF-8 text instead of remaining unimplemented.
- Both protocols are still intentionally silent at the stream layer until the
  later Phase 5 integration work.
- Validation completed with:
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon fmt`
  - `moon info`
