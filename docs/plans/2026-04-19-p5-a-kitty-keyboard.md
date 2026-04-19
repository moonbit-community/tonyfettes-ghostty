# P5.A8 Kitty Keyboard Protocol

## Goal

Land the final remaining execute / ESC / CSI implementation slice in `P5.A` by
translating the kitty keyboard protocol branch under `CSI u`.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/kitty/key.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- Builds on the existing `CSI` dispatch work already landed in `P5.A1` through
  `P5.A7`.
- Keeps the kitty keyboard payload narrow:
  - one packed flag wrapper for the upstream `u5`
  - direct `UInt16` payload for pop count
- Does not introduce a separate kitty package yet; this slice only mirrors the
  stream semantic surface.

## Included semantic surface

- `CSI ? u` -> kitty keyboard query
- `CSI > u` -> kitty keyboard push
- `CSI < u` -> kitty keyboard pop
- `CSI = u` -> kitty keyboard set
- `CSI = <flags> ; 2 u` -> kitty keyboard set-or
- `CSI = <flags> ; 3 u` -> kitty keyboard set-not

## Acceptance criteria

- valid kitty keyboard forms emit typed stream actions
- invalid flag-width and invalid set-mode selector forms stay silent
- the MoonBit port preserves upstream oddities:
  - `CSI >` with extra params falls back to disabled flags
  - `CSI <` with extra params falls back to pop count `1`
  - `CSI ?` ignores params and still emits query
  - `CSI =` ignores params after the second one
- tests pass in the same change

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream.mbt`
  - new kitty keyboard `CSI u` branches are covered by the added subset,
    tolerance, and invalid-form tests
  - only the same `2` pre-existing structural residuals remain in
    `next_slice_capped` and `next_non_utf8`
- `src/terminal/stream_test.mbt`
  - new tests cover valid query / push / pop / set / set-or / set-not actions
  - new tests also cover upstream tolerance behavior for extra parameters
  - invalid flag-width and invalid set-mode selector cases stay silent

## Commit scope

- `feat(stream)`

## Review findings

- kitty keyboard payload stays minimal: one tuple wrapper for the packed flag
  value and a plain `UInt16` for pop count
- the MoonBit port preserves the upstream quirks for extra parameters instead
  of tightening them into a stricter protocol
- `pkg.generated.mbti` changes should be limited to `KittyKeyboardFlags` plus
  the six kitty keyboard stream actions

## Audit / result notes

- `moon fmt` passed
- `moon check` passed with the current warning baseline (`27` warnings)
- `moon test` passed (`188` tests)
- `moon coverage analyze` reported the same `2` pre-existing uncovered lines in
  `src/terminal/stream.mbt`
- `moon info` completed and the interface diff matched the intended kitty
  keyboard stream additions
