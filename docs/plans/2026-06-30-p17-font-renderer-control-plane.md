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
- Accepted design: add a new top-level `font` package and keep P17.A as close
  to upstream Zig field and method shape as MoonBit can express. `Glyph`,
  `Metrics`, `Descriptor`, `CodepointMap`, `CodepointMapEntry`,
  `FaceMetrics`, `FontVariationId`, and `FontVariation` are public data
  carriers because the upstream structs expose those fields directly.
  `ModifierSet` remains opaque because it stands in for Zig's unmanaged hash
  map storage.
- Target files/surfaces: `font/moon.pkg`, `font/glyph.mbt`,
  `font/metrics.mbt`, `font/descriptor.mbt`, `font/codepoint_map.mbt`,
  package tests, `font/pkg.generated.mbti`, plus this plan and
  `docs/plan.md`.
- API/interface diff: new public package `tonyfettes/ghostty/font` with
  upstream-shaped public fields for the pure value structs, `Metrics::calc`,
  `Metrics::apply`, `Modifier::parse`, `ModifierSet::new/set/get`,
  `Descriptor::new`, `Descriptor::hashcode`,
  `CodepointMap::new/add/get/hashcode`, and hashcode helpers for
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

P17.B.1 accepted design checkpoint:

- Goal: translate upstream `font/Atlas.zig` as the first green slice of P17.B,
  before sprite canvas and draw routines.
- Accepted design: add atlas packing and byte-buffer storage to the existing
  `font` package. Follow the upstream field and method contract first, even
  when that exposes mutable backing storage. `Atlas.data` is intentionally
  reachable like Zig's `data: []u8`; callers that can reach it can observe and
  mutate the backing buffer. This is recorded as an intentional exception to
  the general public-mutable-field ban for faithful translation.
- Target files/surfaces: `font/atlas.mbt`, `font/atlas_test.mbt`,
  `font/pkg.generated.mbti`, this plan file, and later P17.B audit notes.
  `docs/plan.md` remains `P17.B todo` until sprite substrate also lands.
- API/interface diff: new public `Atlas` field surface matching upstream as
  closely as MoonBit can express it: `data`, `size`, `format`, `modified`, and
  `resized` are public mutable state; the node list may remain private unless
  MoonBit requires exposing a named `AtlasNode` to keep the field model
  faithful. New public `AtlasFormat` and `AtlasRegion`; `AtlasError` only
  contains upstream's real `AtlasFull` error. Methods map directly from
  upstream names/behavior: `Atlas::new`/init, `reserve`, `set`,
  `set_from_larger`, `grow`, `clear`, and `AtlasFormat::depth`.
- Intentional MoonBit naming/type adapters: Zig nested `Format`/`Region` become
  package-level `AtlasFormat`/`AtlasRegion`; Zig `setFromLarger` becomes
  `set_from_larger`; Zig `[]const u8` inputs become MoonBit read-only byte
  views; allocator errors are omitted because MoonBit allocation is GC-managed.
- Revised implementation shape approved before code:
  - `Atlas.data` uses `Array[Byte]` rather than `Bytes` because MoonBit
    `Bytes` is immutable at the public API level and cannot model Zig's
    mutable `[]u8` backing storage.
  - `Atlas.nodes` is exposed as `Array[AtlasNode]`. MoonBit has no per-field
    public/private visibility equivalent, so exposing the upstream public
    `Atlas` fields requires the node field to appear too.
  - `AtlasNode`, `AtlasRegion`, and `Atlas` use `UInt` for upstream
    `u32`/`usize` values where MoonBit indexing requires conversion through
    `Int`.
  - `Atlas::set` and `Atlas::set_from_larger` accept `ArrayView[Byte]` as the
    read-only slice counterpart for upstream `[]const u8`.
  - `modified` and `resized` are mutable `UInt` counters standing in for
    upstream `std.atomic.Value(usize)`.
  - `init` is exposed as `Atlas::new` because MoonBit has no allocator
    parameter; allocator/OOM/tripwire/deinit/debug dump/Wasm APIs remain
    deferred adapters for this pure GC-backed slice.
- Why existing code cannot be reused as-is: the current `font` package only
  contains glyph/metrics/descriptor/codepoint-map values. No existing
  terminal or font module owns atlas pixel storage or rectangle packing.
- Open questions: no blocker for atlas. Sprite canvas and z2d-equivalent path
  drawing remain the next P17.B substep.
- Next implementation step: port `Format.depth`, `Region`, `init/clear`,
  `reserve/fit/merge`, `set`, `setFromLarger`, and `grow` from
  `Atlas.zig`, with translated tests for exact fit, full atlas, multiple fit,
  writes, larger-source writes, growth, and BGR depth.
- Validation plan: `moon check`, `moon test`, `moon coverage analyze`,
  targeted caret coverage for `font/atlas.mbt`, `moon fmt`, `moon info`, and
  `.mbti` public API review.

P17.B.2 accepted design checkpoint:

- Goal: translate the pure sprite/canvas substrate from upstream
  `font/sprite.zig` and `font/sprite/canvas.zig`, so later sprite draw
  routines have a platform-independent alpha surface that can write into the
  translated `Atlas`.
- Accepted design: keep the sprite/canvas surface inside the existing `font`
  package for now. This preserves a direct path from `Canvas.writeAtlas` to
  `Atlas` and avoids a future package cycle between `font` and
  `font/sprite` when sprite fallback is integrated into collection/face
  logic.
- Target files/surfaces: `font/sprite.mbt`, `font/sprite_canvas.mbt`,
  `font/sprite_canvas_test.mbt`, `font/pkg.generated.mbti`, and this plan
  file. `docs/plan.md` remains `P17.B todo` until the sprite substrate,
  direct draw-routine dispatch, and sprite face rendering are complete.
- API/interface diff: add public `Sprite`, `SpriteColor`,
  `SpritePoint[T]`, `SpriteLine[T]`, `SpriteBox[T]`, `SpriteRect[T]`,
  `SpriteTriangle[T]`, `SpriteQuad[T]`, and `SpriteCanvas`. `SpriteCanvas`
  exposes `data`, `width`, `height`, `padding_x`, `padding_y`, and clip
  fields because upstream `Canvas` exposes the drawable surface and clip
  state inside the sprite namespace. Add methods corresponding to the pure
  upstream canvas operations: `new`, `write_atlas`,
  `clear_clipping_regions`, `pixel`, `rect`, `box`, `invert`,
  `flip_horizontal`, and `flip_vertical`.
- Intentional MoonBit naming/type adapters:
  - Zig `Sprite = enum(u32)` becomes an opaque scalar `Sprite` with
    `start/end`, tag constructors, `codepoint`, and `from_codepoint` helpers,
    because MoonBit enums do not expose Zig-style raw integer tags.
  - Zig open raw `Color = enum(u8) { on = 255, off = 0, _ }` becomes
    `SpriteColor(Byte)` with `on/off/from_byte/value` helpers so later shade
    drawing can still pass arbitrary alpha values.
  - Zig comptime geometry factories `Point(T)`, `Line(T)`, `Box(T)`,
    `Rect(T)`, `Triangle(T)`, and `Quad(T)` become public generic MoonBit
    structs with `Sprite*` prefixes. `SpriteBox::rect` is implemented for the
    integer rectangle path used by the pure canvas primitive.
  - Zig `z2d.Surface` is represented by public `SpriteCanvas.data` plus
    `width`/`height` fields, storing alpha bytes directly. This is an
    approved local substitute for the z2d alpha8 surface, not a renderer/GPU
    backend.
  - Allocator/deinit/OOM behavior is omitted in this GC-backed slice.
- Deferred from P17.B.2: `getContext`, `staticPath`, `line`, `triangle`,
  `quad`, `strokePath`, `fillPath`, `innerStrokePath`, PNG golden-diff tests,
  Wuffs decode, `sprite/Face.zig` `renderGlyph`, and any z2d-equivalent path
  rasterizer. These require either P17.C face options or a separately
  approved rasterizer adapter.
- Why existing code cannot be reused as-is: `Atlas` owns packed texture
  storage but has no drawable alpha surface, clipping state, or padded cell
  coordinate system. Existing terminal renderer snapshots are not suitable as
  a sprite glyph raster surface.
- Open questions: no blocker for the pure alpha canvas. The path rasterizer
  strategy for curved/triangular sprite drawing remains an explicit follow-up
  before porting all `draw/*.zig` routines.
- Next implementation step: add `Sprite`, the pure `SpriteCanvas` operations,
  and focused tests for codepoint mapping, geometry normalization, padded
  pixel/rectangle writes, trimming into an atlas, clipping-region clearing,
  inversion, and horizontal/vertical flips.
- Validation plan: `moon check`, targeted `moon test font`, full `moon test`,
  `moon coverage analyze`, targeted caret coverage for the new sprite files,
  `moon fmt`, `moon info`, and `.mbti` public API review.

P17.B.3 accepted design checkpoint:

- Goal: translate upstream `font/sprite/Face.zig` sprite dispatch in the
  simplest MoonBit shape while preserving upstream draw routine behavior.
- Accepted design: do not add a generator, function-pointer table, draw
  registry type, `get_draw_fn`, or `draw_sprite -> Bool` helper. MoonBit will
  use explicit `match cp` range dispatch directly in `render_glyph`: each
  matching range calls the corresponding package-private translated draw
  routine, and the fallback branch immediately returns a blank glyph. This is
  the approved adapter for Zig's comptime reflection-generated
  `getDrawFn(cp) orelse return glyph`.
- Target files/surfaces: `font/sprite_face.mbt`, package-private
  `font/sprite_draw_*.mbt` files as draw routines are translated,
  `font/sprite_face_test.mbt` or `_wbtest.mbt`, `font/pkg.generated.mbti`, and
  this plan file.
- API/interface diff: no public registry, no public draw function type, and no
  public draw routine surface. `SpriteFace` remains package-private unless
  later P17.C/P17.D integration needs a recorded public caller story.
  `has_codepoint`, if needed for sprite fallback, should also be a direct
  range match and should not reuse a hidden registry abstraction.
- Intentional MoonBit naming/type adapters: Zig's comptime declaration scan is
  replaced with hand-maintained explicit range arms. Each arm must correspond
  to an upstream `drawXXXX` or `drawXXXX_YYYY` symbol and should stay ordered
  by codepoint range for reviewability. Until P17.C translates the full
  `font.face.RenderOptions`, `render_glyph` takes a package-private
  `cell_width : UInt?` adapter for the single upstream option that
  `sprite/Face.zig` reads. This adapter must be replaced by the real
  `RenderOptions` surface when P17.C lands.
- Why existing code cannot be reused as-is: P17.B.2 only provides the alpha
  canvas primitives. It has no sprite face, no draw dispatch, and no
  translated draw routines.
- Open questions: the z2d-equivalent path/curve/triangle rasterizer and PNG
  golden-diff/Wuffs boundary remain separate P17.B work. The first executable
  slice may translate only draw routines whose dependencies are already present
  in `SpriteCanvas`.
- Next implementation step: add the direct-dispatch sprite face slice with
  package-private draw routines for an initial green subset, plus tests that
  unsupported codepoints return a blank glyph and supported ranges call the
  translated routine through `render_glyph`.
- Validation plan: `moon check`, targeted `moon test font`, full `moon test`,
  `moon coverage analyze`, targeted caret coverage for touched font files,
  `moon fmt`, `moon info`, and `.mbti` public API review confirming no
  registry/draw helper leaked publicly.

P17.B.4 accepted design checkpoint:

- Goal: translate the rect/box-only subset of upstream
  `font/sprite/draw/special.zig` while keeping the sprite face direct-dispatch
  model from P17.B.3.
- Accepted design: add package-private special sprite draw routines only for
  upstream functions whose bodies use the already-translated
  `SpriteCanvas.rect`/`box`/`pixel` primitives. Do not add z2d context, path,
  stroke, fill, arc, branch drawing, generator output, a registry, `DrawFn`, or
  a `draw_sprite -> Bool` helper in this slice.
- Target files/surfaces: `font/sprite_draw_special.mbt`,
  `font/sprite_face.mbt`, `font/sprite_face_wbtest.mbt`,
  `font/pkg.generated.mbti`, and this plan file.
- API/interface diff: no public API is expected. `SpriteFace`, special draw
  routines, and special dispatch helpers remain package-private. The existing
  public `Sprite` codepoint value surface is reused as-is.
- Included upstream symbols: `underline`, `underline_double`,
  `underline_dashed`, `strikethrough`, `overline`, `cursor_rect`,
  `cursor_hollow_rect`, `cursor_bar`, and `cursor_underline`.
- Deferred upstream symbols: `underline_dotted` and `underline_curly` require
  z2d-style context/path/curve/fill/stroke behavior and remain deferred.
  `font/sprite/draw/branch.zig` is also deferred because it depends on
  `box.zig` `arc(...)` and z2d context `arc`/`stroke`/`fill` behavior.
- Intentional MoonBit naming/type adapters: Zig special sprite enum field names
  become explicit special-codepoint match arms corresponding to
  `Sprite::...().codepoint()` in `SpriteFace.render_glyph` and
  `SpriteFace.has_codepoint`. Only implemented special sprite codepoints should
  return true from `has_codepoint`; deferred special sprite codepoints continue
  to fall back to a blank glyph. A package-private `saturating_add_uint` helper
  in `font/sprite_draw_special.mbt` stands in for Zig `+|` where upstream
  clamps decoration positions to the padded canvas extent.
- Why existing code cannot be reused as-is: P17.B.3 only dispatches Unicode
  block and braille ranges. It does not handle upstream special sprite
  codepoints such as decorations and cursors.
- Open questions: exact z2d-compatible rasterization semantics for dotted and
  curly underlines, branch arcs, path strokes/fills, PNG golden diff, and Wuffs
  remain separate P17.B follow-up work.
- Next implementation step: add the special rect-only draw file, extend direct
  dispatch and `has_codepoint`, and add focused white-box tests that verify
  implemented special sprites render while deferred special sprites remain
  unsupported.
- Validation plan: `moon check`, targeted `moon test font`, full `moon test`,
  `moon coverage analyze`, targeted caret coverage for touched font files,
  `moon fmt`, `moon info`, and `.mbti` public API review confirming no special
  draw helper leaked publicly.

P17.B.5 accepted design checkpoint:

- Goal: translate the pure box/fill subset of upstream
  `font/sprite/draw/symbols_for_legacy_computing_supplement.zig` that can run
  on the already-translated `SpriteCanvas` primitives.
- Accepted design: add package-private draw routines for only the three
  upstream ranges whose bodies use `canvas.box` or `common.fill` directly:
  `draw1CC21_1CC2F`, `draw1CE51_1CE8F`, and `draw1CE90_1CEAF`. Keep
  `SpriteFace` direct range dispatch from P17.B.3; do not add a generator,
  registry, `DrawFn`, function-pointer table, or `draw_sprite -> Bool` helper.
- Target files/surfaces: new
  `font/sprite_draw_legacy_computing_supplement.mbt`,
  `font/sprite_draw_common.mbt`, `font/sprite_face.mbt`,
  `font/sprite_face_wbtest.mbt`, `font/pkg.generated.mbti`, and this plan
  file.
- API/interface diff: no public API is expected. The legacy supplement draw
  routines and the extra fraction variants remain package-private. The
  generated `font/pkg.generated.mbti` should remain unchanged.
- Included upstream symbols:
  - `draw1CC21_1CC2F`: separated block quadrants.
  - `draw1CE51_1CE8F`: separated block sextants.
  - `draw1CE90_1CEAF`: sixteenth blocks.
- Deferred upstream symbols:
  - `draw1CD00_1CDE5` depends on `octants.txt` and the policy for translating
    Zig comptime `@embedFile` tables.
  - `draw1CC30_1CC3F`, `draw1CE0B`, and `draw1CE0C` depend on
    `staticPath`/`strokePath` circle-piece rasterization.
  - `draw1CC1B_1CC1E` and `draw1CE16_1CE19` call `box.linesChar` and wait for
    a `box.zig` translation slice.
  - Other line/path/arc/rasterizer-dependent legacy supplement symbols remain
    deferred with the broader P17.B rasterizer boundary.
- Intentional MoonBit naming/type adapters: extend private
  `SpriteDrawFraction` with quarter fractions corresponding to upstream
  `common.Fraction.quarters`, so `draw1CE90_1CEAF` can remain a direct switch
  over upstream fill arms. Zig packed `Quads`/`Sextants` bit casts are
  translated to explicit bit-mask reads from `cp - range_base`, preserving the
  upstream bit order without adding helper structs that leak into `.mbti`.
- Why existing code cannot be reused as-is: P17.B.3/P17.B.4 only cover Block
  Elements, Braille Patterns, and rect-only special sprites. The legacy
  computing supplement ranges live in a separate upstream draw file and need
  their own package-private translation and dispatch arms.
- Open questions: no blocker for these three pure ranges. Octant embedded data,
  `box.zig`, circle/path rasterization, Wuffs PNG golden diffs, and broader
  rasterizer compatibility remain separate approved-deferred boundaries.
- Next implementation step: add the legacy supplement draw file, extend
  package-private fraction support, wire the three ranges into
  `SpriteFace.has_codepoint` and `SpriteFace.render_glyph`, and add focused
  white-box tests for included ranges and deferred nearby ranges.
- Validation plan: `moon check`, targeted `moon test font`, full `moon test`,
  `moon coverage analyze`, targeted caret coverage for touched font files,
  `moon fmt`, `moon info`, and `.mbti` public API review confirming no legacy
  supplement draw helper leaked publicly.

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

P17.B.1:

- `moon coverage analyze` was run after `moon test`.
- `moon coverage analyze -- -f caret -F font/atlas.mbt` reported no uncovered
  executable lines.
- The remaining global coverage findings are pre-existing non-`font` gaps in
  bench/example/terminal files and are outside P17.B.1.

P17.B.2:

- `moon coverage analyze` was run after `moon test`.
- `moon coverage analyze -- -f caret -F font/sprite.mbt` reported no
  uncovered executable lines.
- `moon coverage analyze -- -f caret -F font/sprite_canvas.mbt` reported no
  uncovered executable lines.
- `moon coverage analyze -- -f caret -F font/atlas.mbt` reported no uncovered
  executable lines after the record-type annotation needed by the new
  `SpriteRect` public shape.
- The remaining global coverage findings are pre-existing non-`font` gaps in
  bench/example/terminal files and are outside P17.B.2.

P17.B.5:

- `moon coverage analyze` was run after `moon test`.
- `moon coverage analyze -- -f caret -F
  font/sprite_draw_legacy_computing_supplement.mbt` reported no uncovered
  executable lines.
- `moon coverage analyze -- -f caret -F font/sprite_draw_common.mbt` reported
  no uncovered executable lines.
- `moon coverage analyze -- -f caret -F font/sprite_face.mbt` reported no
  uncovered executable lines.
- The remaining global coverage findings are pre-existing bench/example/
  terminal gaps plus the already-documented `font/sprite_draw_braille.mbt`
  invariant residuals, and are outside P17.B.5.

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
- Public API visibility review: superseded by the faithful repair below. The
  first implementation used opaque owner APIs, but the accepted P17 priority is
  Zig field parity over MoonBit API minimization.
- `.mbti` review: superseded by the faithful repair below. No existing
  `terminal` package interface changed.
- Coverage findings review: all touched executable `font/*.mbt` files have no
  uncovered lines after targeted caret coverage review.
- Deferred adapter confirmation: system discovery, rasterization, image decode,
  regex link matching, and GPU backends remain absent.

P17.A faithful repair checkpoint:

- Problem: the first P17.A implementation preserved much of the pure font value
  behavior, but it was not a strict line-by-line translation. It introduced
  MoonBit-style opaque owner APIs/getters, changed some upstream field shapes,
  and changed descriptor hash behavior. This conflicts with the revised P17
  priority that faithful Zig translation is higher priority than API
  minimization.
- Accepted design: repair only the already-landed P17.A value layer so its
  public field shape, method set, and hash semantics follow upstream
  `Glyph.zig`, `Metrics.zig`, `CodepointMap.zig`, `discovery.Descriptor`, and
  `face.Variation` as closely as MoonBit can express. Any remaining MoonBit
  adapters must be named and documented as adapters, not hidden redesigns.
- Target files/surfaces: `font/glyph.mbt`, `font/metrics.mbt`,
  `font/descriptor.mbt`, `font/codepoint_map.mbt`, `font/font_test.mbt`,
  `font/metrics_wbtest.mbt`, `font/pkg.generated.mbti`, and this plan file.
- Expected API/interface diff:
  - `Glyph` becomes a public field carrier matching upstream fields instead of
    an opaque type with constructor/getter API.
  - `Metrics` becomes a public mutable field carrier matching upstream fields;
    getter methods that only hid fields are removed.
  - `FaceMetrics` remains a public field carrier and keeps upstream helper
    methods translated to MoonBit snake_case.
  - `FontVariationId` changes from a packed `UInt` wrapper to an `a/b/c/d`
    field carrier matching upstream `Variation.Id`; `FontVariation` keeps
    `id/value`.
  - `Descriptor.size` changes to `Float` to match upstream `f32`; descriptor
    and codepoint-map hash functions restore upstream semantics, including
    truncating variation decimal values for hashing. Hashcode still returns
    `UInt` as the MoonBit-sized stand-in for upstream `u64`, and this adapter
    remains recorded.
  - `CodepointMapEntry` changes from `start/end` to a range pair shape matching
    upstream `Entry.range: [2]u21` as closely as MoonBit can express.
  - `CodepointMap` exposes a public mutable `list` field as the MoonBit Array
    stand-in for upstream `std.MultiArrayList(Entry)`.
- Why existing code cannot be reused as-is: it was intentionally API-shaped for
  opaque MoonBit consumers, but P17 now requires Zig-first public field and
  behavior parity. Continuing with the existing API would keep translating
  downstream P17 files against a MoonBit-specific abstraction that does not
  exist upstream.
- Open questions: no blocking questions for this repair. Allocator/deinit/clone
  are still not translated where they only model Zig allocator ownership that
  MoonBit GC does not expose; each omission must be recorded as a MoonBit
  adapter rather than an upstream behavior claim.
- Remaining adapters:
  - `Descriptor::new` is a MoonBit convenience constructor for upstream struct
    field defaults; direct field construction remains available through
    `pub(all)`.
  - `ModifierSet` is an opaque wrapper around `HashMap`, standing in for
    upstream `std.AutoHashMapUnmanaged(Key, Modifier)`.
  - `MetricKey` is a package-level enum standing in for upstream
    `Metrics.Key`, which is generated from struct fields at comptime.
  - `hashcode` returns MoonBit `UInt` and uses MoonBit `Hasher(seed=0)`, while
    upstream returns `u64` from Zig Wyhash.
  - `CodepointMap.list` uses `Array[CodepointMapEntry]` as the
    `std.MultiArrayList(Entry)` stand-in.
  - `Modifier.parseCLI` and `Modifier.formatEntry` remain deferred because the
    corresponding Ghostty config formatter/parser surface has not been ported.
- Next implementation step: revise the P17.A files and tests before starting
  any P17.B atlas code.
- Validation plan: `moon check`, `moon test`, `moon coverage analyze`, targeted
  caret coverage for touched `font/*.mbt` files, `moon fmt`, `moon info`, and
  `.mbti` review for intentionally public mutable field surface.

P17.B.1:

- Dependency boundary review: no sprite canvas, rasterizer, Wuffs, GPU, or
  platform FFI surface was introduced.
- Public API visibility review: `Atlas` intentionally exposes mutable
  `data/size/nodes/format/modified/resized` fields to preserve upstream field
  access. `AtlasNode` is public because MoonBit lacks per-field visibility for
  a partially public struct.
- `.mbti` review: `font/pkg.generated.mbti` adds only the atlas surface:
  `Atlas`, `AtlasFormat`, `AtlasNode`, `AtlasRegion`, `AtlasError`, and the
  translated methods `new/reserve/set/set_from_larger/grow/clear/depth`.
- Coverage findings review: `font/atlas.mbt` has no uncovered executable lines
  after targeted caret coverage review.
- Deferred adapter confirmation: allocator/OOM/tripwire/deinit/debug dump/Wasm
  APIs remain deferred; `Array[Byte]`/`ArrayView[Byte]` stand in for Zig byte
  slices and `UInt` counters stand in for atomics.

P17.B.2:

- Dependency boundary review: no `z2d` path API, Wuffs PNG decode/export,
  sprite `Face.renderGlyph`, platform font backend, renderer backend, or GPU
  surface was introduced.
- Public API visibility review: `Sprite` and `SpriteColor` are opaque scalar
  wrappers with public constructors/accessors for the approved raw-codepoint
  and raw-alpha adapters. `SpriteCanvas` intentionally exposes mutable
  `data` and clip fields to model upstream's drawable alpha surface and clip
  state.
- `.mbti` review: `font/pkg.generated.mbti` adds only the approved sprite
  substrate surface: `Sprite`, `SpriteColor`, generic `Sprite*` geometry
  structs, `SpriteCanvas`, and the pure canvas operations. No
  parser/terminal package interface changed.
- Coverage findings review: `font/sprite.mbt`, `font/sprite_canvas.mbt`, and
  the touched `font/atlas.mbt` line have no uncovered executable lines after
  targeted caret coverage review.
- Deferred adapter confirmation: `getContext`, `staticPath`, line/triangle/
  quad/path stroke/fill operations, z2d-equivalent rasterization, PNG golden
  diff tests, Wuffs decode, and `sprite/Face.zig` glyph rendering remain
  deferred.
- Adapter note: `SpriteCanvas.pixel` clips writes outside the local alpha
  surface before indexing the MoonBit array. This is the safe local stand-in
  for z2d surface bounds handling and is covered by tests.

P17.B.3:

- Dependency boundary review: no z2d path API, Wuffs PNG decode/export,
  platform font backend, renderer backend, GPU surface, generator package, or
  runtime registry abstraction was introduced.
- Public API visibility review: `SpriteFace`, translated draw routines, draw
  helpers, and the temporary `cell_width : UInt?` render option adapter remain
  package-private. No public `DrawFn`, `get_draw_fn`, registry table, or draw
  routine surface exists.
- `.mbti` review: `font/pkg.generated.mbti` should remain unchanged for this
  slice because the new sprite face/direct-dispatch code is internal until
  P17.C/P17.D records a public caller story.
- Coverage findings review: `font/sprite_draw_block.mbt`,
  `font/sprite_draw_common.mbt`, and `font/sprite_face.mbt` have no uncovered
  executable lines after targeted caret coverage. `font/sprite_draw_braille.mbt`
  has four uncovered lines: the final "increase dot width" branch and three
  post-layout invariant aborts. These mirror upstream assert-style safety paths;
  exhaustive local search over practical cell sizes found the final adjustment
  unreachable after the preceding margin/spacing adjustments, and the invariant
  aborts are only reachable if that layout math is internally broken.
- Deferred adapter confirmation: path/curve/triangle rasterization, PNG golden
  diff tests, Wuffs decode, special sprite drawing, and the remaining
  `sprite/draw/*.zig` ranges remain deferred.

P17.B.4:

- Dependency boundary review: no z2d context/path/stroke/fill/arc API, Wuffs
  PNG decode/export, platform font backend, renderer backend, GPU surface,
  generator package, or runtime registry abstraction was introduced.
- Public API visibility review: rect-only special draw routines remain
  package-private and are reachable only through `SpriteFace` direct dispatch.
  No public `DrawFn`, registry table, special draw helper, or rasterizer
  adapter surface exists.
- `.mbti` review: `font/pkg.generated.mbti` remains unchanged for this slice
  because the new special sprite draw code is internal.
- Coverage findings review: `font/sprite_draw_special.mbt` and
  `font/sprite_face.mbt` have no uncovered executable lines after targeted
  caret coverage. The pre-existing `font/sprite_draw_braille.mbt` invariant
  residuals remain unchanged.
- Deferred adapter confirmation: `underline_dotted`, `underline_curly`,
  `branch.zig`, `box.zig` arcs, path/curve/triangle rasterization, PNG golden
  diff tests, Wuffs decode, and remaining `sprite/draw/*.zig` ranges remain
  deferred.

P17.B.5:

- Dependency boundary review: no z2d context/path/stroke/fill/arc API, Wuffs
  PNG decode/export, platform font backend, renderer backend, GPU surface,
  generator package, or runtime registry abstraction was introduced.
- Public API visibility review: legacy supplement draw routines and the
  quarter `SpriteDrawFraction` variants remain package-private and are
  reachable only through `SpriteFace` direct dispatch. No public `DrawFn`,
  registry table, draw helper, or rasterizer adapter surface exists.
- `.mbti` review: `font/pkg.generated.mbti` remains unchanged for this slice
  because the new legacy supplement draw code is internal.
- Coverage findings review:
  `font/sprite_draw_legacy_computing_supplement.mbt`,
  `font/sprite_draw_common.mbt`, and `font/sprite_face.mbt` have no uncovered
  executable lines after targeted caret coverage. The pre-existing
  `font/sprite_draw_braille.mbt` invariant residuals remain unchanged.
- Deferred adapter confirmation: octant embedded data, `box.zig` line
  characters, circle/path rasterization, PNG golden diff tests, Wuffs decode,
  and remaining legacy supplement ranges remain deferred.

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
  `FaceMetrics`, `Modifier`, `ModifierSet`, `Descriptor`, `FontVariation`,
  `FontVariationId`, and `CodepointMap` behavior. The faithful repair changed
  the first implementation from MoonBit-style opaque/getter APIs to
  upstream-shaped public fields and restored descriptor hash details such as
  `f32` size bits and truncated variation values. Hashcodes use MoonBit's
  deterministic `Hasher(seed=0)` and return `UInt`; this preserves the
  descriptor/map identity contract without pretending to expose upstream Zig's
  `u64` Wyhash implementation.
- P17.A validation passed:
  `moon check`;
  `moon test` with 588 tests passed;
  `moon coverage analyze` plus targeted touched-file caret review;
  `moon fmt`;
  `moon info`.
- P17.B.1 added `Atlas` packing and byte-buffer storage with translated tests
  for depth, exact fit, full-atlas failures, multi-region packing, skyline y
  raising, direct writes, larger-source writes, growth, BGR writes/growth,
  clear, and assertion panic paths. The debug dump, Wasm wrapper, explicit
  allocator failure tests, `deinit`, and tripwire failure injection are
  deferred adapters because this MoonBit slice is GC-backed and headless.
- P17.B.1 validation passed:
  `moon check`;
  `moon test` with 603 tests passed;
  `moon coverage analyze` plus targeted `font/atlas.mbt` caret review;
  `moon fmt`;
  `moon info`.
- P17.B.2 added `Sprite`, `SpriteColor`, generic sprite geometry value types,
  and `SpriteCanvas` pure alpha-surface operations. The canvas covers padded
  coordinate writes, rectangle/box filling, trim-to-atlas writes,
  clipping-region clearing, inversion, and horizontal/vertical flips. Path
  rasterization, PNG diff tests, Wuffs, and `sprite/Face.zig` rendering remain
  deferred adapters.
- P17.B.2 validation passed:
  `moon check`;
  `moon test font` with 49 tests passed;
  `moon test` with 618 tests passed;
  `moon coverage analyze` plus targeted `font/sprite.mbt`,
  `font/sprite_canvas.mbt`, and `font/atlas.mbt` caret review;
  `moon fmt`;
  `moon info`.
- P17.B.3 added package-private `SpriteFace` direct range dispatch and the
  initial pure draw routines for Block Elements (`U+2580..U+259F`) and Braille
  Patterns (`U+2800..U+28FF`). Unsupported codepoints return the upstream
  blank glyph shape through `render_glyph`; supported initial ranges draw into
  `SpriteCanvas` and write through the existing atlas path. The implementation
  intentionally does not add a generator, function pointer registry,
  `get_draw_fn`, or `draw_sprite -> Bool`.
- P17.B.3 validation passed:
  `moon check`;
  `moon test font` with 60 tests passed;
  `moon test` with 629 tests passed;
  `moon coverage analyze` reported 290 uncovered lines in 36 files, with only
  `font/sprite_draw_braille.mbt` touched-file residuals documented in the
  P17.B.3 coverage review;
  targeted caret coverage for `font/sprite_draw_block.mbt`,
  `font/sprite_draw_common.mbt`, and `font/sprite_face.mbt` reported no
  uncovered lines;
  targeted caret coverage for `font/sprite_draw_braille.mbt` reported only the
  documented layout invariant residuals;
  `moon fmt`;
  `moon info`.
- P17.B.4 added package-private rect-only special sprite draw routines for
  underline, double underline, dashed underline, strikethrough, overline, rect
  cursor, hollow rect cursor, bar cursor, and underline cursor. `SpriteFace`
  direct dispatch now recognizes only those implemented special codepoints;
  dotted and curly underlines remain unsupported and return the upstream blank
  glyph shape through the fallback branch.
- P17.B.4 validation passed:
  `moon check`;
  `moon test font` with 63 tests passed;
  `moon test` with 632 tests passed;
  `moon coverage analyze` reported 290 uncovered lines in 36 files, with no new
  touched-source residuals;
  targeted caret coverage for `font/sprite_draw_special.mbt` and
  `font/sprite_face.mbt` reported no uncovered lines;
  `moon fmt`;
  `moon info`.
- P17.B.5 added package-private pure legacy supplement draw routines for
  separated block quadrants (`U+1CC21..U+1CC2F`), separated block sextants
  (`U+1CE51..U+1CE8F`), and sixteenth blocks (`U+1CE90..U+1CEAF`).
  `SpriteFace` direct dispatch now recognizes only those implemented ranges;
  octants, circle pieces, `box.zig` line-character composites, and other
  rasterizer-dependent legacy supplement codepoints remain unsupported and
  return the upstream blank glyph shape through the fallback branch.
- P17.B.5 validation passed:
  `moon check`;
  `moon test font` with 67 tests passed;
  `moon test` with 636 tests passed;
  `moon coverage analyze` reported 290 uncovered lines in 36 files, with no new
  touched-source residuals;
  targeted caret coverage for
  `font/sprite_draw_legacy_computing_supplement.mbt`,
  `font/sprite_draw_common.mbt`, and `font/sprite_face.mbt` reported no
  uncovered lines;
  `moon fmt`;
  `moon info`.

## Public API visibility findings

P17.0 changes docs only and does not change `.mbti`.

P17.A adds `font/pkg.generated.mbti`. The public API is intentional for future
font face, resolver, shaper, and renderer consumers and is now governed by the
faithful-translation priority:

- public fields are allowed where upstream structs expose direct fields
- public mutable fields on `Metrics` and `CodepointMap.list` are intentional
  because upstream mutates those fields/storage directly
- opaque owner types remain preferred only where upstream storage is not a
  simple public field carrier, such as `ModifierSet`
- no parser/terminal public API churn

P17.B.1 extends `font/pkg.generated.mbti` with the atlas surface:

- `Atlas.data` is public mutable `Array[Byte]` to model upstream mutable
  `[]u8` storage.
- `Atlas.nodes` and `AtlasNode` are public mutable adapter surface because
  MoonBit cannot expose only selected fields of a public record.
- `Atlas.modified` and `Atlas.resized` are public mutable `UInt` counters
  standing in for upstream atomic values.
- No parser/terminal public API churn.

P17.B.2 extends `font/pkg.generated.mbti` with the sprite substrate:

- `Sprite` is opaque and exposes raw-codepoint constructors/accessors instead
  of a MoonBit enum because upstream uses `enum(u32)` values outside Unicode.
- `SpriteColor` is opaque and exposes `from_byte` so arbitrary alpha values can
  model upstream's open `Color` enum.
- `SpriteCanvas.data` and clip fields are public mutable to model the upstream
  canvas alpha surface and clip state.
- Generic `SpritePoint`, `SpriteLine`, `SpriteBox`, `SpriteRect`,
  `SpriteTriangle`, and `SpriteQuad` are public constructible value carriers
  standing in for Zig comptime geometry factories.
- No parser/terminal public API churn.

P17.B.3 does not intentionally extend `font/pkg.generated.mbti`:

- `SpriteFace`, `draw2580_259f`, `draw2800_28ff`, and draw helper types remain
  package-private.
- No public registry, generator output, draw function type, or draw helper API
  is added.
- No parser/terminal public API churn.

P17.B.4 does not intentionally extend `font/pkg.generated.mbti`:

- `underline`, `underline_double`, `underline_dashed`, `strikethrough`,
  `overline`, `cursor_rect`, `cursor_hollow_rect`, `cursor_bar`, and
  `cursor_underline` remain package-private.
- No public special sprite draw API, registry, generator output, rasterizer
  adapter, or draw helper API is added.
- No parser/terminal public API churn.

P17.B.5 does not intentionally extend `font/pkg.generated.mbti`:

- `draw1cc21_1cc2f`, `draw1ce51_1ce8f`, `draw1ce90_1ceaf`, and quarter
  `SpriteDrawFraction` variants remain package-private.
- No public legacy supplement draw API, registry, generator output,
  rasterizer adapter, or draw helper API is added.
- No parser/terminal public API churn.

For implementation tasks:

- new `font` and `renderer` packages should keep owner types opaque by default
- internal caches, run iterators, atlas nodes, and renderer command builders
  must not be public unless a caller story is recorded
- public mutable fields remain banned unless explicitly justified in the
  subplan
