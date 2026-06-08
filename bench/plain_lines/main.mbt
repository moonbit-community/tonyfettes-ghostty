///|
/// Profiling entry point for the `plain_lines` workload. Run with:
///   moon run bench/plain_lines --release --target native --profile
fn main {
  @workloads.plain_lines().run_main()
}
