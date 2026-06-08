///|
/// Profiling entry point for the `scroll_storm` workload. Run with:
///   moon run bench/scroll_storm --release --target native --profile
fn main {
  @workloads.scroll_storm().run_main()
}
