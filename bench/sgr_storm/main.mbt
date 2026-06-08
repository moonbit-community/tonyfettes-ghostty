///|
/// Profiling entry point for the `sgr_storm` workload. Run with:
///   moon run bench/sgr_storm --release --target native --profile
fn main {
  @workloads.sgr_storm().run_main()
}
