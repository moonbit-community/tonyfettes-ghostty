///|
test "build_info/version string includes prerelease and build metadata" {
  let version : BuildVersion = {
    major: 2U,
    minor: 0U,
    patch: 1U,
    pre: Some("beta.1"),
    build: Some("20260421"),
  }

  assert_eq(version.string(), "2.0.1-beta.1+20260421")
}
