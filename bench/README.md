# bench

StreamTerminal benchmarks, as a separate workspace module
(`tonyfettes/ghostty-bench`). Each workload is defined once in the shared
`workloads/` package and exposed two ways:

## Statistics — `moon bench`

Runs every workload through the `@bench.T` framework and reports
`mean ± σ` with auto-tuned iteration counts:

```sh
moon bench -p bench/workloads --release --target native
```

Use this to A/B a change: run it, switch the code under test, run it again, and
compare. Keep a workload that your change does not touch (e.g. `plain_lines`) as
a drift control.

## Profiling — `moon run bench/<name> --profile`

Each workload also has its own `main` package that loops the workload long
enough (~1–2 s) for the Time Profiler (macOS) / perf (Linux) to sample it:

```sh
moon run bench/sgr_storm --release --target native --profile
```

This prints self / inclusive / leaf cost tables and writes a JSON report plus an
Instruments trace under `_build/.../profile/`. The looped unit is exactly the
unit `moon bench` measures (`Workload::process`), so the profile reflects the
benchmarked code.

Available workloads: `plain_lines`, `wrapped_blob`, `scroll_storm`,
`scroll_full`, `colored_log`, `tui_redraw`, `cjk_text`, `osc_titles`,
`mixed_realistic`, `sgr_storm`, `query_storm`.
