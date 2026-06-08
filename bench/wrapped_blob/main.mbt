///|
/// Profiling entry point for the `wrapped_blob` workload. Run with:
///   moon run bench/wrapped_blob --release --target native --profile
fn main {
  @workloads.wrapped_blob().run_main()
}
