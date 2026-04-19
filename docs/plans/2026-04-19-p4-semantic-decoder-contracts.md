# P4.0 Semantic Decoder Contracts

## Goal

Record the exact semantic-decoder boundaries for Phase 4 so each worker slice
can land in a green state without reopening the parser-core work:

- P4.A: SGR
- P4.B: DCS
- P4.C: OSC high-frequency commands
- P4.D: OSC long-tail commands
- P4.E: APC helpers

## Upstream files

- `upstream/ghostty/src/terminal/sgr.zig`
- `upstream/ghostty/src/terminal/dcs.zig`
- `upstream/ghostty/src/terminal/osc.zig`
- `upstream/ghostty/src/terminal/osc/parsers.zig`
- `upstream/ghostty/src/terminal/osc/parsers/*.zig`
- `upstream/ghostty/src/terminal/apc.zig`
- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/stream_terminal.zig`

## MoonBit target files

- `docs/plans/2026-04-19-p4-semantic-decoder-contracts.md`
- `docs/plan.md`
- future worker targets:
  - `src/terminal/sgr.mbt`
  - `src/terminal/sgr_wbtest.mbt`
  - `src/terminal/dcs.mbt`
  - `src/terminal/dcs_wbtest.mbt`
  - `src/terminal/apc.mbt`
  - `src/terminal/apc_wbtest.mbt`
  - `src/terminal/osc.mbt`
  - `src/terminal/osc_wbtest.mbt`
  - additional flat helper files under `src/terminal/` as needed, without
    introducing new MoonBit packages

## Dependency notes

- Phase 4 starts after the Phase 3 parser state machine. Semantic decoders
  consume typed parser outputs; they must not change parser action ordering or
  the parse-table shape.
- Already-landed MoonBit dependencies:
  - `src/terminal/parser.mbt` for CSI separator semantics and raw DCS/APC/OSC
    action payloads
  - `src/terminal/color.mbt` for RGB, named colors, dynamic colors, and color
    target enums
  - `src/terminal/osc.mbt` as the current minimal OSC core that P4.C and P4.D
    will extend rather than replace
- Future stream integration depends on these decoders staying typed and narrow:
  - `stream` should consume `sgr.Attribute`, `dcs.Command`, `osc.Command`, and
    `apc.Command` rather than reparsing byte payloads

## Per-task contracts

### P4.A SGR

- Preserve the upstream typed SGR output surface:
  - `unset`
  - `unknown(full, partial)`
  - style toggles/resets
  - underline styles
  - 8-color, bright-color, 256-color, direct RGB color
  - underline-color forms and reset
- Separator bits are semantic input, not formatting trivia.
  - Colon-mode parsing is only valid for `4`, `38`, `48`, and `58`.
  - Unsupported colon-led runs must return `unknown` and consume the whole
    colon-connected slice before continuing.
- Direct-color fidelity rules:
  - semicolon form: `38;2;r;g;b`, `48;2;r;g;b`, `58;2;r;g;b`
  - colon form accepts optional colorspace: `38:2:Pi:r:g:b`
  - semicolon form does not skip an optional colorspace field
  - malformed or short forms degrade to `unknown`, not crashes
- Worker write set:
  - `src/terminal/sgr.mbt`
  - `src/terminal/sgr_wbtest.mbt`
  - `src/terminal/pkg.generated.mbti`
- Minimum test categories:
  - empty SGR and repeated `next()`
  - style toggles/resets
  - underline styles and trailing-colon regressions
  - 8-color / bright-color / 256-color
  - direct-color semicolon and colon forms
  - mixed valid and invalid runs, including Kakoune regressions

### P4.B DCS

- Preserve the handler lifecycle shape:
  - `hook(dcs) -> ?Command`
  - `put(byte) -> ?Command`
  - `unhook() -> ?Command`
- Preserve the state split:
  - inactive
  - ignore
  - XTGETTCAP accumulator
  - DECRQSS accumulator
  - tmux control-mode parser when enabled upstream
- The parser already emits raw `DcsHook`, `DcsPut`, and `DcsUnhook`; P4.B is
  where those become semantic commands.
- Initial command surface to preserve:
  - XTGETTCAP (`ESC P + q`)
  - DECRQSS (`ESC P $ q`)
  - tmux control mode (`ESC P 1000 p`) as an optional/guarded lane if the
    MoonBit port is not ready to carry the full tmux parser in the first cut
- Worker write set:
  - `src/terminal/dcs.mbt`
  - `src/terminal/dcs_wbtest.mbt`
  - `src/terminal/pkg.generated.mbti`
- Minimum test categories:
  - unknown DCS enters ignore and exits cleanly
  - XTGETTCAP basic, mixed-case, multiple keys, invalid data
  - DECRQSS valid and invalid requests
  - max-bytes / overflow handling
  - tmux enter/exit only if tmux support is included in the slice

### P4.C OSC high-frequency lane

- Extend the current `src/terminal/osc.mbt` core instead of replacing it.
- High-frequency lane stays on the commands already central to parser and
  stream behavior:
  - window title
  - window icon
  - hyperlink start/end
  - report pwd
  - color operations
  - semantic prompt
  - mouse shape
- Parser-core assumptions that must not change:
  - OSC dispatch still happens on parser exit from `OscString`
  - terminator (`BEL` vs `ST`) stays attached to commands that need to mirror
    responses
  - current prefix-state-machine behavior in `src/terminal/osc.mbt` remains the
    base, with functionality extended by typed subparsers rather than replaced
- Worker write set:
  - `src/terminal/osc.mbt`
  - `src/terminal/osc_wbtest.mbt`
  - helper files such as `src/terminal/osc_semantic_prompt.mbt` or
    `src/terminal/osc_hyperlink.mbt` only if needed for clarity
  - `src/terminal/pkg.generated.mbti`
- Minimum test categories:
  - current title/icon/pwd/mouse-shape coverage must stay green
  - hyperlink start/end parsing
  - semantic prompt command parsing
  - color operations, queries, resets, invalid bodies, terminator propagation
  - UTF-8 payload handling and fixed-buffer boundaries

### P4.D OSC long-tail lane

- Long-tail OSC stays separate so P4.C can finish green without dragging in
  every downstream protocol at once.
- Commands in this lane:
  - clipboard operations
  - kitty color protocol
  - kitty clipboard protocol
  - desktop notifications / ConEmu family
  - context signalling
  - kitty text sizing
  - other remaining `osc/parsers/*.zig` features not required by P4.C
- Hidden dependencies:
  - safe string / encoding helpers
  - more structured payload decoders than the current minimal core
  - eventual stream/terminal effect hooks, especially for clipboard and
    notifications
- Worker write set:
  - `src/terminal/osc.mbt`
  - `src/terminal/osc_wbtest.mbt`
  - one or more flat helper files under `src/terminal/`
  - `src/terminal/pkg.generated.mbti`
- Minimum test categories:
  - clipboard get/set forms
  - kitty color protocol set/reset/query forms
  - kitty clipboard protocol parsing
  - context signal payload parsing
  - text sizing protocol parsing
  - ConEmu / desktop-notification command parsing

### P4.E APC helpers

- Keep APC narrow in Phase 4.
- Preserve the APC handler lifecycle:
  - `start()`
  - `feed(byte)`
  - `end() -> ?Command`
- Preserve first-byte identification semantics:
  - unknown APC commands enter ignore
  - `G` selects kitty graphics parsing
- P4.E is not the place to port image storage/rendering. The scope here is the
  APC-facing command parser boundary needed by future stream integration.
- Worker write set:
  - `src/terminal/apc.mbt`
  - `src/terminal/apc_wbtest.mbt`
  - minimal kitty-graphics command-parse helper files only if required to keep
    `apc.mbt` faithful and green
  - `src/terminal/pkg.generated.mbti`
- Minimum test categories:
  - unknown APC command ignored
  - malformed kitty graphics APC returns no command
  - integer overflow cases return no command
  - valid kitty graphics command reaches typed APC command output

## Lane boundaries

- P4.A and P4.B can proceed independently after this gate.
- P4.C and P4.D share `src/terminal/osc.mbt`, so they are logically parallel
  but should not be implemented at the same time by different workers unless
  their write sets are first split into distinct helper files.
- P4.E stays independent of P4.B even though both are passthrough-derived,
  because APC semantics flow through `apc.zig`, not `dcs.zig`.
- Recommended execution order after P4.0:
  1. P4.A SGR
  2. P4.B DCS
  3. P4.C OSC high-frequency
  4. P4.E APC helpers
  5. P4.D OSC long-tail

This order keeps the most parser-adjacent and stream-blocking semantics in
front while leaving the broader OSC surface for later.

## Acceptance criteria

- Phase 4 decoder boundaries are explicit enough that each worker slice can
  land code, tests, and validation in one green commit.
- Hidden dependencies on parser-core, color types, and future stream/terminal
  integration are recorded before implementation begins.
- The split between OSC high-frequency and long-tail commands is clear and
  compatible with the existing MoonBit OSC core.

## Validation commands

- doc review against `docs/architecture.md`
- doc review against `docs/plan.md`
- source review against the listed upstream files

## Coverage findings for touched files

- Docs-only task; no MoonBit coverage run required for this step.

## Commit scope

- `docs`: add Phase 4 semantic decoder contracts

## Review findings

- Explorer review on SGR confirmed that separator bits are a first-class part
  of SGR semantics, that direct-color parsing must preserve the upstream
  colon-vs-semicolon rules, and that `unknown.full` / `unknown.partial` should
  be asserted directly in the MoonBit tests because copied slices are a likely
  drift point in this port.
- Main-agent review covered:
  - DCS hook/put/unhook state boundaries and command families
  - the OSC high-frequency vs long-tail split around the existing MoonBit OSC
    core
  - APC staying limited to the command-parser boundary rather than image
    execution/storage work

## Audit/result notes

- Recorded the worker write sets and test categories for P4.A through P4.E.
- Locked the recommended Phase 4 execution order so worker slices stay green
  and narrowly scoped.
- Kept the file layout flat under `src/terminal/`, matching the current
  package strategy.
