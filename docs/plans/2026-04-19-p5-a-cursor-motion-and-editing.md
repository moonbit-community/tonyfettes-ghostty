# P5.A Cursor Motion And Editing

## Goal

Land the next bounded `P5.A` slice for cursor motion, positioning, tab
movement, and counted editing commands in the stream layer.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- Builds on the existing `P5.A` stream slices.
- Reuses `CursorMovement` for relative/absolute one-value cursor actions.
- Introduces a dedicated cursor-position record for `CUP`/`HVP`.
- Defers margins, mode save/restore, and device-status/device-attributes
  requests to later slices.

## Included semantic surface

- cursor motion and positioning:
  - `CSI A`, `CSI k`
  - `CSI B`
  - `CSI D`, `CSI j`
  - `CSI E`
  - `CSI F`
  - `CSI G`, ``CSI ` ``
  - `CSI H`, `CSI f`
  - `CSI I`
  - `CSI Z`
  - `CSI a`
  - `CSI d`
  - `CSI e`
- counted editing commands:
  - `CSI L`
  - `CSI M`
  - `CSI P`
  - `CSI S`
  - `CSI T`
  - `CSI X`
  - `CSI b`

## Acceptance criteria

- supported cursor and editing controls emit typed stream actions
- invalid arity or unsupported intermediates are ignored
- aliases such as `CSI k`, `CSI j`, ``CSI ` ``, and `CSI f` match upstream
- tests pass in the same change

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream.mbt` covers the newly added cursor motion, cursor
  position, tab-back, repeat-char, and counted editing dispatch helpers.
- The only remaining uncovered lines in `src/terminal/stream.mbt` are the same
  two structural residuals already recorded in earlier `P5.A` slices:
  - `next_slice_capped` main-loop re-entry into `consume_until_ground`
  - `next_non_utf8` branch for `Some(Print(codepoint))`

## Commit scope

- `feat(stream)`

## Review findings

- Added a dedicated `CursorPosition` record for `CUP`/`HVP` rather than
  overloading the more general `Point` coordinate types.
- Reused `CursorMovement` for both relative and absolute one-value cursor
  actions, matching the upstream `CursorMovement` contract.
- `.mbti` changes are limited to the new semantic stream surface for this slice.

## Audit / result notes

- Validation run:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
- Result: implementation complete for this slice and ready to land as a green,
  atomic commit.
