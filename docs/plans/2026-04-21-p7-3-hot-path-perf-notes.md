# P7.3 Hot Path Perf Notes

## Goal

Measure the translated parser stack at the public `StreamTerminal` boundary for
the main hot-path classes that matter in the current scope, then record the
results and any obvious deviations or caveats.

## Upstream files

- `upstream/ghostty/src/terminal/stream.zig`
- `upstream/ghostty/src/terminal/stream_terminal.zig`
- `upstream/ghostty/src/terminal/c/terminal.zig`

## MoonBit target files

- `tools/stream_terminal_perf/moon.pkg`
- `tools/stream_terminal_perf/main.mbt`
- `docs/plan.md`
- `docs/plans/2026-04-21-p7-3-hot-path-perf-notes.md`

## Dependency notes

- `P7.2` finished the public-facade parity corpus, so the last open Phase 7
  task is measurement and documentation rather than new translation behavior.
- The benchmark package stays at the public host boundary. It does not reach
  into parser or bridge internals.

## Measurement method

Command:

- `moon run --release tools/stream_terminal_perf`

Configuration baked into the harness:

- 5 timed runs per case
- wall-clock timing via `@env.now()`
- all cases instantiate a fresh `StreamTerminal` per run

Measured hot-path cases:

- `printable_bulk`
  - one large `next_slice(Bytes)` containing only printable ASCII
- `split_escape`
  - repeated split `ESC` + continuation writes to stress persistent parser
    state across host writes
- `query_callbacks`
  - repeated DECRQM + DA1 + XTVERSION + ENQ + size-report queries with
    callback paths enabled and PTY writes sunk

## Results

Local release rerun on 2026-04-21 with
`moon run --release tools/stream_terminal_perf`:

| case | bytes per run | runs | min ms | avg ms | avg bytes/ms | approx MiB/s |
|---|---:|---:|---:|---:|---:|---:|
| `printable_bulk` | 294,912 | 5 | 5,682 | 5,766 | 51 | 0.05 |
| `split_escape` | 450,000 | 5 | 998 | 1,004 | 448 | 0.43 |
| `query_callbacks` | 380,000 | 5 | 25 | 26 | 14,615 | 13.94 |

## Interpretation

- `query_callbacks` is comfortably the cheapest measured class. It mostly
  exercises parser/query dispatch and callback encoding with almost no grid
  mutation.
- `split_escape` is materially slower than pure query traffic, which is
  expected because it repeatedly crosses the host write boundary and still
  performs printable cell updates.
- `printable_bulk` is the slowest case by a wide margin. This benchmark is not
  just parser decode; it continuously drives screen writes and scroll-region
  churn on a very small terminal model, so it is best read as a
  parser-plus-grid-mutation measurement rather than a pure parser throughput
  number.
- Normalizing by visible cells rather than raw input bytes makes the key
  result clearer: `printable_bulk` is about `51.1` visible chars/ms and
  `split_escape` is about `49.8` visible chars/ms, so escape parsing itself is
  not materially more expensive than plain printable traffic once both paths
  pay the same grid-mutation cost.

## Caveats

- The harness uses `@env.now()`, so timings have millisecond resolution and
  should be treated as coarse regression notes, not precise microbenchmarks.
- Absolute numbers are machine-dependent. The relative ordering between query,
  split-escape, and heavy printable-scroll traffic is the useful signal here.

## Validation commands

- `moon run --release tools/stream_terminal_perf`
- `moon fmt`
- `moon check`
- `moon test`
- `moon coverage analyze -p tonyfettes/ghostty/src/terminal`
- `moon info`

## Review findings

- The harness is intentionally small and reproducible; it is not a benchmark
  framework.
- No API changes are expected from this slice; `.mbti` should remain stable.
- The current terminal hot path is dominated by screen-grid mutation cost once
  workloads force repeated scroll/write churn.

## Commit scope

- `docs(perf): record stream terminal hot path notes`
