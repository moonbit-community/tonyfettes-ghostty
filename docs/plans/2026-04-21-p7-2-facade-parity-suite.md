# P7.2 Facade Parity Suite

## Goal

Port the agreed host-boundary parity corpus from upstream
`upstream/ghostty/src/terminal/c/terminal.zig` onto the public MoonBit
`StreamTerminal` façade without widening the API.

## Upstream files

- `upstream/ghostty/src/terminal/c/terminal.zig`

## MoonBit target files

- `src/terminal/stream_terminal_parity_test.mbt`
- `docs/plan.md`

## Dependency notes

- `P7.1` established the public `StreamTerminal` owner, so the parity work in
  this slice stays entirely at the blackbox host boundary.
- The agreed parity corpus from `P7.0` is inline VT byte sequences and
  callback expectations from upstream C-terminal tests; no additional fixture
  file is needed for this first parity batch.

## Acceptance criteria

- The agreed upstream host-boundary cases are mirrored as blackbox MoonBit
  tests against `StreamTerminal`.
- The suite checks public behavior only: byte feeding, query replies, callback
  delivery, and title observation.
- No new public API surface is added for parity convenience.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze -p tonyfettes/ghostty/src/terminal`
- `moon info`

## Upstream parity mapping

Mirrored directly from `upstream/ghostty/src/terminal/c/terminal.zig`:

- `vt_write`
- `vt_write split escape sequence`
- `set write_pty callback`
- `set bell callback`
- `set enquiry callback`
- `set xtversion callback`
- `xtversion without callback reports default`
- `set title_changed callback`
- `set size callback`
- `set device_attributes callback primary`
- `set device_attributes callback secondary`
- `set device_attributes callback tertiary`
- `device_attributes without callback uses default`
- `get title set via vt_write`

Also covered in this slice because the public MoonBit callback shape expresses
it naturally:

- upstream `device_attributes callback returns false uses default`
  - mirrored as `device_attributes=fn() { None }`

## Coverage findings for touched files

- `src/terminal/stream_terminal_parity_test.mbt`
  - fully exercised by the test suite itself
- no product-code executable lines changed in this slice
- package-level uncovered-line residue is unchanged from `P7.1`:
  - `src/terminal/stream.mbt:222`
  - invariant-only internal branches already documented in
    `src/terminal/stream_terminal_bridge.mbt`

## Commit scope

- `test(parity): add stream terminal facade parity suite`

## Review findings

- The public API remained stable: `.mbti` should not change in this slice.
- The parity suite stays blackbox and uses only `StreamTerminal` plus existing
  public snapshot/query types.
- The suite mirrors upstream host-boundary behavior directly instead of
  folding everything into a smaller number of composite regression tests.

## Audit/result notes after implementation

- Added a dedicated public-facade parity suite that tracks the first agreed
  upstream `c/terminal.zig` host corpus one test at a time.
- Kept the earlier `stream_terminal_test.mbt` coverage-oriented blackbox tests
  intact; this parity suite complements them with clearer upstream alignment.
