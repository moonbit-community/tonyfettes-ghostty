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
- The initial multi-package proposal was rejected after a dependency review.
- The control-plane mapping now uses a single MoonBit package root:
  `src/terminal/...`
- The test inventory was adjusted so no implementation phase depends on a
  standalone failing-test commit.
- Worker ownership remains useful, but it should be expressed as file ownership
  inside one package, not as separate packages.

## Packaging decision

Decision:

- Use one MoonBit package under `src/terminal`.

Rejected alternative:

- one MoonBit package per translated Zig file

Why:

- `Parser.zig` and `parse_table.zig` are mutually coupled at the type level.
- `dcs.zig` imports `main.zig` for `terminal.DCS`, while `main.zig` re-exports
  both `dcs` and `Parser`.
- `osc.zig` imports `kitty/color.zig`, and `kitty/color.zig` imports
  `../main.zig` for `terminal.color.RGB` and `terminal.osc.Terminator`.
- `sgr.zig` depends on `Parser.Action.CSI.SepList`.
- `stream.zig` is already the integrator over nearly the entire parser slice.

These edges are natural file-level dependencies in Zig, but they would force
either package cycles or premature refactors in MoonBit.

Source references:

- `Parser.zig:9` <-> `parse_table.zig:13`
- `dcs.zig:5-6` and `main.zig:9,36-44`
- `osc.zig:16` and `kitty/color.zig:2-4`
- `sgr.zig:8`
- `stream.zig:9-20`

## Upstream-to-MoonBit file mapping

MoonBit root for the parser slice:

- `src/terminal/...`

Mapping rule:

- keep one upstream file per target MoonBit file where possible
- keep all translated parser-slice files in one package unless a later
  dependency review shows a clean package split
- add only small helper files when MoonBit or generated data organization forces
  it, not to simulate package boundaries

| Upstream file | Proposed MoonBit target | Layer | Notes |
|---|---|---|---|
| `src/terminal/Parser.zig` | `src/terminal/parser.mbt` | parser core | keep as a direct file-level translation target |
| `src/terminal/parse_table.zig` | `src/terminal/parse_table.mbt` | parser core | keep table-driven and adjacent to `parser.mbt` because of mutual dependency |
| `src/terminal/UTF8Decoder.zig` | `src/terminal/utf8_decoder.mbt` | parser core | leaf-like file, but keep in the same package |
| `src/terminal/stream.zig` | `src/terminal/stream.mbt` | parser core | stream remains the parser/action integrator |
| `src/terminal/osc.zig` | `src/terminal/osc.mbt` | semantic | keep as one primary file first; split helpers only if needed later |
| `src/terminal/osc/encoding.zig` | `src/terminal/osc_encoding.mbt` | semantic helper | flatten into the same package unless a stronger reason appears |
| `src/terminal/osc/parsers.zig` | `src/terminal/osc_parsers.mbt` | semantic helper | registry/helper file in the same package |
| `src/terminal/osc/parsers/*.zig` | `src/terminal/osc_parser_*.mbt` | semantic helper | keep parser-specific files in the same package |
| `src/terminal/dcs.zig` | `src/terminal/dcs.mbt` | semantic | keep near `parser.mbt` and `stream.mbt` because of `DCS` ties |
| `src/terminal/sgr.zig` | `src/terminal/sgr.mbt` | semantic | keep in-package because it depends on parser CSI separator types |
| `src/terminal/apc.zig` | `src/terminal/apc.mbt` | semantic | same package; parser-facing protocol logic |
| `src/terminal/lib.zig` | `src/terminal/lib.mbt` | support | file-level helper only |
| `src/terminal/ansi.zig` | `src/terminal/ansi.mbt` | support | same package support file |
| `src/terminal/charsets.zig` | `src/terminal/charsets.mbt` | support | same package support file |
| `src/terminal/csi.zig` | `src/terminal/csi.mbt` | support | same package support file |
| `src/terminal/device_attributes.zig` | `src/terminal/device_attributes.mbt` | support | same package support file |
| `src/terminal/device_status.zig` | `src/terminal/device_status.mbt` | support | same package support file |
| `src/terminal/modes.zig` | `src/terminal/modes.mbt` | support | same package support file |
| `src/terminal/mouse.zig` | `src/terminal/mouse.mbt` | support | same package support file |
| `src/terminal/color.zig` | `src/terminal/color.mbt` | support | same package support file |
| `src/terminal/kitty.zig` | `src/terminal/kitty.mbt` | support | same package support file |
| `src/terminal/kitty/color.zig` | `src/terminal/kitty_color.mbt` | support helper | flattened helper in same package |
| `src/terminal/size_report.zig` | `src/terminal/size_report.mbt` | support | same package support file |
| `src/terminal/point.zig` | `src/terminal/point.mbt` | support | same package support file |
| `src/terminal/main.zig` parser-facing aliases | `src/terminal/terminal_aliases.mbt` | support | only if alias consolidation is still needed after direct translation begins |
| `src/terminal/stream_terminal.zig` | `src/terminal/stream_terminal.mbt` | terminal integration | same package, later phase |
| `src/terminal/Terminal.zig` | `src/terminal/terminal_model.mbt` | terminal model | same package, later phase |
| `src/terminal/Screen.zig` | `src/terminal/screen_model.mbt` | terminal model | same package, later phase |
| `src/terminal/style.zig` | `src/terminal/style.mbt` | terminal model | same package, later phase |
| `src/terminal/page.zig` | `src/terminal/page.mbt` | terminal model | same package, later phase |
| `src/terminal/Tabstops.zig` | `src/terminal/tabstops.mbt` | terminal model | same package, later phase |
| `src/terminal/hyperlink.zig` | `src/terminal/hyperlink.mbt` | terminal model | same package, later phase |

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
  - output: single-package layout, shared type locations, docs/plans entry for
    the task
  - green rule: no placeholder tests that fail; only land skeletons that keep
    `moon check`, `moon test`, `moon fmt`, and `moon info` green

- Parallel worker lane A: foundational enums and charsets
  - upstream: `ansi.zig`, `charsets.zig`, `modes.zig`
  - write set: `src/terminal/{ansi,charsets,modes}*.mbt` and their tests
  - do not edit parser core, stream, or terminal-model files

- Parallel worker lane B: reports and device-facing value types
  - upstream: `device_attributes.zig`, `device_status.zig`, `mouse.zig`, `color.zig`
  - write set:
    `src/terminal/{device_attributes,device_status,mouse,color}*.mbt` and
    their tests
  - do not edit lane A, parser core, stream, or terminal-model files

- Parallel worker lane C: small geometry and report helpers
  - upstream: `point.zig`, `size_report.zig`, parser-local small structs
  - write set: `src/terminal/{point,size_report}*.mbt` and their tests only
  - do not edit lanes A/B or parser core

- Serial gate 2: parser prerequisites contract freeze
  - owner: main agent after explorer pass
  - output: exact invariants for UTF-8 retry behavior, parse-table representation,
    and the minimal OSC core needed by `Parser`

- Parallel worker lane D: UTF-8 decoder
  - upstream: `UTF8Decoder.zig`
  - write set: `src/terminal/utf8_decoder*.mbt` and direct tests only
  - do not edit parse table, parser, or stream

- Parallel worker lane E: parse table
  - upstream: `parse_table.zig`
  - write set: `src/terminal/parse_table*.mbt` and smoke tests
  - do not edit decoder, OSC, or parser implementation

- Parallel worker lane F: minimal OSC parser core
  - upstream: parser-facing subset of `osc.zig`
  - write set: `src/terminal/osc*.mbt` parser-core subset and parser-local
    tests
  - do not edit parse table, UTF-8 decoder, or long-tail OSC semantic modules

- Serial gate 3: `Parser`
  - upstream: `Parser.zig`
  - write set: `src/terminal/parser*.mbt` and direct tests only
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
