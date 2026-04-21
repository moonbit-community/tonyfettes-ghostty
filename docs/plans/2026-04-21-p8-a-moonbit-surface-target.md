# P8.A MoonBit Surface Target Policy

## Goal

Lock the implementation target for the `src/terminal/c` translation to pure
MoonBit semantic parity, so later phases do not accidentally preserve C ABI
mechanics that are no longer part of scope.

## Upstream files

- the full `upstream/ghostty/src/terminal/c/*.zig` surface, with special
  attention to:
  - `allocator.zig`
  - `main.zig`
  - `terminal.zig`
  - `formatter.zig`
  - `render.zig`
  - `types.zig`

## MoonBit target files

- `docs/plan.md`
- `docs/plans/2026-04-21-p8-0-terminal-c-surface-control-plane.md`
- `docs/plans/2026-04-21-p8-a-moonbit-surface-target.md`

## Dependency notes

- `P8.0` fixed the denominator and file map first. This task fixes how that
  denominator is translated.
- The parser-stack foundation is already translated in pure MoonBit, so the
  remaining `src/terminal/c` work should stay on top of that implementation
  rather than inventing a second ABI-shaped layer.

## Acceptance criteria

- The plan states unambiguously that the target is pure MoonBit semantic
  parity for the full `src/terminal/c` surface.
- C-only ownership/export helpers are either:
  - absorbed into MoonBit semantics, or
  - explicitly declared out of scope,
  rather than carried forward as accidental implementation requirements.
- Later phases have concrete translation rules for handles, callbacks,
  result/error signaling, and aggregate wrapper modules.

## Validation

- doc review only

## Commit scope

- `docs`

## Review findings

- The biggest planning risk was conflating `src/terminal/c` semantic parity
  with C ABI parity. They are not the same denominator, and forcing ABI-shaped
  wrappers into the plan would create work that the user explicitly does not
  want.
- `allocator.zig` is the clearest example: it exists to let C callers free
  buffers returned by exported functions, not to define terminal behavior.

## Audit/result notes

The translation policy for Phases `P9` through `P14` is:

- Stay in the existing `src/terminal` package.
- Use `c_*.mbt` filenames only as source-organization markers, not as package
  boundaries.
- Preserve upstream wrapper layering and operation families where they encode
  real behavior:
  - `new/free/reset`
  - `get/get_multi/set`
  - iterators and query objects
  - callback-driven host effects
- Preserve upstream result semantics where they matter to behavior review:
  - keep explicit `Result`/`no_value`/`invalid_value`/`out_of_memory` style
    outcomes instead of silently collapsing everything into exceptions
- Adapt away C-only mechanics when they exist only for ABI reasons:
  - opaque pointer wrappers become opaque MoonBit owner types
  - output pointers become typed return values, tuples, `Option`, or explicit
    result-bearing helpers as appropriate
  - callback function pointers become MoonBit closures
  - `extern struct`, sized-struct, and C-union layout tricks become normal
    MoonBit types unless exact binary layout is itself part of the semantic
    contract being translated
- `allocator.zig` is intentionally absorbed, not translated as a standalone
  module:
  - buffer ownership for functions like `format_alloc` becomes ordinary
    MoonBit-owned `Bytes`/`String` results
  - there is no planned `c_allocator.mbt`
  - `alloc_alloc` / `alloc_free` are omitted from the planned `c_main` surface
    because they are pure C ABI support, not terminal semantics
- `main.zig` remains in scope as the aggregate wrapper index, but it aggregates
  only the pure-MoonBit translated surface, not C ABI shims.
- If a later task reveals a truly semantic reason to preserve a C-shaped API
  detail, record that in the task audit before implementation rather than
  silently widening the scope.
