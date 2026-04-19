# P5.A Foundational ESC / CSI Slice

## Goal

Land the first semantic-dispatch slice for Phase 5A by replacing selected
execute / ESC / CSI placeholders with typed stream actions that already map
cleanly onto translated MoonBit value types.

This slice is intentionally limited to the highest-signal actions needed to
turn the stream from a shell into a useful semantic dispatcher while still
ending in a green commit.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/Parser.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- This slice builds directly on `P5.1`.
- It uses existing translated value types from:
  - `ansi.mbt`
  - `charsets.mbt`
  - `modes.mbt`
- It does not widen into OSC, DCS, APC, or the broader CSI space.
- It does not attempt to land the entire `stream.zig` action union in one
  commit.

## Included semantic surface

- ESC charset configuration:
  - `ESC ( B`
  - `ESC ) A`
  - `ESC * 0`
- ESC cursor / keypad subset:
  - `ESC 7`
  - `ESC 8`
  - `ESC =`
  - `ESC >`
- ESC charset invocation subset:
  - `ESC N`
  - `ESC O`
  - `ESC n`
  - `ESC o`
  - `ESC ~`
  - `ESC }`
  - `ESC |`
- CSI subset:
  - `CUF` (`CSI C`)
  - `SM` / `RM` (`CSI h` / `CSI l`)
  - `ED` / `DECSED` (`CSI J`, `CSI ? J`)
  - `EL` / `DECSEL` (`CSI K`, `CSI ? K`)
  - `DECSCUSR` (`CSI SP q`)

## Acceptance criteria

- stream emits typed actions for the listed ESC / CSI cases
- invalid forms are ignored without corrupting later parsing
- tests cover both valid and rejected forms for the touched cases
- `moon check`, `moon test`, `moon coverage analyze`, `moon fmt`, and
  `moon info` all run before commit

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `moon coverage analyze` leaves 2 uncovered lines in `src/terminal/stream.mbt`
- reviewed as structural invariants carried forward from the stream driver core:
  - the `next_slice_capped` branch that re-enters `consume_until_ground`
    inside the post-escape loop stays unreachable under the current greedy
    `consume_all_escapes` flow
  - the `Some(Print(codepoint))` arm in `next_non_utf8` stays unreachable
    under the current parser contract because parser `Print` is emitted only
    from ground-state printable input
- all newly added ESC / CSI semantic branches in this slice are covered

## Commit scope

- `feat(stream)`

## Review findings

- public API audit:
  - added only action/value types that this slice actually emits:
    `ConfigureCharsetAction`, `CursorMovement`, and the new `StreamAction`
    variants
  - no parser state or mutable internal stream state was exposed
- behavioral audit:
  - ESC charset configuration now emits semantic actions instead of being a
    no-op, so earlier shell-era expectations were updated accordingly
  - C1 bytes in the `0x80..0x9F` range now route through `execute` on the
    scalar ground path before UTF-8 decoding

## Audit / result notes

- implemented in this slice:
  - ESC charset configuration for `B`, `A`, `0`
  - ESC save/restore cursor and keypad mode toggles
  - ESC invoke-charset subset `N`, `O`, `n`, `o`, `~`, `}`, `|`
  - CSI `C`, `h`, `l`, `J`, `K`, and `SP q`
- intentionally still deferred in `P5.A`:
  - broader cursor movement and positioning
  - tab-control, margins, reports, protected-mode, and SGR wiring
- validation run:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
