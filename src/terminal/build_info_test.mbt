///|
test "build_info/current snapshot matches translated module metadata" {
  let info = build_info()
  assert_eq(info.simd(), false)
  assert_eq(info.kitty_graphics(), true)
  assert_eq(info.tmux_control_mode(), false)
  let version = info.version()
  assert_eq(version.major(), 0U)
  assert_eq(version.minor(), 1U)
  assert_eq(version.patch(), 0U)
  guard version.pre() == None else { fail("expected no prerelease segment") }
  guard version.build() == None else {
    fail("expected no build metadata segment")
  }
  assert_eq(version.string(), "0.1.0")
  assert_eq(info.version_string(), "0.1.0")
}

///|
test "build_info/optimize mode stays within supported moonbit variants" {
  let optimize = build_info().optimize()
  guard optimize == OptimizeMode::Debug || optimize == OptimizeMode::ReleaseSafe else {
    fail("unexpected optimize mode projection")
  }
}

///|
test "build_info/current snapshot is stable across calls" {
  guard build_info() == build_info() else {
    fail("expected build info snapshot to be stable")
  }
}
