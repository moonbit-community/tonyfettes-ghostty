# Remove Src Package Prefix

## Goal

Hard-migrate the public terminal package from
`tonyfettes/ghostty/src/terminal` to `tonyfettes/ghostty/terminal` before the
first release, removing the extra `src` layer from the published package path.

## Accepted Design

- Move the MoonBit terminal package directory from `src/terminal` to
  `terminal`.
- Do not keep a compatibility shim at `src/terminal`; this is a hard migration.
- Update repository-local imports and README examples to use
  `tonyfettes/ghostty/terminal`.
- Update local generator scripts so generated terminal data still lands in the
  moved package.
- Update current package-layout documentation. Historical plan files may retain
  upstream `src/terminal/...` references when they describe Ghostty upstream
  source paths or past implementation history.

## Target Files and Surfaces

- `terminal/**`
- `src/terminal/**` removal
- root `README.md`
- examples and tools `moon.pkg` imports
- generator scripts under `tools/`
- current docs: `README.md`, `docs/plan.md`; `docs/architecture.md` was
  inspected and left unchanged because its remaining `src/terminal/*.zig`
  references describe upstream Ghostty source files.

## API / Interface Diff

```text
- tonyfettes/ghostty/src/terminal
+ tonyfettes/ghostty/terminal
```

The terminal package public types and functions should otherwise remain the
same after `moon info`.

## Open Questions

- None. The user requested a direct hard migration.

## Next Implementation Step

Move the package directory, update imports and target paths, regenerate package
interfaces, and validate both the root module and examples module.

## Validation Plan

- `moon check --target native`
- `moon test --target native`
- `moon check --target js`
- `moon test --target js`
- `moon coverage analyze -p tonyfettes/ghostty/terminal -- -f summary`
- `moon fmt`
- `moon info`
- `moon -C examples check --target native`
- `moon -C examples check --target js`
- `moon -C examples test --target native`
- `moon -C examples test --target js`
- `moon -C examples fmt`
- `moon -C examples info`

## Validation Results

- `moon check --target native`: passed.
- `moon check --target js`: passed.
- `moon test --target native`: 517/517 passed.
- `moon test --target js`: 539/539 passed.
- `moon coverage analyze -p tonyfettes/ghostty/terminal -- -f summary`: passed,
  reporting `9866/10231` covered lines for the moved terminal package.
- `moon fmt`: passed.
- `moon info`: passed and regenerated `terminal/pkg.generated.mbti` with
  `package "tonyfettes/ghostty/terminal"`.
- `moon -C examples check --target native`: passed.
- `moon -C examples check --target js`: passed.
- `moon -C examples test --target native`: 517/517 passed.
- `moon -C examples test --target js`: 539/539 passed.
- `moon -C examples fmt`: passed.
- `moon -C examples info`: passed.
