# P14.C: Package Surface Closeout

## Goal

Close the `upstream/ghostty/src/terminal/c/main.zig` translation without
creating a fake MoonBit aggregator module. The `src/terminal` package itself is
the public surface, so this task verifies that the finished owner APIs compose
coherently through package-level smoke tests.

## Upstream files

- `upstream/ghostty/src/terminal/c/main.zig`

## MoonBit targets

- `src/terminal/terminal_package_smoke_test.mbt`
- `docs/plan.md`

## Design

- Do not add a dedicated `main.mbt` or re-export shim.
- Use smoke tests to span the public package surface families that `main.zig`
  aggregated upstream:
  - build/runtime metadata
  - system hooks
  - terminal host surface
  - formatter/render/graphics owners
  - input helpers and encoders
- Treat `pkg.generated.mbti` review as the final export audit for this plan.

## Acceptance criteria

- package-level smoke tests prove the final `src/terminal` API works as one
  coherent surface
- no redundant MoonBit aggregator module is introduced
- stale phase statuses in `docs/plan.md` are corrected so the control plane
  matches the landed work

## Validation

- `moon check`
- `moon test`
- `moon coverage analyze`
- `moon fmt`
- `moon info`

## Audit notes

- The smoke suite intentionally uses only public package API. This keeps the
  closeout aligned with the role that `main.zig` served upstream: aggregate
  reachability, not private behavior.
- `src/terminal/pkg.generated.mbti` remains the definitive package export
  audit. No standalone aggregator module was added.
