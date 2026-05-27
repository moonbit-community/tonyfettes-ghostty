# Tun POC Ghostty Sync Checkpoint

## Goal

Sync the standalone Ghostty MoonBit translation with the newer
`tun-poc/vendor/ghostty` warning-cleanup changes without mirroring vendor-only
omissions or deleting standalone demo/tooling files.

## Accepted design

- Apply the `tun-poc` commits `a4eb3764 fix(ghostty): address MoonBit warnings`
  and `84d7a736 chore(release): bump versions for 0.3.2`, remapped from
  `vendor/ghostty/` to the standalone repository root.
- Preserve standalone-only files and directories, including `demo/`, `.github/`,
  `upstream/ghostty`, `tools/terminal_playground_core`, and
  `tools/gen_x11_color_data.py`.
- Do not import vendor-only documentation notes that mark standalone demos as
  omitted.

## Target files and surfaces

- Module metadata: add `moon.mod`, remove legacy `moon.mod.json`.
- Terminal package sources and tests under `src/terminal/`.
- `src/terminal/moon.pkg` and `src/terminal/pkg.generated.mbti`.
- `tools/stream_terminal_perf/main.mbt` and
  `tools/stream_terminal_perf/moon.pkg`.

## API/interface diff

- No new public types, helpers, or fields are intended.
- Expected generated interface change is limited to current MoonBit syntax for
  `StreamHandler` trait methods: `fn vt` and `fn deinit`.

## Open questions

- None. The existing modified `upstream/ghostty` submodule pointer is unrelated
  and will be left untouched.

## Next implementation step

Apply the two focused `tun-poc/vendor/ghostty` patches with path remapping,
review the resulting diff, then run validation.

## Validation plan

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`
- Review touched coverage output and `.mbti` churn before handoff.

## Validation results

- `moon check` passed with existing standalone-only deprecation warnings in
  `tools/terminal_playground_core` and `demo/rabbita_asciinema`.
- `moon test` passed: 517 wasm-gc tests and 22 js tests.
- Initial `moon coverage analyze` failed because stale `_build` coverage
  metadata referenced removed `src/terminal/grid_ref.mbt`; after `moon clean`
  and rerunning `moon test`, `moon coverage analyze` passed.
- `moon coverage analyze -- -f summary` reported total coverage `10802/11261`.
- Global `moon fmt` migrated `demo/rabbita_asciinema/moon.mod.json` to an
  invalid `moon.mod` for its local path dependency; that out-of-scope formatter
  side effect was reverted, then `moon fmt src/terminal tools/stream_terminal_perf`
  and `moon fmt moon.mod` reported no work.
- `moon info` passed with the same standalone-only deprecation warnings.

## Coverage audit

Touched files with uncovered executable lines:

- `src/terminal/formatter.mbt`: `647/718`. The uncovered paths are existing
  formatter framebuffer/selection/edge-case branches; this sync only replaces
  deprecated buffer construction syntax in existing code paths.
- `src/terminal/key_encoder.mbt`: `469/508`, and
  `src/terminal/key_encoder_function_keys.mbt`: `231/270`. The uncovered paths
  are existing key-encoding edge cases; this sync only replaces deprecated buffer
  construction syntax.
- `src/terminal/stream.mbt`: `675/677`. The touched change is interface syntax
  for the existing `StreamHandler` trait.
- `src/terminal/stream_terminal.mbt`: `211/228`, and
  `src/terminal/stream_terminal_bridge.mbt`: `1422/1474`. The uncovered paths
  are existing terminal bridge query/edge branches; this sync only replaces
  deprecated buffer construction syntax.
- `tools/stream_terminal_perf/main.mbt`: `0/52`. This is an executable benchmark
  tool with no package tests; the touched change is the buffer constructor and
  package import cleanup.

Touched files not listed by the coverage summary were either fully covered,
test-only, package metadata, or generated interface files. No new behavior or
new uncovered semantic branch is introduced by this sync.

## Interface audit

- `src/terminal/pkg.generated.mbti` changes only the `StreamHandler` trait
  method syntax to include `fn`.
- No new public type, function, field, or mutable field is introduced.
