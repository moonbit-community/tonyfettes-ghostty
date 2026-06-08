///|
/// Profiling entry point for the `scroll_full` workload. Run with:
///   moon run bench/scroll_full --release --target native --profile
fn main {
  @workloads.scroll_full().run_main()
}
