///|
/// Profiling entry point for the `cjk_text` workload. Run with:
///   moon run bench/cjk_text --release --target native --profile
fn main {
  @workloads.cjk_text().run_main()
}
