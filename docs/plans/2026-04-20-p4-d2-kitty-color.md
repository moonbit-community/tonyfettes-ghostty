# P4.D2 OSC 21 Kitty Color Parser

## Goal

Translate upstream `OSC 21` kitty color parsing into a typed MoonBit command
surface, wire it through the OSC state machine, and keep stream dispatch
explicitly deferred until `P5.B4`.

## Upstream files

- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers/kitty_color.zig`
- `upstream/ghostty/src/terminal/kitty/color.zig`

## MoonBit target files

- `src/terminal/osc.mbt`
- `src/terminal/osc_kitty_color.mbt`
- `src/terminal/osc_wbtest.mbt`
- `src/terminal/parser_wbtest.mbt`
- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- `src/terminal/stream_wbtest.mbt`

## Dependency notes

- This slice extends the `osc.mbt` numeric-prefix state machine with `21`.
- `RGB::parse` remains the shared color decoder for kitty color values.
- Stream dispatch is intentionally a no-op for now so parser fidelity can land
  before the downstream `P5.B4` stream action surface.

## Acceptance criteria

- `OSC 21` is recognized by `OscParser` and returns a typed
  `Command::KittyColorProtocol`.
- Requests preserve upstream behavior for query, reset, set, whitespace trim,
  unknown key ignore, invalid color ignore, and palette-key parsing.
- Parser integration and stream defer behavior are covered by tests.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/osc_kitty_color.mbt`: fully covered for the new `OSC 21`
  parser surface, including query/set/reset, trim rules, invalid inputs, and
  request-limit rejection.
- `src/terminal/stream.mbt`: one pre-existing uncovered branch remains at
  `next_slice_capped` line 181. In the current control flow, the slice walker
  enters the inner `while` only after `consume_until_ground` and
  `consume_all_escapes` have already normalized parser state, so this `else`
  arm appears unreachable from externally valid entry points. This slice only
  adds the explicit `KittyColorProtocol(_) => ()` defer in `osc_dispatch`; it
  does not change the slice-walker control flow.

## Commit scope

- `feat(parser-protocols): add osc 21 kitty color parsing`

## Review findings

- Public surface should stay limited to the typed OSC payload needed by the
  public `Command` enum. No new mutable public fields are allowed.
- `KittyColorSet::new` is kept package-private so the public surface exposes
  inspection of parser output without promising external construction helpers.

## Audit/result notes

- `OSC 21` now parses into a typed MoonBit payload.
- Stream dispatch remains deferred by design until `P5.B4`.
- Validation completed with:
  - `moon fmt`
  - `moon check`
  - `moon test`
  - `moon coverage analyze`
  - `moon info`
