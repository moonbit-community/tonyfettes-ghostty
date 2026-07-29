///|
/// Profiling entry point for the `kitty_apc_long` workload. Run with:
///   moon run bench/kitty_apc_long --release --target native --profile
fn main {
  @workloads.kitty_apc_long().run_main()
}
