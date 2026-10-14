# P4.E.1 APC State Value Enum

## Goal

Measure whether representing the private APC handler state as a MoonBit value
enum improves long Kitty graphics APC processing while preserving the upstream
handler lifecycle and all observable `StreamTerminal` behavior.

## Upstream files and symbols

- `upstream/ghostty/src/terminal/apc.zig`
  - `Handler.state`
  - `State`
  - `Handler.start`
  - `Handler.feed`
  - `Handler.end`

Upstream stores `State` directly in `Handler`, switches on that union in
`feed`, and feeds the active Kitty parser in place. The MoonBit change must
preserve the same `inactive -> identify -> kitty/ignore -> inactive` lifecycle,
first-byte identification, byte ordering, and command completion behavior.

## MoonBit targets

- `terminal/apc.mbt`
- `bench/README.md`
- `bench/workloads/workloads.mbt`
- `bench/workloads/workloads_test.mbt`
- `bench/kitty_apc_long/main.mbt`
- `bench/kitty_apc_long/moon.pkg`
- generated benchmark `.mbti` files changed by `moon info`
- `docs/plan.md`
- this subplan

## Dependencies and boundaries

- The installed compiler must accept a `#valtype` enum whose `Kitty` variant
  carries the reference-typed `KittyGraphicsParser`.
- `ApcState`, `KittyGraphicsParser`, and `ApcHandler` remain private.
- Only `ApcState` receives `#valtype`; the parser, handler methods, command
  model, and state transitions are unchanged.
- The benchmark uses only the public `StreamTerminal` boundary. It must not
  expose or inspect private APC state.
- The benchmark feeds one complete, valid, long direct-medium Kitty graphics
  query so the measurement includes stream parsing, every APC body byte,
  command completion, and terminal application.

## Benchmark method

- Workload name: `kitty_apc_long`.
- Payload: one `ESC _ G ... ESC \` query for a 128 by 128 RGB image, with
  65,536 base64 bytes decoding to 49,152 bytes.
- The profiling main runs 500 iterations, about one second at the measured
  variant rate, matching the benchmark README's sampling-duration convention.
- Statistical command:
  `moon bench -p bench/workloads -f workloads_test.mbt -i 11 --release
  --target native --no-parallelize`.
- Run the selected workload three times before and three times after adding
  `#valtype`.
- Keep the payload, compiler, release mode, target, and benchmark command
  identical between baseline and variant.
- Inspect the generated native C for the benchmark executable to confirm the
  `ApcState` layout rather than inferring it from the source annotation.

## Acceptance criteria

- `ApcState` is an inline value enum in the generated native benchmark C.
- Existing APC lifecycle and Kitty graphics behavior remain unchanged on every
  supported backend.
- The long APC workload reaches a complete command through `StreamTerminal`.
- Three baseline and three variant benchmark samples are recorded below.
- Coverage for touched executable MoonBit lines is reviewed.
- `moon info` shows no terminal-package public API change; the only expected
  interface addition is the benchmark workload entry point.

## Validation commands

- `moon check --target all`
- targeted `terminal/apc_wbtest.mbt` runs for every supported target
- `moon test`
- `moon coverage analyze`
- `moon coverage analyze -- -f caret -F terminal/apc.mbt`
- review the `bench/workloads/workloads.mbt` findings in the full coverage
  output, because normal tests do not execute `@bench` blocks
- `moon fmt`
- `moon info`
- `git diff -- '*.mbti'`

## Results

### Baseline

The unannotated state produced these three native release means:

| run | mean | sigma |
|---|---:|---:|
| 1 | 2.17 ms | 11.91 us |
| 2 | 2.18 ms | 16.00 us |
| 3 | 2.19 ms | 18.20 us |

The simple mean of the three run means is 2.180 ms.

The generated profiling-main C stored `ApcHandler.state` as `void*`. Its Kitty
body arm allocated a new `ApcState.Kitty` object with `moonbit_malloc` after
every `parser.bytes.push(byte)`.

### `#valtype` variant

The annotated state produced these three native release means:

| run | mean | sigma |
|---|---:|---:|
| 1 | 2.05 ms | 18.89 us |
| 2 | 1.99 ms | 16.97 us |
| 3 | 2.01 ms | 12.52 us |

The simple mean of the three run means is 2.017 ms: 7.5% less mean time than
the baseline, or approximately 8.1% more throughput.

The generated statistical-benchmark C stores an inline
`struct ApcState { tag; union payload; }` directly in `ApcHandler`. The Kitty
body arm no longer calls `moonbit_malloc` for the outer state. It still performs
the compiler's managed value-enum retain/release operations and the existing
parser byte-array push; those are required to preserve reference ownership and
buffer behavior.

## Coverage and API audit

- `moon check --target all`: passed for wasm, wasm-gc, JavaScript, and native.
- `moon test terminal/apc_wbtest.mbt --target all`: 7/7 passed on each of wasm,
  wasm-gc, JavaScript, and native.
- `moon test`: 660 passed, 0 failed.
- `moon coverage analyze`: completed with the repository's existing 296
  uncovered lines across 38 files.
- A caret report for `terminal/apc.mbt` was empty: no executable line in that
  file is uncovered.
- Normal coverage does not execute `@bench` blocks. The new workload builder
  and profiling `main` therefore appear uncovered for the same reason as every
  existing file under `bench/`; they were exercised by one full
  `StreamTerminal` smoke run and all six recorded benchmark runs.
- `moon fmt`: passed.
- `moon info`: passed. No terminal-package `.mbti` changed. The benchmark module
  adds only `pub fn kitty_apc_long() -> Workload`, and the new executable has
  an empty public interface.

## Audit notes

- The source change maps directly to upstream `State` and `Handler.state`; no
  adapter, helper type, or lifecycle change was introduced.
- `ApcState`, its reference payload, and its owning handler remain private.
- The benchmark crosses the same public `StreamTerminal::next_slice` boundary
  as the other workloads and does not inspect private APC state.
- The profiling main uses 500 iterations; its release-native smoke completed
  with `payload_bytes=65574` and `checksum=0`.
- Native layout evidence and all three-run means support keeping the
  annotation.
- Native release builds emit the pre-existing Warning 0073 at
  `terminal/build_info_optimize_release.mbt:3` for the unnecessary
  `OptimizeMode::ReleaseSafe` qualification. That untouched file is outside
  this task's write set; the warning is recorded here and was not suppressed or
  fixed.
