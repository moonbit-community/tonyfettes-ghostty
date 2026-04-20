# P4.D5 Kitty Clipboard Protocol

## Goal

Translate upstream `OSC 5522` kitty clipboard parsing into a typed MoonBit OSC
payload with faithful metadata/payload splitting, typed option readers, and the
current-phase stream behavior of remaining intentionally silent until `P5.B6`.

## Upstream files

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/kitty_clipboard_protocol.zig`

## MoonBit target files

- `src/terminal/osc.mbt`
- `src/terminal/osc_kitty_clipboard.mbt`
- `src/terminal/osc_wbtest.mbt`
- `src/terminal/parser_wbtest.mbt`
- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`

## Dependency notes

- This slice extends the `osc.mbt` numeric-prefix state machine with the
  `55 -> 552 -> 5522` branch while preserving the existing `OSC 52` path.
- The kitty clipboard payload is its own typed command surface; it should not
  be collapsed into `ClipboardContents` because upstream carries raw metadata,
  optional payload, and terminator state with typed option decoding on top.
- Stream handling remains an intentional no-op in this phase and will be
  revisited in `P5.B6`.

## Acceptance criteria

- `OscParser` recognizes `OSC 5522` and emits a typed kitty clipboard payload.
- The payload preserves raw metadata, optional payload, and terminator.
- Typed option readers preserve upstream behavior for:
  - `id`
  - `loc`
  - `mime`
  - `name`
  - `password`
  - `pw`
  - `status`
  - `type`
- Parser integration and current stream no-op behavior are covered by tests.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/osc_kitty_clipboard.mbt`: fully covered for metadata/payload
  splitting, typed option readers, identifier validation, whitespace handling,
  enum decoding, and malformed metadata edge cases.
- `src/terminal/osc.mbt`: newly added `55` / `552` / `5522` transitions and
  malformed-state branches are covered.
- `src/terminal/stream.mbt`: the new `KittyClipboardProtocol(_) => ()` no-op
  branch is covered. One pre-existing uncovered line remains at
  `next_slice_capped` line 181, the same residual already documented in prior
  Phase 4D audits.

## Commit scope

- `feat(parser-protocols): add osc 5522 kitty clipboard parsing`

## Review findings

- The public API grows intentionally here because `Command` needs a typed kitty
  clipboard payload and external consumers need read access to its decoded
  option surface.
- Constructors remain package-private. The public surface is limited to opaque
  payload accessors plus the typed enums needed to interpret metadata.

## Audit/result notes

- `OSC 5522` now parses into a typed MoonBit payload instead of disappearing
  into the generic clipboard surface.
- The option readers follow the upstream metadata contract, including
  whitespace trimming, identifier validation, and exact enum decoding.
- Stream behavior remains intentionally silent for this protocol until `P5.B6`.
- Validation completed with:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
