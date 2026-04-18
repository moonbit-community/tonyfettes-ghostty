# Phase 0 Control Plane Execution

## Goal

Complete the remaining Phase 0 tasks in `docs/plan.md`:

- `P0.4` file mapping table
- `P0.5` translated-test inventory
- `P0.6` dependency and ownership map
- `P0.7` delegated workflow pattern

## Upstream files

- `upstream/ghostty/src/terminal/Parser.zig`
- `upstream/ghostty/src/terminal/parse_table.zig`
- `upstream/ghostty/src/terminal/UTF8Decoder.zig`
- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/dcs.zig`
- `upstream/ghostty/src/terminal/sgr.zig`
- `upstream/ghostty/src/terminal/stream_terminal.zig`
- directly referenced terminal-model support modules discovered during mapping

## MoonBit target files

- `docs/plan.md`
- `docs/plans/README.md`
- this subplan file

## Dependencies and invariants

- This is a docs-only task and must not create runnable failing code or tests.
- The output must make later implementation tasks able to finish in a green
  state.
- Delegated outputs should be integrated only after review.

## Acceptance criteria

- `docs/plan.md` contains an exact enough upstream-to-MoonBit mapping table or
  equivalent structured inventory for the parser slice.
- `docs/plan.md` contains a translated-test inventory for the scoped upstream
  parser files.
- `docs/plan.md` contains a dependency and worker-ownership map for the next
  implementation phases.
- `docs/plans/README.md` and the plan agree on the delegated-subplan contract.
- `P0.4` through `P0.7` are marked `done` in `docs/plan.md`.

## Validation commands

- Review-only validation:
  - inspect `docs/plan.md`
  - inspect `docs/plans/README.md`
  - review explorer outputs
  - review final diff

## Commit scope

- `docs`: complete Phase 0 translation control-plane docs

## Review findings

- Explorer outputs were consistent on the key phase split:
  - foundations
  - parser prerequisites
  - parser core
  - semantic decoders
  - stream integration
  - terminal application surface
- The file-mapping proposal was tightened to use a stable MoonBit target root:
  `src/terminal/{core,semantic,support,terminal}/...`
- The test inventory was adjusted so no implementation phase depends on a
  standalone failing-test commit.
- The dependency/ownership notes were incorporated into `docs/plan.md` to make
  later worker write sets explicit.

## Upstream-to-MoonBit file mapping

MoonBit root for the parser slice:

- `src/terminal/core/...`
- `src/terminal/semantic/...`
- `src/terminal/support/...`
- `src/terminal/terminal/...`

Mapping rule:

- keep one upstream file per target module where possible
- add only small shared type/helper modules where upstream boundaries or later
  terminal-model dependencies force the split

| Upstream file | Proposed MoonBit target | Layer | Notes |
|---|---|---|---|
| `src/terminal/Parser.zig` | `src/terminal/core/parser.mbt` | core | keep `parser_types`, `parse_table`, and OSC core separate so `Parser` can land as its own green commit |
| `src/terminal/parse_table.zig` | `src/terminal/core/parse_table.mbt` | core | keep table-driven and separate; share only `State`/`TransitionAction` through `core/parser_types.mbt` |
| `src/terminal/UTF8Decoder.zig` | `src/terminal/core/utf8_decoder.mbt` | core | keep separate because stream depends on its retry-on-error contract |
| `src/terminal/stream.zig` | `src/terminal/core/stream.mbt` | core | keep parser, decoder, SGR, OSC, CSI, and support enums separate rather than folding into one module |
| `src/terminal/osc.zig` | `src/terminal/semantic/osc/core.mbt` | semantic | keep core capture/state separate from long-tail subparsers |
| `src/terminal/osc/encoding.zig` | `src/terminal/semantic/osc/encoding.mbt` | semantic | separate helper so encoding tests can land independently |
| `src/terminal/osc/parsers.zig` | `src/terminal/semantic/osc/parsers/index.mbt` | semantic | thin registry only |
| `src/terminal/osc/parsers/*.zig` | `src/terminal/semantic/osc/parsers/*.mbt` | semantic | keep each subparser separate so high-frequency and long-tail OSC commands can ship in different green commits |
| `src/terminal/dcs.zig` | `src/terminal/semantic/dcs.mbt` | semantic | keep parser-facing DCS types separate from a future full terminal package |
| `src/terminal/sgr.zig` | `src/terminal/semantic/sgr.mbt` | semantic | keep iterator parser separate; use shared parser types from `core/parser_types.mbt` |
| `src/terminal/apc.zig` | `src/terminal/semantic/apc.mbt` | semantic | parser-facing protocol logic, not terminal mutation |
| `src/terminal/lib.zig` | `src/terminal/support/lib.mbt` | support | small helper layer reused by parser-facing enums/unions |
| `src/terminal/ansi.zig` | `src/terminal/support/ansi.mbt` | support | keep separate from CSI and mode values |
| `src/terminal/charsets.zig` | `src/terminal/support/charsets.mbt` | support | shared by stream and terminal-model code |
| `src/terminal/csi.zig` | `src/terminal/support/csi.mbt` | support | shared request/report/value helpers consumed by `stream` and `stream_terminal` |
| `src/terminal/device_attributes.zig` | `src/terminal/support/device_attributes.mbt` | support | separate report/value module |
| `src/terminal/device_status.zig` | `src/terminal/support/device_status.mbt` | support | separate report/value module |
| `src/terminal/modes.zig` | `src/terminal/support/modes.mbt` | support | shared contract between parsing and terminal application |
| `src/terminal/mouse.zig` | `src/terminal/support/mouse.mbt` | support | keep separate even if only a small parser-facing slice lands first |
| `src/terminal/color.zig` | `src/terminal/support/color.mbt` | support | shared by SGR and OSC color parsing |
| `src/terminal/kitty.zig` | `src/terminal/support/kitty.mbt` | support | keep parser-facing kitty flags separate from APC helpers |
| `src/terminal/kitty/color.zig` | `src/terminal/support/kitty_color.mbt` | support | needed by OSC and terminal handler |
| `src/terminal/size_report.zig` | `src/terminal/support/size_report.mbt` | support | small shared value/report module |
| `src/terminal/point.zig` | `src/terminal/support/point.mbt` | support | small shared geometry module |
| `src/terminal/main.zig` parser-facing aliases | `src/terminal/support/terminal_types.mbt` | support | copy only DCS/APC/tmux-facing parser-slice types, not the whole barrel |
| `src/terminal/stream_terminal.zig` | `src/terminal/terminal/stream_terminal.mbt` | terminal | integrate after the minimum model exists |
| `src/terminal/Terminal.zig` | `src/terminal/terminal/terminal_model.mbt` | terminal | keep separate so the terminal model can be ported in bounded slices |
| `src/terminal/Screen.zig` | `src/terminal/terminal/screen_model.mbt` | terminal | keep separate from `terminal_model.mbt` |
| `src/terminal/style.zig` | `src/terminal/terminal/style.mbt` | terminal | terminal-model support, not parser-phase code |
| `src/terminal/page.zig` | `src/terminal/terminal/page.mbt` | terminal | minimal terminal-model lane |
| `src/terminal/Tabstops.zig` | `src/terminal/terminal/tabstops.mbt` | terminal | minimal terminal-model lane |
| `src/terminal/hyperlink.zig` | `src/terminal/terminal/hyperlink.mbt` | terminal | minimal terminal-model lane |

## Translated-test inventory

- `Parser.zig`
  - essential early gates:
    - ground/print/execute smoke
    - one `ESC` dispatch with intermediates
    - one plain CSI dispatch and one CSI-with-params dispatch
    - separator-bit preservation for `:` vs `;` with at least one mixed SGR case
    - one OSC termination case
    - one DCS hook case with params
    - CSI overflow drop and DCS overflow drop
  - defer until later integration:
    - OSC semantic payload edge cases already delegated into `osc.zig`
    - duplicate OSC terminator coverage once one terminator is green
    - longest Kakoune stress inputs after one shorter mixed-separator regression is green

- `UTF8Decoder.zig`
  - essential early gates:
    - ASCII fast path
    - well-formed 1/2/3/4-byte decoding
    - partially invalid UTF-8 with replacement + retry semantics
  - defer:
    - none

- `stream.zig`
  - essential early gates:
    - `Action` ABI smoke
    - print path
    - invalid and split UTF-8 handling
    - one representative CSI mapping (`CUF`)
    - one DEC mode set/reset case
    - one ANSI mode set/reset case
    - robustness for too many params and overly long params
  - defer until later integration:
    - command-family matrices such as `DECSCA`, `DECED`, `DECEL`, `DECSCUSR`, `XTSHIFTESCAPE`
    - title push/pop matrix
    - 17-parameter SGR regression until `sgr` is wired into stream
    - kitty keyboard defaulting until kitty action surface is translated

- `osc.zig`
  - early gate:
    - compile/smoke coverage is optional; direct behavior is better gated through `Parser` first
  - defer:
    - file-local smoke test if parser-visible OSC behavior is already covered

- `dcs.zig`
  - essential early gates:
    - unknown-command ignore path
    - one basic `XTGETTCAP` case
    - multiple-key `XTGETTCAP` iteration
    - invalid-data normalization
    - valid and invalid `DECRQSS`
  - defer:
    - tmux control-mode coverage
    - mixed-case canonicalization if normalization is already covered elsewhere

- `sgr.zig`
  - essential early gates:
    - parser basics and multi-item iteration
    - bold/italic/underline toggles
    - underline-style colon decoding
    - 8-color, 256-color, and one direct-color case
    - underline color plus reset
    - malformed-input non-crash cases: missing color, too many colons, trailing separator
    - at least one Kakoune regression input
  - defer:
    - ABI smoke
    - duplicate color-family variants once one case per family is green
    - the second Kakoune regression once one real-world mixed sequence is green

## Dependency and worker-ownership map

- Serial gate 1: package skeleton and shared ownership map
  - owner: main agent
  - output: package layout, shared type locations, docs/plans entry for the task
  - green rule: no placeholder tests that fail; only land skeletons that keep
    `moon check`, `moon test`, `moon fmt`, and `moon info` green

- Parallel worker lane A: foundational enums and charsets
  - upstream: `ansi.zig`, `charsets.zig`, `modes.zig`
  - write set: foundational parser-support modules and their tests
  - do not edit parser core, stream, or terminal-model files

- Parallel worker lane B: reports and device-facing value types
  - upstream: `device_attributes.zig`, `device_status.zig`, `mouse.zig`, `color.zig`
  - write set: parser-facing report/color/mouse/device modules and tests
  - do not edit lane A, parser core, stream, or terminal-model files

- Parallel worker lane C: small geometry and report helpers
  - upstream: `point.zig`, `size_report.zig`, parser-local small structs
  - write set: small shared value modules and tests only
  - do not edit lanes A/B or parser core

- Serial gate 2: parser prerequisites contract freeze
  - owner: main agent after explorer pass
  - output: exact invariants for UTF-8 retry behavior, parse-table representation,
    and the minimal OSC core needed by `Parser`

- Parallel worker lane D: UTF-8 decoder
  - upstream: `UTF8Decoder.zig`
  - write set: UTF-8 decoder and direct tests only
  - do not edit parse table, parser, or stream

- Parallel worker lane E: parse table
  - upstream: `parse_table.zig`
  - write set: parse table module or generated representation and smoke tests
  - do not edit decoder, OSC, or parser implementation

- Parallel worker lane F: minimal OSC parser core
  - upstream: parser-facing subset of `osc.zig`
  - write set: OSC core parser module and parser-local tests
  - do not edit parse table, UTF-8 decoder, or long-tail OSC semantic modules

- Serial gate 3: `Parser`
  - upstream: `Parser.zig`
  - write set: parser module and direct tests only
  - do not edit stream, semantic decoders, or terminal-model files in this lane

- Parallel worker lanes after `Parser` is green:
  - G: `sgr`
  - H: `dcs`
  - I: high-frequency OSC handlers
  - J: OSC long tail and APC helpers
  - each lane owns code + tests together and stays out of `stream` and terminal files

- Serial gate 4: `stream` driver core
  - owner: main agent or one tightly scoped worker
  - output: `Stream.Action`, handler interface, driver skeleton, base stream tests
  - do not mix in broad dispatch work until the base driver is green

- Parallel worker lanes after stream-core is green:
  - K: execute/ESC/CSI dispatch
  - L: OSC dispatch wiring
  - M: DCS/APC passthrough wiring

- Parallel worker lanes for terminal-model minimum surface:
  - N: style and attributes
  - O: cursor, tabstops, and modes
  - P: screen, page, and hyperlink state

- Cross-layer hazards to watch:
  - `Parser.next` three-action ordering getting reordered in MoonBit control flow
  - flattening `parse_table` into ad hoc conditionals
  - simplifying UTF-8 retry semantics and breaking stream replay behavior
  - overbuilding OSC before `Parser` needs are frozen
  - letting CSI semantics drift between `stream` and `sgr`
  - broadening terminal-model workers beyond the parser-facing minimum surface

## Audit/result notes

- `P0.4` through `P0.7` were completed in `docs/plan.md`.
- `docs/plans/README.md` already satisfied the delegated-subplan requirement,
  so no further structural change was needed there for this phase.
- This phase remained docs-only and required no MoonBit validation commands.
