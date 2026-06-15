///|
/// Profiling entry point for the `color_storm` workload. Run with:
///   moon run bench/color_storm --release --target native --profile
fn main {
  @workloads.color_storm().run_main()
}
