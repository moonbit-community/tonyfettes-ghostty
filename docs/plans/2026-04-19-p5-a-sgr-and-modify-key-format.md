# P5.A SGR And Modify Key Format

## Goal

Land the next bounded `P5.A` slice for `CSI m` dispatch in the stream layer,
covering both SGR attribute replay and the `CSI > m` modify-key-format subset.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/sgr.zig`

## MoonBit target files

- `src/terminal/sgr.mbt`
- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/pkg.generated.mbti`

## Dependency notes

- Builds on the already-landed SGR decoder in `src/terminal/sgr.mbt`.
- `Stream` is a public blackbox-tested surface, so SGR attribute values carried
  by `StreamAction` must use a deliberate public type name rather than leaking
  raw private parser helper names.
- Keeps `SgrParser` private; only the semantic attribute value type is widened.

## Included semantic surface

- `CSI m`
  - plain SGR attribute replay through the translated SGR parser
- `CSI > m`
  - modify-key-format reset and set subset that upstream handles in this branch

## Acceptance criteria

- `CSI m` emits one typed stream action per parsed SGR attribute
- colon-separated SGR forms continue to flow through the existing SGR parser
- `CSI > m` emits typed modify-key-format actions for supported forms
- invalid `CSI > m` forms stay silent
- tests pass in the same change

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/stream.mbt`
  - new `CSI m` and `CSI > m` branches are covered by the added stream tests
  - only the same `2` pre-existing structural residuals remain in
    `next_slice_capped` and `next_non_utf8`
- `src/terminal/sgr.mbt`
  - this slice widens the semantic attribute types to public names but does not
    change parser behavior; existing SGR tests stay green after the rename
- `src/terminal/stream_test.mbt`
  - new tests cover plain SGR replay, colon-form replay, unknown-attribute
    propagation, modify-key-format subsets, and silent invalid forms

## Commit scope

- `feat(stream)`

## Review findings

- `SgrParser` stays private; only the semantic value types are widened to
  `SgrAttribute`, `SgrUnderline`, and `SgrUnknown`
- the public rename avoids leaking a generic package-level type name
  `Unknown` through `pkg.generated.mbti`
- `CSI > m` follows the upstream narrow behavior rather than the broader
  `modify_key_format_from_int` helper mapping
- `pkg.generated.mbti` changes are limited to the new SGR semantic value types
  plus `StreamSetAttribute`

## Audit / result notes

- `moon fmt` passed
- `moon check` passed with the current warning baseline (`27` warnings)
- `moon test` passed (`185` tests)
- `moon coverage analyze` reported the same `2` pre-existing uncovered lines in
  `src/terminal/stream.mbt`
- `moon info` completed and the interface diff matched the intended SGR stream
  additions
