# P5.1 Stream Driver Core

## Goal

Land the scalar stream driver core for the translated parser stack:

- own the handler, parser, and UTF-8 decoder
- preserve base replay ordering
- expose a narrow semantic action surface
- leave later dispatch breadth to the remaining Phase 5 lanes

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/Parser.zig`
- `upstream/ghostty/src/terminal/UTF8Decoder.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- This task intentionally implements the scalar stream shell first.
- CSI / ESC / OSC / DCS / APC dispatch functions are explicit placeholders in
  this slice and remain owned by later Phase 5 tasks.
- The public semantic surface in this task is only the base action set used by
  the current tests.

## Acceptance criteria

- `Stream` owns handler, parser, and UTF-8 decoder
- `next` and `next_slice` compile and preserve UTF-8 retry behavior
- base C0 actions emit semantic `StreamAction` values
- ignored escape-sequence paths return to printable ground-state behavior
- tests pass in the same change

## Validation commands

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` leaves 2 uncovered lines in `src/terminal/stream.mbt`
- reviewed as structural invariants, not ordinary missing tests:
  - the `next_slice_capped` loop branch that calls `consume_until_ground`
    after the main slice loop starts is unreachable under the current greedy
    `consume_all_escapes` flow, because any visible `ESC` run is consumed
    either before the loop or at the loop tail once ground is re-entered
  - the `Some(Print(codepoint))` arm in `next_non_utf8` is unreachable under
    the current parser contract, because `Parser::Print` is emitted only from
    ground-state printable input, while `next_non_utf8` is entered only when
    the stream is already in a non-ground parser state
- reviewer signoff: accepted for P5.1 because the uncovered lines reflect
  control-flow guards that stay explicit for faithful translation, not missing
  user-visible behavior in the current slice

## Commit scope

- `feat(stream)`

## Review findings

- public API audit:
  - keep `Stream`, `StreamHandler`, `StreamAction`, and
    `InvokeCharsetAction` public for the external host-facing driver surface
  - do not expose parser state, UTF-8 decoder state, or the owned handler
    directly; the earlier temporary `handler()` accessor was removed before
    landing
- behavior audit:
  - UTF-8 invalid-continuation retry is covered through the public
    `next_slice` API
  - placeholder CSI/OSC/DCS/APC paths are covered only for ground-return
    behavior in this slice; semantic dispatch breadth remains Phase 5A-5C

## Audit / result notes

- implemented:
  - scalar `Stream` shell owning handler, `Parser`, and `Utf8Decoder`
  - base semantic action surface for printable codepoints and core C0 controls
  - placeholder dispatch sinks for CSI/ESC/OSC/DCS/APC with recovery-to-ground
    tests
- validation run:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
