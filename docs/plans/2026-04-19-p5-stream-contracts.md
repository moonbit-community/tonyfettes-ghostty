# P5.0 Stream Contracts

## Goal

Record the Phase 5 integration boundary for `stream.zig` before landing the
MoonBit driver core.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/Parser.zig`
- `upstream/ghostty/src/terminal/UTF8Decoder.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/dcs.zig`
- `upstream/ghostty/src/terminal/sgr.zig`

## MoonBit target files

- `src/terminal/stream.mbt`
- `src/terminal/stream_test.mbt`
- future Phase 5 lane files if the stream dispatch body needs to be split

## Dependency notes

- `stream.zig` is the semantic join point between the low-level parser and the
  higher-level terminal actions.
- `Parser.next` remains the raw three-action state-machine API. `Stream` must
  replay those parser actions in-order.
- `Utf8Decoder::next` retry-on-error semantics are required to preserve the
  ground-state fast path contract.
- For MoonBit, the callback-style Zig handler contract is translated into a
  public open trait. This keeps the semantic action boundary explicit without
  exposing parser internals.
- Phase 5 is split so that P5.1 only establishes:
  - stream ownership of handler, parser, and UTF-8 decoder
  - scalar `next` / `next_slice` driver flow
  - replay ordering for base actions
  - placeholders for CSI / ESC / OSC routing
- The later Phase 5 lanes own semantic dispatch breadth:
  - P5.A: execute, ESC, CSI semantic dispatch
  - P5.B: OSC semantic dispatch
  - P5.C: DCS / APC passthrough
- The SIMD fast path stays out of P5.1. The function boundaries are preserved
  so that a later optimization pass can fill them in without changing the
  stream surface.

## Handler contract

The MoonBit stream layer uses an open trait:

- `StreamHandler::vt(Self, Action) -> Unit`
- `StreamHandler::deinit(Self) -> Unit`

The stream owns the handler, like upstream Zig.

## Action split

P5.1 base action surface:

- printable codepoints
- basic C0 controls:
  - bell
  - backspace
  - horizontal tab
  - linefeed
  - carriage return
  - enquiry
  - shift in / shift out charset locking

Deferred to later Phase 5 lanes:

- CSI semantic actions
- ESC semantic actions
- OSC semantic actions
- DCS / APC passthrough actions

## Acceptance criteria

- `stream.zig` ownership and replay boundaries are recorded
- the MoonBit handler trait and base action surface are explicit
- the P5.1 scope is narrow enough to end green without unfinished dispatch
  breadth

## Validation commands

- doc review against `docs/architecture.md`
- doc review against `docs/plan.md`
- consistency review against current `src/terminal` package layout

## Commit scope

- `docs`

## Review findings

- The plan originally treated Phase 5 as strictly after the full Phase 4
  semantic decoder gate. In practice, the driver core can land earlier as long
  as unsupported dispatch groups stay explicitly stubbed and the phase board
  continues to track the remaining stream lanes.

## Audit / result notes

- Ready for P5.1 implementation.
