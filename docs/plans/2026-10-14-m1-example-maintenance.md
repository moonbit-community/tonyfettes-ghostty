# M1 examples and benchmark compatibility subplan

## Goal and ownership

Maintain existing `examples/**` and `bench/**` host adapters and tests under
M1 of `2026-10-14-m1-toolchain-maintenance.md`, without architecture or API
changes. Module manifests remain owned by the integrator.

## Source mapping and dependencies

Upstream integration boundaries are `src/termio/Termio.zig`
(`processOutputLocked`), `src/termio/stream_handler.zig`, and
`src/terminal/stream_terminal.zig` (`Handler.vtFallible`). Existing adapters
are documented by P15 terminal playground and P16 Rabbita asciinema plans.
Native tmux retains existing Pane lifecycle and process ownership.

Dependency API mapping: Rabbita `Dispatch` to `Emit`,
`cell_with_dispatch` to `cell_with_emit`, void `html.input` no children;
PTY `Pty::spawn` to its `spawn` free-function alias. Existing test references
are explicitly package-qualified. Existing playground JSON byte conversion
uses the current `Json` constructor. No new helper types/functions are added.

Use the minimally compatible Rabbita 0.12.4 and PTY 0.2.3: both have current
`moon.mod` manifests while preserving existing component and PTY lifecycle.
Rabbita 0.16.4 and PTY 0.4.3 were inspected but would require unrelated model
and lifecycle migrations, so are excluded from this warning/format task.

## Acceptance and validation

- No owned compiler warnings/errors with `moon check --target all`.
- Targeted JS player, wasm-gc playground, native tmux, and benchmark tests.
- Run `moon coverage analyze` and audit touched executable lines.
- Run `moon fmt` and `moon info`; review owned `.mbti` changes.
- Preserve public interfaces and behavior; no new FFI or suppressions.

## Audit and results

- `moon check --target all --output-json`: zero diagnostics in owned examples
  and bench paths; remaining 1,169 library warnings are the parallel core lane.
- `moon test examples/rabbita_asciinema/main --target js`: 22/22 passed.
- `moon test examples/terminal_playground/core --target wasm-gc`: 6/6 passed.
- `moon test examples/tmux --target native` and `moon test bench/workloads
  --target all`: no ordinary test entry (workloads contains benchmark cases).
  `moon bench -p tonyfettes/ghostty-bench/workloads --target native --build-only`
  compiled all benchmark cases. `moon build examples/tmux --target native`
  passed and the generated executable's `--help` succeeded.
- `moon build examples/rabbita_asciinema/main --target js` passed.
- `moon coverage analyze -p
  tonyfettes/ghostty-examples/terminal_playground/core -- -f summary`: 422/444
  points. Additional `moon test examples/rabbita_asciinema/main --target js
  --enable-coverage` and `moon coverage report` collected JS coverage: player
  main 211/228 points, adapter 230/234, package 509/530.
- Reviewed coveralls line counts: both changed playground executable lines
  583 and 604 are covered (3 and 1 hits). Void input rendering is covered by
  the existing styled HTML/player controls tests. Emit type aliases do not
  create executable coverage points.
- Accepted gaps for integrator review: changed player startup call
  `cell_with_emit` at main.mbt:573 runs only in DOM-mounted `main`, so it is
  built but not run in the existing headless unit tests. Native tmux's renamed
  `spawn` call at main.mbt:608 has no test entry and was not executed against an
  interactive shell; source and dependency interface confirm it is the exact
  free-function alias of the original constructor and leaves lifecycle intact.
  Benchmark changes only qualify the same calls; all benchmark cases compile,
  but workloads were not timed for this mechanical change. No tests were
  weakened or new coverage exclusions introduced.
- Other uncovered lines in the two touched production files are pre-existing
  paths: player main 48,175,281,396,574,579-581 (empty-cast fallback, DOM file
  loading, seek/play state and mount); playground
  431,451-452,462-463,478-479,481,493,504-507,543,605,613,632,688,697-698,710
  (nullable metadata/color/image branches). No behavior edits affect them.
- `moon fmt examples bench`, `moon fmt examples bench --check`, and
  `moon info` passed. Generated interface changes in owned paths only remove
  a redundant blank line, with no public item changes. Player and tmux remain
  private executable models; playground exports retain their documented P15
  consumer story; no new public mutable fields or unjustified public surface
  introduced in the touched area.
- One intermediate check reported a missing `sgr` import at
  ghostty_terminal_wbtest.mbt:138 after moving unused production imports.
  Resolved within scope by retaining it as a white-box-test-only import.
  Subsequent checks/tests passed.

## Integration review

Main's unqualified `moon fmt` subsequently formatted every workspace package;
the worker's path selectors had selected only the named root packages. A
second read-only review confirmed that the extra diffs are only Int/UInt
canonical spelling, default-parameter spelling, trailing commas and layout.
Final `moon fmt --check`, strict all-target check, and full workspace tests pass.
Current modified executable line numbers are playground 587 and 608 (3 and 1
coverage hits), player startup 570, and tmux spawn 608.

Main reviewer accepts the documented DOM mount and interactive PTY coverage
gaps: these calls are verified compatible aliases, builds pass, and no
lifecycle/behavior change is introduced. The pre-existing nullable and
interaction branches above remain accepted for this mechanical task.
