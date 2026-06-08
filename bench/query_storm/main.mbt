///|
/// Profiling entry point for the `query_storm` workload. Run with:
///   moon run bench/query_storm --release --target native --profile
fn main {
  @workloads.query_storm().run_main()
}
