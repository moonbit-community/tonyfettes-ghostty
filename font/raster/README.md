# tonyfettes/ghostty/font/raster

A small, self-validating anti-aliased polygon rasterizer in pure MoonBit. It is
the glyph-outline fill stage of the font subsystem — the pure-MoonBit stand-in
for what Ghostty delegates to FreeType in `font/face/freetype.zig` — and depends
only on `moonbitlang/core/math`, so it stays target-agnostic (wasm-gc + native).

The goal here is **not** the rasterizer itself (it is deliberately simple) but a
**test methodology** that lets you trust a fill algorithm without any reference
images, fonts, or C libraries. Rasterization has no normative "correct bitmap"
(FreeType, CoreText, stb_truetype all differ at the edges), so correctness is
established by *differential + analytic + invariant* checks rather than by
matching a golden output.

## The pieces

| File | Role |
|---|---|
| `raster.mbt` | **Under test.** Analytic signed-area rasterizer: each edge is walked once through the pixel grid, depositing signed `cover`/`area` per cell, resolved by a left-to-right prefix sweep. This is the `ftgrays` / `stb_truetype` v2 method — *exact* per-pixel area for straight edges, single pass, no supersampling. |
| `reference.mbt` | **Oracle.** Brute-force `N×N` point-sampling per pixel. Slow but obviously correct; shares no code with `raster.mbt`. |
| `geometry.mbt` | Points, paths, fill rules, exact point-in-path, and the shoelace **analytic area**. |
| `bezier.mbt` | `PathBuilder` mirroring harfbuzz's `draw` callbacks (`move_to`/`line_to`/`quadratic_to`/`cubic_to`/`close`), flattening Béziers via recursive de Casteljau subdivision. |
| `shapes.mbt` | Test shapes: rect, triangle, regular polygon, circle, ring (hole), pentagram (self-intersecting). |
| `coverage.mbt` | Coverage buffer, diff metrics, ASCII rendering. |
| `selfcheck_test.mbt` | The four validation layers below (geometric shapes). |
| `glyph_test.mbt` | The full pipeline on a **real captured harfbuzz `draw` outline**. |

## The four validation layers

1. **Area conservation** — total rendered coverage must equal the analytic
   shoelace area, for simple hole-free shapes. Because the fill is analytically
   exact for straight edges, this now holds to floating-point noise (< 0.5%).
   Catches winding/fill-rule/coverage-scaling bugs with an absolute ground truth.
2. **Supersampling differential** — the rasterizer must agree with the
   brute-force oracle across circles and rings under both fill rules (mean
   < 0.2%, max < 5% — the residual is the oracle's own sampling error). The two
   implementations are independent, so agreement is real signal. Self-
   intersecting paths (a pentagram) are checked separately: the analytic method
   integrates the *winding number* per pixel (as FreeType does), so it differs
   from a point-sampled oracle only at the handful of self-crossing pixels, and
   the mean stays tiny.
3. **Fill-rule discrimination** — a pentagram's core is filled under non-zero
   but empty under even-odd; both the exact predicate and the rasterizer must
   reproduce that.
4. **Invariants** — coverage stays in `[0,1]`, integer translation shifts the
   image exactly, an empty path renders blank.

Plus an **ASCII snapshot** of an anti-aliased circle (`moon test --update`) as a
regression guard once the output is trusted.

## Run

```bash
moon test font/raster            # run all checks
moon test font/raster --update   # refresh the ASCII snapshot
```

## Real glyph pipeline (`glyph_test.mbt`)

`glyph_test.mbt` runs the actual chain end to end:

```
harfbuzz draw (real)  ->  PathBuilder (flatten)  ->  render (scanline fill)
```

The glyph outline is the **verbatim** command stream HarfBuzz emitted for a
curved TrueType glyph (a standard 4-quadratic "circle"), captured by a test in
the `harfbuzz.mbt` repo (`capture draw stream for curved glyph`) and checked in
here as a fixture:

```
M 100 50 / Q 100 100 50 100 / Q 0 100 0 50 / Q 0 0 50 0 / Q 100 0 100 50 / Z
```

It is validated three independent ways, none of which need a reference image:

1. **Flattening convergence** — the flattened polygon's area converges to the
   exact area enclosed by the *curve*, computed by a Simpson line integral
   (`½∮(x dy − y dx)`) that never flattens anything.
2. **Area conservation** — total rendered coverage equals that exact curved area.
3. **Supersampling differential** — the raster output matches the brute-force
   oracle on the same flattened path.

## FreeType differential layer

The fourth oracle — a FreeType reference bitmap (rendered offline, hinting off) —
lives in the external `feihaoxiang/glyph_pipeline` harness, which pulls outlines
live from `harfbuzz.mbt`'s `draw` package across a real font's glyph set and
diffs them against this rasterizer. It is kept out of this project for now
because it needs harfbuzz, `moonbitlang/x/fs`, the native target, and checked-in
golden bitmaps; when the `font/face/` shaping layer lands here it will fold in.
Because the fill here uses the same analytic winding-integral method as
FreeType's `ftgrays`, it matches FreeType to **mean ≤ 0.0012, max ≤ 0.087** on
Inconsolata @48px. See that harness's README.
