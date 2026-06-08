///|
/// Profiling entry point for the `colored_log` workload. Run with:
///   moon run bench/colored_log --release --target native --profile
fn main {
  @workloads.colored_log().run_main()
}
