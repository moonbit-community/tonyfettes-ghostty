# P17 Font and Headless Renderer Control Plane

## Goal

Plan the next translation scope for upstream Ghostty `src/font/*` and
`src/renderer/*` while keeping the first implementation wave pure MoonBit,
headless, and green without platform C FFI or GPU bindings.

This plan extends the repository beyond the completed parser and
`src/terminal/c` semantic surface. It does not reopen Phase 13: Phase 13
covered the C wrapper render/formatter/graphics surface. P17 starts the
upstream font subsystem and the real renderer subsystem.

## Upstream files

Primary font scope:

- `upstream/ghostty/src/font/main.zig`
- `upstream/ghostty/src/font/Glyph.zig`
- `upstream/ghostty/src/font/Metrics.zig`
- `upstream/ghostty/src/font/CodepointMap.zig`
- `upstream/ghostty/src/font/CodepointResolver.zig`
- `upstream/ghostty/src/font/Collection.zig`
- `upstream/ghostty/src/font/DeferredFace.zig`
- `upstream/ghostty/src/font/SharedGrid.zig`
- `upstream/ghostty/src/font/SharedGridSet.zig`
- `upstream/ghostty/src/font/Atlas.zig`
- `upstream/ghostty/src/font/shape.zig`
- `upstream/ghostty/src/font/shaper/run.zig`
- `upstream/ghostty/src/font/shaper/Cache.zig`
- `upstream/ghostty/src/font/shaper/feature.zig`
- `upstream/ghostty/src/font/shaper/harfbuzz.zig`
- `upstream/ghostty/src/font/sprite.zig`
- `upstream/ghostty/src/font/sprite/Face.zig`
- `upstream/ghostty/src/font/sprite/canvas.zig`
- `upstream/ghostty/src/font/sprite/draw/*.zig`
- `upstream/ghostty/src/font/opentype*.zig`

Deferred font adapter scope:

- `upstream/ghostty/src/font/face/freetype.zig`
- `upstream/ghostty/src/font/face/coretext.zig`
- `upstream/ghostty/src/font/face/web_canvas.zig`
- `upstream/ghostty/src/font/discovery.zig` platform discovery paths
- `upstream/ghostty/pkg/freetype/*`
- `upstream/ghostty/pkg/fontconfig/*`

Primary headless renderer scope:

- `upstream/ghostty/src/renderer.zig`
- `upstream/ghostty/src/renderer/backend.zig`
- `upstream/ghostty/src/renderer/size.zig`
- `upstream/ghostty/src/renderer/cursor.zig`
- `upstream/ghostty/src/renderer/State.zig`
- `upstream/ghostty/src/renderer/message.zig`
- `upstream/ghostty/src/renderer/row.zig`
- `upstream/ghostty/src/renderer/cell.zig`
- `upstream/ghostty/src/renderer/image.zig` data/model parts only
- `upstream/ghostty/src/renderer/link.zig` only if a non-FFI regex policy is
  approved later

Deferred renderer adapter scope:

- `upstream/ghostty/src/renderer/generic.zig` draw-loop and runtime parts
- `upstream/ghostty/src/renderer/OpenGL.zig`
- `upstream/ghostty/src/renderer/Metal.zig`
- `upstream/ghostty/src/renderer/WebGL.zig`
- `upstream/ghostty/src/renderer/opengl/*`
- `upstream/ghostty/src/renderer/metal/*`
- `upstream/ghostty/src/renderer/shaders/*`
- `upstream/ghostty/pkg/wuffs/*`
- `upstream/ghostty/pkg/oniguruma/*`

## MoonBit target files

Documentation targets for P17.0:

- `docs/plan.md`
- `docs/plans/2026-06-30-p17-font-renderer-control-plane.md`

Planned package targets:

- `font/moon.pkg`
- `font/*.mbt`
- `font/opentype/` only for Ghostty-specific adapters not covered by
  `moonbit-community/harfbuzz/sfnt`
- `font/sprite/`
- `font/shaper/`
- `renderer/moon.pkg`
- `renderer/*.mbt`

Package shape is tentative until implementation starts, but the default is to
keep `font` and `renderer` as top-level packages rather than adding more
surface to the already large `terminal` root package.

## Dependencies and invariants

Accepted dependency policy:

- Use `moonbit-community/harfbuzz` from the sibling checkout
  `../../harfbuzz.mbt` relative to this repository root.
- Do not vendor harfbuzz into this repository.
- Validate the `moon.work` setup before the first harfbuzz-backed
  implementation task.
- Record the local checkout requirement in the relevant implementation audit.
  The likely workspace root is `~/Workspace/moonbit`, with members
  `feihaoxiang/ghostty` and `harfbuzz.mbt`.

Deferred C FFI and platform dependencies:

- FreeType, CoreText, and WebCanvas font backends are deferred.
- fontconfig, CoreText, and Windows font discovery are deferred.
- WebGL, OpenGL, and Metal renderer backends are deferred.
- Wuffs PNG/JPEG decode and pixel swizzling are deferred.
- oniguruma regex matching is deferred.

Immediate translation invariants:

- Preserve Ghostty's font layering:
  pure font values -> face contracts -> collection/resolver -> shared grid ->
  run segmentation -> shaper.
- Keep harfbuzz as the per-run shaping engine only; do not collapse Ghostty's
  run segmentation, cursor/selection boundaries, fallback policy, or shaper
  cache into harfbuzz calls.
- Prefer reusing `moonbit-community/harfbuzz/sfnt` for OpenType/SFNT table
  parsing instead of duplicating equivalent parsers.
- Keep sprite font and atlas logic platform independent.
- Keep renderer work headless until a backend is approved: translate renderer
  value types, state transitions, row/cell classification, and command
  snapshots before any GPU API.
- Keep terminal kitty-graphics protocol storage separate from renderer image
  decode/upload state.

Known dependency explanations:

- Wuffs is Ghostty's C image decode and pixel-swizzle dependency. Upstream uses
  it for PNG/JPEG decode and gray/rgb/bgr/bgra-to-RGBA conversion before
  renderer upload.
- oniguruma is Ghostty's regex engine. Upstream uses it in `renderer/link.zig`
  for viewport auto-link detection from configured regular expressions. It is
  not the core OSC 8 hyperlink storage.

## Phase split

### P17.0 control plane

Scope:

- Add this plan and the Phase 17 board in `docs/plan.md`.
- Record accepted dependency decisions and deferred adapter boundaries.
- Do not implement code in this task.

### P17.A pure font values and table adapters

Scope:

- `Glyph.zig`
- `Metrics.zig`
- `CodepointMap.zig`
- backend-independent pieces from `face.zig`
- OpenType/SFNT table access policy

Acceptance notes:

- Translate metrics calculation and modifier behavior with tests.
- Translate codepoint map hashing/lookup behavior with tests.
- Audit harfbuzz.mbt `sfnt`, `face`, and `font` interfaces before adding any
  Ghostty-specific table parser.

Accepted design checkpoint:

- Goal: translate the pure MoonBit font value layer needed before any face,
  discovery, shaper, atlas, or renderer implementation.
- Accepted design: add a new top-level `font` package. Keep owner types opaque
  by default: `Glyph`, `Metrics`, `Descriptor`, `CodepointMap`, and
  `MetricModifierSet`. Expose value enums and data carriers only where later
  packages need to construct or select behavior: `MetricKey`,
  `MetricModifier`, `FaceMetrics`, `FontVariationId`, `FontVariation`, and
  `CodepointMapEntry`.
- Target files/surfaces: `font/moon.pkg`, `font/glyph.mbt`,
  `font/metrics.mbt`, `font/descriptor.mbt`, `font/codepoint_map.mbt`,
  package tests, `font/pkg.generated.mbti`, plus this plan and
  `docs/plan.md`.
- API/interface diff: new public package `tonyfettes/ghostty/font` with
  `Glyph::new` and getters, `Metrics::calc`, `Metrics::apply` and getters,
  `MetricModifier::parse`, `MetricModifierSet::new/set/get`, `Descriptor::new`
  and getters, `CodepointMap::new/add/get/hashcode`, and hashcode helpers for
  descriptor/codepoint-map comparison. No existing `terminal` package API is
  changed.
- Why existing code is not reused: the current terminal/render-state package
  models terminal snapshot state, not upstream font metrics, glyph atlas
  entries, descriptor hashes, or codepoint fallback lookup. The sibling
  harfbuzz package covers shaping/SFNT primitives but not Ghostty's metrics,
  descriptor, or codepoint-map policy.
- Open questions: no blocking questions for this pure value step. Platform
  rasterizers, font discovery, Wuffs, oniguruma, and GPU adapters remain
  deferred. Harfbuzz workspace validation is deferred until the first
  harfbuzz-backed P17 task.
- Next implementation step: port `Glyph.zig`, `Metrics.zig`,
  `CodepointMap.zig`, and the pure `discovery.Descriptor` value behavior into
  the new `font` package with translated tests.
- Validation plan: `moon check`, `moon test`, `moon coverage analyze`, review
  uncovered touched executable lines, `moon fmt`, `moon info`, and review
  `font/pkg.generated.mbti` for public API shape.

### P17.B atlas and sprite font

Scope:

- `Atlas.zig`
- `sprite.zig`
- `sprite/canvas.zig`
- `sprite/Face.zig`
- `sprite/draw/*.zig`

Acceptance notes:

- Atlas reserve, set, set-from-larger, grow, clear, and format-depth behavior
  must be tested.
- Sprite draw routines must remain independent of platform font backends.

### P17.C face contract without rasterizer FFI

Scope:

- backend-independent `face.zig` options and constraints
- in-memory/embedded face contract if feasible through harfbuzz.mbt
- explicit adapter notes for glyph rasterization gaps

Acceptance notes:

- Do not introduce FreeType/CoreText/WebCanvas FFI.
- If pixel glyph rendering is unavailable, record the exact missing capability
  and keep downstream tasks limited to paths that do not require it.

### P17.D collection, resolver, and discovery policy

Scope:

- `Collection.zig`
- `CodepointResolver.zig`
- `DeferredFace.zig`
- non-platform `discovery.zig` descriptor/value behavior

Acceptance notes:

- Preserve collection style priority, aliasing, size adjustment, presentation
  mode, and fallback semantics for embedded/in-memory faces.
- Keep system discovery as a deferred adapter, not a half-implemented public
  API.

### P17.E shared grid and shaper

Scope:

- `SharedGrid.zig`
- `SharedGridSet.zig`
- `shape.zig`
- `shaper/run.zig`
- `shaper/Cache.zig`
- `shaper/feature.zig`
- harfbuzz adapter backed by `moonbit-community/harfbuzz`

Acceptance notes:

- Preserve run splitting on style changes, cursor boundaries, selection
  boundaries, invisible cells, spacers, grapheme clusters, kitty placeholders,
  and fallback codepoints.
- Preserve cache-key semantics closely enough that repeated equivalent runs can
  share shaped output.
- Harfbuzz output must map back to Ghostty `shape.Cell` coordinates and offsets,
  not just expose raw glyph buffers.

### P17.F headless renderer values and row/cell helpers

Scope:

- `renderer/size.zig`
- `renderer/cursor.zig`
- `renderer/State.zig`
- `renderer/message.zig`
- `renderer/row.zig`
- pure parts of `renderer/cell.zig`

Acceptance notes:

- Port size, coordinate conversion, padding balance, cursor style, preedit
  range, row background-extension heuristic, and cell classification tests.
- Do not introduce renderer thread, surface mailbox, app runtime, or GPU API
  dependencies.

### P17.G headless image and placement snapshots

Scope:

- model portions of `renderer/image.zig`
- projection from translated terminal kitty graphics state to renderer-facing
  image and placement snapshots

Acceptance notes:

- Keep Wuffs decode and GPU texture upload deferred.
- Preserve placement ordering, layer split, source/destination geometry, and
  virtual placement invalidation policy where representable without a backend.

## Acceptance criteria

- P17.0 records the agreed scope and non-scope before implementation starts.
- The plan names the upstream files, intended MoonBit packages, dependency
  decisions, and deferred adapters.
- The plan keeps implementation steps green and reviewable without requiring a
  red intermediate commit.
- The first implementation wave can proceed without C FFI, platform UI, or GPU
  bindings.

## Validation commands

P17.0 is docs-only:

- doc review

Implementation tasks:

- `moon check`
- `moon test`
- `moon coverage analyze`
- review uncovered lines in touched executable files
- `moon fmt`
- `moon info`
- review `.mbti` public API changes

Harfbuzz workspace validation, before P17.E implementation:

- validate the sibling `../../harfbuzz.mbt` checkout is present
- validate `moon.work` can include both this repository and
  `../../harfbuzz.mbt`
- run the relevant `moon check` command from the workspace root

## Coverage findings for touched files

P17.0 is docs-only, so coverage is not applicable.

P17.A:

- `moon coverage analyze` was run after `moon test`.
- `moon coverage analyze -- -f caret -F font/metrics.mbt` reported no
  uncovered executable lines.
- `moon coverage analyze -- -f caret -F font/descriptor.mbt` reported no
  uncovered executable lines.
- `moon coverage analyze -- -f caret -F font/codepoint_map.mbt` reported no
  uncovered executable lines.
- `moon coverage analyze -- -f caret -F font/glyph.mbt` reported no uncovered
  executable lines.
- The remaining global coverage findings are pre-existing non-`font` gaps in
  bench/example/terminal files and are outside P17.A.

Each later implementation subplan must record coverage findings for every
touched MoonBit executable file before review.

## Commit scope

P17.0:

- `docs(font-renderer): plan headless font and renderer translation`

Implementation phases:

- `feat(font)`
- `feat(font-shaper)`
- `feat(renderer)`

## Review findings

P17.0 required doc review only.

P17.A:

- Dependency boundary review: no harfbuzz import was added, no OpenType table
  parser was duplicated, and no FreeType/CoreText/WebCanvas/fontconfig/Wuffs/
  oniguruma/GPU FFI surface was introduced.
- Public API visibility review: `Glyph`, `Metrics`, `Descriptor`,
  `CodepointMap`, `MetricModifierSet`, and `FontVariationId` are opaque owner
  types. `FaceMetrics`, `FontVariation`, `CodepointMapEntry`,
  `MetricModifier`, and `MetricKey` are public construction/selection values.
  There are no public mutable fields.
- `.mbti` review: `font/pkg.generated.mbti` contains only the P17.A package
  API; no existing `terminal` package interface changed. `CodepointMapEntry`
  is consumed by `CodepointMap::add`.
  `MetricModifier::apply_*` helpers and metrics internals remain private.
- Coverage findings review: all touched executable `font/*.mbt` files have no
  uncovered lines after targeted caret coverage review.
- Deferred adapter confirmation: system discovery, rasterization, image decode,
  regex link matching, and GPU backends remain absent.

Implementation reviews must include:

- dependency boundary review
- public API visibility review
- `.mbti` review
- coverage findings review
- confirmation that deferred FFI adapters did not leak into the first wave

## Audit/result notes

- Phase 13 already translated the `src/terminal/c` render, formatter, and
  graphics semantic surface. P17 intentionally starts a new upstream subsystem
  boundary instead of modifying Phase 13 history.
- Harfbuzz is approved as a sibling workspace dependency via
  `../../harfbuzz.mbt`, not as vendored source.
- FreeType/CoreText/WebCanvas font backends, system font discovery,
  WebGL/OpenGL/Metal backends, Wuffs, and oniguruma are deferred because they
  require C FFI or platform/runtime bindings.
- The first useful renderer target is headless command/state generation, not a
  live GUI renderer.
- P17.A added `tonyfettes/ghostty/font` with pure `Glyph`, `Metrics`,
  `FaceMetrics`, `MetricModifier`, `MetricModifierSet`, `Descriptor`,
  `FontVariation`, and `CodepointMap` behavior. Hashcodes use MoonBit's
  deterministic `Hasher(seed=0)` and return `UInt`; this preserves the
  descriptor/map identity contract without pretending to expose upstream Zig's
  `u64` Wyhash implementation.
- P17.A validation passed:
  `moon check`;
  `moon test` with 586 tests passed;
  `moon coverage analyze` plus targeted touched-file caret review;
  `moon fmt`;
  `moon info`.

## Public API visibility findings

P17.0 changes docs only and does not change `.mbti`.

P17.A adds `font/pkg.generated.mbti`. The public API is intentional for future
font face, resolver, shaper, and renderer consumers:

- opaque owner types for lifecycle/stateful values
- public data carriers where future packages must construct inputs
- no public mutable fields
- no parser/terminal public API churn

For implementation tasks:

- new `font` and `renderer` packages should keep owner types opaque by default
- internal caches, run iterators, atlas nodes, and renderer command builders
  must not be public unless a caller story is recorded
- public mutable fields remain banned unless explicitly justified in the
  subplan
