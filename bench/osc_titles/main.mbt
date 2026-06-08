///|
/// Profiling entry point for the `osc_titles` workload. Run with:
///   moon run bench/osc_titles --release --target native --profile
fn main {
  @workloads.osc_titles().run_main()
}
