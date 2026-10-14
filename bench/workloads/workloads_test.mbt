// Statistical benchmarks (mean ± σ) for every workload, run with:
//   moon bench -p bench/workloads --release --target native
//
// Each measures `Workload::process` once per iteration — the same unit the
// `bench/<name>` main packages loop under `moon run --profile`, so the profiled
// code is exactly the code these statistics measure.

///|
test "bench plain_lines" (it : @bench.T) {
  let w = @workloads.plain_lines()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench wrapped_blob" (it : @bench.T) {
  let w = @workloads.wrapped_blob()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench scroll_storm" (it : @bench.T) {
  let w = @workloads.scroll_storm()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench scroll_full" (it : @bench.T) {
  let w = @workloads.scroll_full()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench colored_log" (it : @bench.T) {
  let w = @workloads.colored_log()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench tui_redraw" (it : @bench.T) {
  let w = @workloads.tui_redraw()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench cjk_text" (it : @bench.T) {
  let w = @workloads.cjk_text()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench osc_titles" (it : @bench.T) {
  let w = @workloads.osc_titles()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench color_storm" (it : @bench.T) {
  let w = @workloads.color_storm()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench sgr_storm" (it : @bench.T) {
  let w = @workloads.sgr_storm()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench query_storm" (it : @bench.T) {
  let w = @workloads.query_storm()
  it.bench(fn() { it.keep(w.process()) })
}

///|
test "bench mixed_realistic" (it : @bench.T) {
  let w = @workloads.mixed_realistic()
  it.bench(fn() { it.keep(w.process()) })
}
