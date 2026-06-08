// Statistical benchmarks (mean ± σ) for every workload, run with:
//   moon bench -p bench/workloads --release --target native
//
// Each measures `Workload::process` once per iteration — the same unit the
// `bench/<name>` main packages loop under `moon run --profile`, so the profiled
// code is exactly the code these statistics measure.

///|
test "bench plain_lines" (it : @bench.T) {
  let w = plain_lines()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench wrapped_blob" (it : @bench.T) {
  let w = wrapped_blob()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench scroll_storm" (it : @bench.T) {
  let w = scroll_storm()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench scroll_full" (it : @bench.T) {
  let w = scroll_full()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench colored_log" (it : @bench.T) {
  let w = colored_log()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench tui_redraw" (it : @bench.T) {
  let w = tui_redraw()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench cjk_text" (it : @bench.T) {
  let w = cjk_text()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench osc_titles" (it : @bench.T) {
  let w = osc_titles()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench sgr_storm" (it : @bench.T) {
  let w = sgr_storm()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench query_storm" (it : @bench.T) {
  let w = query_storm()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench mixed_realistic" (it : @bench.T) {
  let w = mixed_realistic()
  it.bench(fn() { it.keep(w.process()) })
}
