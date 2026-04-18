# Ghostty Parser Architecture

## Scope

This document covers the upstream Ghostty parser subsystem under
`upstream/ghostty`, limited to the files that define the VT parser pipeline and
its runtime integration:

- `src/terminal/Parser.zig`
- `src/terminal/parse_table.zig`
- `src/terminal/stream.zig`
- `src/terminal/stream_terminal.zig`
- `src/terminal/osc.zig`
- `src/terminal/dcs.zig`
- `src/terminal/sgr.zig`
- `src/terminal/UTF8Decoder.zig`
- `src/termio/Termio.zig`

The goal is a faithful MoonBit translation of the parser stack. This means
preserving module boundaries, state machines, ordered side effects, and the
data contracts between layers, not just reproducing the external behavior.

## Source Map

The parser is not one parser. Upstream splits it into four layers:

1. `Parser.zig`: byte-oriented DEC ANSI state machine.
2. `stream.zig`: bridge from parser actions to typed terminal actions.
3. `osc.zig`, `dcs.zig`, `sgr.zig`: sequence-specific semantic decoders.
4. `stream_terminal.zig` and `termio/Termio.zig`: action application and host
   integration.

`UTF8Decoder.zig` sits beside the VT parser. It is used only when the stream is
in ground state.

## End-to-End Data Flow

The live application path is:

1. `Termio.processOutputLocked(buf)` receives PTY bytes.
2. It schedules renderer work, handles cursor blink reset throttling, and then
   forwards bytes into `terminal_stream`.
3. In normal mode it calls `terminal_stream.nextSlice(buf)`.
4. In inspector mode it falls back to byte-at-a-time `terminal_stream.next(b)`.
5. `stream.zig` decides whether bytes stay on the UTF-8 fast path or must enter
   the VT control parser.
6. `Parser.next(byte)` emits up to three ordered actions for one byte:
   exit action, transition action, entry action.
7. `stream.zig` interprets those parser actions into `Stream.Action` values and
   immediately calls the handler's `vt` method.
8. A handler applies those actions either to a `Terminal` model
   (`stream_terminal.zig`) or to the full application runtime
   (`termio/stream_handler.zig`, instantiated by `Termio`).

The important architectural point is that Ghostty keeps these concerns
separate:

- byte classification and state transition
- escape-sequence semantic decoding
- terminal-state mutation
- host side effects such as mailbox messages, PTY writes, clipboard, and title
  updates

## Layer 1: DEC ANSI State Machine

### `terminal/Parser.zig`

`Parser` is a compact stateful machine modeled directly on
<https://vt100.net/emu/dec_ansi_parser>.

Its persistent fields are:

- `state: State`
- `intermediates[4]` plus `intermediates_idx`
- `params[24]`, `params_sep`, `params_idx`
- `param_acc` and `param_acc_idx`
- embedded `osc_parser: osc.Parser`

The state enum is the classic DEC-style split:

- `ground`
- `escape`
- `escape_intermediate`
- `csi_entry`, `csi_param`, `csi_intermediate`, `csi_ignore`
- `dcs_entry`, `dcs_param`, `dcs_intermediate`, `dcs_passthrough`, `dcs_ignore`
- `osc_string`
- `sos_pm_apc_string`

`Parser.Action` is the stable output contract of this layer. It does not know
about `Terminal`; it only emits structural events:

- `print`
- `execute`
- `esc_dispatch`
- `csi_dispatch`
- `osc_dispatch`
- `dcs_hook`, `dcs_put`, `dcs_unhook`
- `apc_start`, `apc_put`, `apc_end`

The critical function is `Parser.next(c: u8) -> [3]?Action`. For a single byte
it can emit:

1. an exit action from the old state
2. the transition action for the byte
3. an entry action for the new state

That ordering is semantically important. Examples:

- leaving `osc_string` runs `osc_parser.end(c)` and may emit `osc_dispatch`
- entering `dcs_passthrough` emits `dcs_hook`
- leaving `dcs_passthrough` emits `dcs_unhook`
- entering `sos_pm_apc_string` emits `apc_start`
- leaving `sos_pm_apc_string` emits `apc_end`

`Parser.doAction` is where the machine mutates temporary parse buffers:

- `collect` appends intermediate bytes
- `param` accumulates numeric parameters and records `;` vs `:`
- `osc_put` forwards bytes into `osc.Parser.next`
- `csi_dispatch` finalizes the current parameter list

Two invariants matter for translation:

- colon separators are represented explicitly in `params_sep`
- colon separators are rejected for non-`m` CSI finals

### `terminal/parse_table.zig`

`parse_table.zig` generates the full transition table at compile time. It is
not a lookup cache over handwritten logic; it is the logic.

Each table cell is:

- `state: State`
- `action: Parser.TransitionAction`

The generated table covers:

- global "anywhere" transitions for ESC, C1 controls, OSC, CSI, DCS, APC/SOS/PM
- per-state byte ranges
- state-specific transition actions like `collect`, `param`, `put`, `osc_put`

Ghostty keeps one deliberate grammar extension here: `csi_param` accepts `:`
because SGR supports colon-separated subparameters.

For a line-by-line MoonBit port, the table should remain data-driven. Replacing
it with a single large `switch` would erase one of the core structural choices
of the upstream code.

## Layer 2: Ground-State UTF-8 and Parser Bridging

### `terminal/UTF8Decoder.zig`

`UTF8Decoder` is a DFA decoder with replacement semantics and one nontrivial
API guarantee:

- `next(byte)` returns `{ ?u21, bool }`
- the boolean says whether the byte was consumed

On malformed UTF-8, the decoder can emit U+FFFD and request that the same byte
be retried. `stream.zig` depends on that behavior.

### `terminal/stream.zig`

`Stream(H)` is the core orchestration layer. It owns:

- `handler: H`
- `parser: Parser`
- `utf8decoder: UTF8Decoder`

`Stream.Action` is the semantic action surface of the parser subsystem. It is
much richer than `Parser.Action`: cursor movement, erase commands, modes,
attributes, title changes, color operations, DCS/APC passthrough events, and
more.

The important control-flow functions are:

- `nextSlice`
- `nextSliceCapped`
- `consumeAllEscapes`
- `consumeUntilGround`
- `next`
- `nextUtf8`
- `handleCodepoint`
- `nextNonUtf8`

The fast path in `nextSlice` is tightly structured:

1. finish any partial scalar UTF-8 decode
2. finish any in-progress control sequence until parser returns to `ground`
3. consume runs of back-to-back `ESC` sequences
4. while in `ground`, use SIMD UTF-8 decoding until a control byte appears
5. fall back to scalar handling only when needed

`nextNonUtf8` has two extra fast paths before calling `Parser.next`:

- `ESC [` jumps directly to `csi_entry`
- dense `csi_param` bytes update parser buffers without table lookup

Once `Parser.next` returns its three possible actions, `stream.zig` replays
them in order and maps them as follows:

- `print` -> handler `vt(.print, ...)`
- `execute` -> C0/C1 handling in `execute`
- `csi_dispatch` -> `csiDispatch`
- `esc_dispatch` -> `escDispatch`
- `osc_dispatch` -> `oscDispatch`
- DCS/APC lifecycle events -> direct handler calls

There is also an optional raw interception hook: if the handler defines
`vtRaw`, it can observe and suppress processed parser actions before
`stream.zig` decodes them further.

## Layer 3: Sequence-Specific Decoders

### CSI decoding in `stream.zig`

`Parser.Action.csi_dispatch` contains only:

- `intermediates`
- `params`
- `params_sep`
- `final`

`stream.zig` owns the real CSI semantics. `csiDispatch` is a large final-byte
dispatcher that:

- validates intermediate bytes and parameter count
- fills in VT defaults
- emits typed `Stream.Action` values
- delegates SGR payload interpretation to `sgr.Parser`

This is where sequences like cursor motion, margins, mode changes, reports,
title stack commands, tab control, and kitty keyboard controls become terminal
actions.

### `terminal/sgr.zig`

SGR is pulled out into its own parser instead of being inlined into the CSI
dispatcher.

`sgr.Parser` iterates over the finalized CSI parameter array using:

- `params`
- `params_sep`
- `idx`

Its `next()` method returns one typed `Attribute` at a time. It understands:

- empty SGR as `unset`
- classic numeric attributes
- underline style subparameters
- 8-color, bright-color, 256-color, and direct RGB color forms
- colon and semicolon variants for direct color and underline color

Unknown forms are not silently dropped. They return `.unknown` with both:

- the full original SGR parameter slice
- the unresolved remaining suffix

That is a fidelity detail worth keeping in MoonBit.

### `terminal/osc.zig`

OSC uses a dedicated parser because it is not parameter-array based.

`osc.Parser` contains:

- `state: State`
- fixed `buffer[2048]`
- optional `capture`
- optional allocator for oversized commands
- `command: Command`

The key design choice is that `state` is a prefix trie encoded as an enum, not
an integer accumulator. States include `@"0"`, `@"2"`, `@"52"`, `@"133"`,
`@"777"`, `@"5522"`, and similar bridging states.

`next(c)` advances through that prefix trie until it sees `;`, then starts
capturing trailing payload bytes either:

- in the fixed buffer
- in an allocating writer for large protocols like OSC 52 and kitty clipboard

`end(terminator_ch)` dispatches to specialized parsers under
`terminal/osc/parsers.zig` and returns a typed `osc.Command`.

`stream.zig.oscDispatch` then maps those commands into terminal actions such as:

- `window_title`
- `start_hyperlink` / `end_hyperlink`
- `report_pwd`
- `clipboard_contents`
- `mouse_shape`
- `color_operation`
- `semantic_prompt`

Important fidelity points:

- OSC title changes are validated as UTF-8 before being emitted
- response-capable OSC commands preserve which terminator was used

### `terminal/dcs.zig`

DCS is stateful and streaming, so Ghostty does not parse it as a single
captured blob.

`dcs.Handler` maintains a `state` union with modes for:

- inactive
- ignore
- tmux control mode
- XTGETTCAP
- DECRQSS

The parser interface matches the lifecycle from `Parser.zig`:

- `hook(dcs_metadata)`
- repeated `put(byte)`
- `unhook()`

Recognized hooks are selected from the `DCS` metadata:

- `ESC P 1000 p` -> tmux control mode
- `ESC P + q` -> XTGETTCAP
- `ESC P $ q` -> DECRQSS

This is an incremental protocol parser, not buffered DCS text parsing. The
MoonBit port should preserve that split.

### APC in the stream layer

APC itself is not in the requested file list, but the listed files expose its
shape clearly:

- `Parser.zig` emits `apc_start`, `apc_put`, `apc_end`
- `stream.zig` forwards those events
- `stream_terminal.zig` feeds them into `apc.Handler`

Architecturally, APC behaves like DCS passthrough rather than like OSC.

## Layer 4: Applying Actions to a Terminal

### `terminal/stream_terminal.zig`

`stream_terminal.zig` is the reference terminal-mutating handler. It instantiates
`stream.Stream(Handler)` and gives a concrete meaning to `Stream.Action`.

`Handler` owns:

- `terminal: *Terminal`
- optional `effects` callbacks
- `apc_handler`

Its main dispatch function is `vtFallible(action, value)`. That function
applies:

- print and movement actions to `Terminal`
- attribute changes to `Terminal.setAttribute`
- mode toggles to `setMode`
- OSC color actions to `colorOperation` / `kittyColorOperation`
- APC bytes to `apc_handler`
- query responses through effect callbacks such as `write_pty`

Notable boundaries:

- DCS actions are ignored here; this handler is the minimal terminal-state
  implementation
- query-style actions such as device attributes and size reports are routed
  through effect callbacks instead of mutating terminal state directly
- title updates go through `windowTitle`, which sets terminal title and then
  triggers `title_changed`

For translation work, `stream_terminal.zig` is the cleanest place to understand
the semantic meaning of each `Stream.Action`.

## Runtime Integration

### `termio/Termio.zig`

`Termio` owns the live parser instance as:

- `terminal_stream: StreamHandler.Stream`

That handler type is not `stream_terminal.Handler`; the application uses a
richer wrapper in `termio/stream_handler.zig` that combines terminal mutation
with mailbox, renderer, clipboard, DCS, APC, and PTY-response behavior.

Within the requested file set, the important integration points are:

- `init`: builds the `Terminal`, constructs the stream handler, and creates
  `terminal_stream` with `initAlloc`
- `processOutputLocked`: the input boundary from PTY bytes into the parser
- `changeConfig`: pushes runtime config changes into the handler
- `resetSynchronizedOutput`: shows that parser-controlled modes affect renderer
  scheduling outside the parser itself

`processOutputLocked` does more than feed bytes:

- queues a render before parsing
- rate-limits cursor blink reset notifications
- switches to byte-at-a-time parsing when the inspector is active
- otherwise uses `nextSlice` for throughput
- notifies the termio mailbox if handler actions queued work

So the production integration path is:

`Termio` -> `StreamHandler.Stream` -> `stream.zig` -> `Parser/OSC/DCS/SGR` ->
handler actions -> terminal state plus host side effects.

## Translation Constraints

A faithful MoonBit translation should preserve these properties:

- `Parser.next` must keep the three-slot ordered action contract.
- `parse_table` should stay generated or table-driven.
- UTF-8 decoding must keep the retry-on-error behavior.
- `stream.zig` should preserve the split between UTF-8 ground-state fast path
  and control-sequence parsing.
- CSI semantics should remain in `stream`, with SGR in its own parser.
- OSC should keep its explicit prefix-state machine plus fixed/allocating
  capture split.
- DCS should remain incremental with `hook` / `put` / `unhook`.
- terminal mutation should stay separate from host effects.
- `Termio` integration should continue to accept slices of bytes and feed the
  same layered parser pipeline.

## Suggested MoonBit Translation Units

For a line-by-line port, the closest structural match is:

- `terminal/parse_table.mbt`
- `terminal/parser.mbt`
- `terminal/utf8_decoder.mbt`
- `terminal/stream.mbt`
- `terminal/osc.mbt`
- `terminal/dcs.mbt`
- `terminal/sgr.mbt`
- `terminal/stream_terminal.mbt`
- `termio/termio_parser_bridge.mbt` or equivalent host integration module

The main rule is to preserve the upstream ownership boundaries. In Ghostty, the
parser stack is already factored into reusable layers. The MoonBit port should
translate those layers directly instead of collapsing them into one parser file.
