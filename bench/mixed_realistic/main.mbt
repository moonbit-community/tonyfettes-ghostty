///|
/// Profiling entry point for the `mixed_realistic` workload. Run with:
///   moon run bench/mixed_realistic --release --target native --profile
fn main {
  @workloads.mixed_realistic().run_main()
}
