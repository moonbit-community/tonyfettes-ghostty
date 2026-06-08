///|
/// Profiling entry point for the `tui_redraw` workload. Run with:
///   moon run bench/tui_redraw --release --target native --profile
fn main {
  @workloads.tui_redraw().run_main()
}
