# P9.A Result And Build Info Surface

## Goal

Translate `src/terminal/c/result.zig` and `src/terminal/c/build_info.zig`
into a MoonBit-aligned owner surface that keeps the upstream result code set,
but adapts the enum-keyed C getter to a typed build-info snapshot API.

## Upstream files

- `upstream/ghostty/src/terminal/c/result.zig`
- `upstream/ghostty/src/terminal/c/build_info.zig`
- `upstream/ghostty/src/terminal/build_options.zig`

## MoonBit target files

- `src/terminal/terminal_result_code.mbt`
- `src/terminal/terminal_result_code_test.mbt`
- `src/terminal/build_info.mbt`
- `src/terminal/build_info_optimize_debug.mbt`
- `src/terminal/build_info_optimize_release.mbt`
- `src/terminal/build_info_test.mbt`
- `src/terminal/build_info_debug_test.mbt`
- `src/terminal/build_info_release_test.mbt`
- `src/terminal/build_info_wbtest.mbt`
- `src/terminal/moon.pkg`
- `src/terminal/pkg.generated.mbti`
- `docs/plan.md`
- `docs/plans/2026-04-21-p9-a-result-and-build-info.md`

## Dependency notes

- `result.zig` is a shared status-code foundation for later wrapper work, so
  the MoonBit surface keeps the same five outcome cases as a dedicated enum.
- `build_info.zig` uses C output pointers and enum-keyed dispatch only for ABI
  ergonomics. In MoonBit that becomes a typed `BuildInfo` snapshot with opaque
  accessor methods.
- Upstream Zig exposes four optimize modes. MoonBit only exposes debug vs
  release file targeting here, so the translation keeps the four-case enum but
  currently projects release builds to `ReleaseSafe`.
- This repo has no build-option injection path analogous to Zig
  `terminal_options`, so the current metadata values are fixed module-level
  constants tied to `moon.mod.json` and the translated feature surface.
- `kitty_graphics`, `tmux_control_mode`, and `simd` are intentionally `false`
  in this slice because those translated host-surface capabilities are not yet
  implemented in the current MoonBit package.

## Acceptance criteria

- A public result-code enum exists with the same upstream cases and integer
  code mapping.
- A typed `BuildInfo` surface exists with feature flags, optimize mode, and
  version accessors.
- Debug and release builds select optimize mode through MoonBit file targets,
  not a hardcoded runtime value.
- Blackbox tests cover the result-code mapping, build-info snapshot fields, and
  both optimize-mode selections.

## Validation commands

- `moon fmt`
- `moon check`
- `moon test`
- `moon test --release src/terminal/build_info_release_test.mbt`
- `moon coverage analyze`
- `moon info`

## Coverage findings for touched files

- `src/terminal/terminal_result_code.mbt` is fully covered by
  `src/terminal/terminal_result_code_test.mbt`.
- `src/terminal/build_info.mbt` is fully covered by the added blackbox tests
  plus `src/terminal/build_info_wbtest.mbt` for the internal prerelease/build
  string branches.
- `src/terminal/build_info_optimize_debug.mbt` is covered by the debug-targeted
  test file under the default `moon test` run.
- `src/terminal/build_info_optimize_release.mbt` is not part of the default
  debug-only `moon coverage analyze` report because it is release-targeted; it
  is validated separately with `moon test --release src/terminal/build_info_release_test.mbt`.
- The pre-existing uncovered parser branch at `src/terminal/stream.mbt:222`
  remains outside the touched surface.

## Commit scope

- `feat(c-surface-foundation): add result and build info surface`

## Review findings

- The typed `BuildInfo` snapshot is the right MoonBit adaptation: the upstream
  enum-keyed `get(data, out)` API exists only because the C wrapper must speak
  through output pointers.
- `TerminalResultCode` is justified public surface because later `src/terminal/c`
  translations still need explicit non-exceptional outcome vocabulary.
- `BuildInfo` and `BuildVersion` stay opaque. Callers can observe metadata, but
  they cannot mutate it or construct inconsistent snapshots.
- The package-local whitebox test is justified here because it covers internal
  version-string formatting branches without widening the public API with a
  constructor that external callers do not need.
- Release builds currently map to `OptimizeMode::ReleaseSafe` because MoonBit
  does not expose the finer Zig `ReleaseSmall` / `ReleaseFast` split. This is a
  deliberate conservative projection, not an accidental omission.

## Audit/result notes after implementation

- Added `TerminalResultCode` plus `TerminalResultCode::code` and
  `terminal_result_code_from_int`.
- Added typed `BuildInfo` / `BuildVersion` surfaces and `build_info()`.
- Wired optimize-mode selection through MoonBit debug/release file targets.
- Kept the current translated feature flags conservative:
  - `simd = false`
  - `kitty_graphics = false`
  - `tmux_control_mode = false`
- Kept module version metadata aligned with the current `moon.mod.json`
  version `0.1.0`.
