# P5.A Tab And Cursor Controls

## Goal

Land the next bounded `P5.A` slice for stream semantic dispatch:

- tab-stop control
- insert blanks
- cursor save/restore-related CSI controls
- shift-escape capture

This slice intentionally avoids `CSI t` report requests so we do not overload
the current `size_report.Style` encoder enum with request-only semantics.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- Builds directly on the previous `P5.A` slice.
- Reuses existing public actions where possible, such as
  `StreamRestoreCursor`.
- Keeps `CSI t`, broader cursor positioning, margins, protected mode, and SGR
  deferred for later `P5.A` slices.

## Included semantic surface

- `CSI W`
  - tab set
  - clear current/all tab stops
  - reset tab stops via `CSI ? 5 W`
- `CSI g`
  - clear current/all tab stops
  - overflow-safe ignore behavior
- `CSI @`
  - insert blanks with zero clamped to one
- `CSI s`
  - left/right margin ambiguous zero-param form
  - `CSI > s` shift-escape capture
- `CSI u`
  - restore cursor

## Acceptance criteria

- covered controls emit typed stream actions
- invalid forms are ignored without corrupting later parsing
- tab-clear overflow input does not crash
- tests pass in the same change

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream.mbt` is covered for the newly added tab, insert-blanks,
  and cursor-control dispatch paths.
- Two residual uncovered lines remain and are treated as structural for now:
  - `next_slice_capped` loop branch that re-enters `consume_until_ground`
    inside the main loop. With the current fast path, leading escape bytes are
    consumed by `consume_all_escapes`, and incomplete escape states at slice
    boundaries return early before that branch can be reached.
  - `next_non_utf8` branch for `Some(Print(codepoint))`. A direct parse-table
    audit shows the generated table never emits `Print` outside `Ground`, while
    `next_non_utf8` is only entered from non-ground parser states.

## Commit scope

- `feat(stream)`

## Review findings

- `CSI t` remains intentionally deferred because the current size-report value
  types model encoder output, not request-side report selectors.
- Added regression coverage for ignored empty/multi-param `CSI g` and `CSI @`
  forms so helper `None` branches are exercised in green state.
- `.mbti` visibility diff is limited to the new `StreamAction` variants for
  this slice; no parser-internal state was exposed.

## Audit / result notes

- Validation run:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
- Result: implementation complete for this slice and ready to land as a green,
  atomic commit.
