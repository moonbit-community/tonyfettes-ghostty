# M1 core: current-toolchain compatibility

## Goal and active step

Execute core maintenance under `docs/plans/2026-10-14-m1-toolchain-maintenance.md`:
remove current-toolchain warnings and format existing `terminal/**` and `font/**`
without changing parser behavior, representation, or previously callable APIs.

## Upstream and target mapping

- Existing terminal parser/state/action owners map to upstream
  `src/terminal/{Parser,parse_table,UTF8Decoder,stream,osc,sgr,dcs}.zig` and the
  already translated terminal model/value owners. Qualify test references and
  declare previously implicit trait method promotions at their existing owner.
- `font/atlas.mbt`, `Atlas::grow` maps to `src/font/Atlas.zig`, `grow`;
  `font/sprite_canvas.mbt`, `SpriteCanvas::write_atlas` maps to
  `src/font/sprite/Canvas.zig`, `writeAtlas`. Replace deprecated `view` aliases
  with `exact_view`, the same current-core implementation and bounds semantics.
- `font/font_test.mbt`, existing `FontVariationId::init` tests: same Bytes view
  alias migration, preserving normal and panic tests.
- `font/codepoint_map.mbt`, `CodepointMap::add` maps to
  `src/font/CodepointMap.zig`, `add`: explicitly spell the existing panic guard
  `guard!`; preserve the existing invalid-range failure behavior.
- Remove imports proven unused by the compiler. No new helper implementations.

## Dependencies and invariants

The main agent owns module manifests, active maintenance plan and integrated
validation. Worker uses copied manifest changes only for validation. Preserve
parser action ordering, UTF-8 retry behavior, OSC/DCS capture/storage and public
contracts. Worktree write ownership: `terminal/**`, `font/**`, this document.

## Acceptance and validation

- No diagnostics in worker-owned files after `moon check --target all`.
- `moon test terminal font --target all` (including nested packages).
- `moon coverage analyze` and review touched executable coverage gaps.
- `moon fmt terminal font`, formatting check and `moon info` API diff audit.
- Existing black-box tests retain test values and assertions.
- Explicit extensions preserve previously promoted Eq/Debug/Hash/etc. methods;
  no new externally visible types, helpers, or mutable fields.

## Audit notes

Baseline core diagnostics: 782 implicit test imports, 374 implicit trait method
promotions, 8 unused imports, 4 deprecated view aliases and 1 panic guard.
Pre-existing public `Parser::reset_ground` is locally used only in a stream test;
removing it would need a separate public API decision. Public mutable fields in
font structs are also pre-existing; compatibility maintenance does not broaden
or redesign those contracts.

## Results

- `moon check --target all --output-json`: zero warnings/errors in `terminal/**`
  and `font/**`. Remaining example errors belong to the parallel worker.
- `moon test` with all 39 owned package directories and `--target all`: 654/654
  tests pass independently on wasm, wasm-gc, JS and native; no owned warnings.
- `moon fmt` and `moon fmt --check` with every owned package pass. Current
  formatter spells source aliases `Int`/`UInt` as `Int32`/`UInt32`; intentional
  mechanical normalization, including generated tables.
- `moon info` regenerated interfaces. Audited all 39 owned interfaces: 564 added
  method declarations are exclusively existing trait promotions (366 Eq,
  184 Debug, 14 Hash); no existing nonblank declaration is removed, no mutable fields or
  new types introduced. Consumers retain their existing dot-call methods.
- `git diff --check -- terminal font` passes.
- `moon coverage analyze -- -f summary` succeeds, combined workspace result
  13239/13841 coverage points. The report includes unrelated benchmark entry
  points and examples; the owned gaps are listed below.
- `moon coverage report -f caret -F font/atlas.mbt`, `font/codepoint_map.mbt`,
  and `font/sprite_canvas.mbt` each produces no uncovered lines. In particular,
  `Atlas::grow` line 222 (`exact_view`), `SpriteCanvas::write_atlas` line 137
  (`exact_view`) and `CodepointMap::add` line 23 (`guard!`) are covered. Existing
  FontVariationId normal/panic tests at lines 158 and 167 pass on every backend.

### Accepted inherited coverage gaps

Reviewed the caret report against the patch: each gap below is inherited code
changed only by current formatter spelling/layout, or in a file receiving
non-executable explicit trait promotion declarations. No new executable branch
or behavior is introduced. Extending coverage for these existing defensive and
protocol branches is outside this mechanical compatibility step; they are
recorded for integrator review rather than silently treated as covered.

| Owned file with inherited gaps | Covered / total points |
| --- | --- |
| `font/sprite_draw_box.mbt` | 471/473 |
| `font/sprite_draw_braille.mbt` | 48/52 |
| `terminal/ascii/ascii.mbt` | 67/79 |
| `terminal/cimap/cimap.mbt` | 68/70 |
| `terminal/color/color.mbt` | 544/545 |
| `terminal/formatter.mbt` | 638/713 |
| `terminal/grid/grid.mbt` | 526/547 |
| `terminal/hyperlink/table.mbt` | 22/24 |
| `terminal/key_encoder/key_encoder.mbt` | 461/500 |
| `terminal/key_encoder/key_encoder_function_keys.mbt` | 231/270 |
| `terminal/kitty_graphics.mbt` | 196/201 |
| `terminal/kitty_graphics_state.mbt` | 168/169 |
| `terminal/osc/osc.mbt` | 557/559 |
| `terminal/page/cell.mbt` | 157/164 |
| `terminal/page/grapheme_table.mbt` | 25/27 |
| `terminal/pagelist/pagelist.mbt` | 800/952 |
| `terminal/render_row_iterator.mbt` | 48/50 |
| `terminal/render_state.mbt` | 235/243 |
| `terminal/sgr/sgr.mbt` | 198/199 |
| `terminal/stream/stream.mbt` | 694/695 |
| `terminal/stream_terminal.mbt` | 261/279 |
| `terminal/stream_terminal_bridge.mbt` | 1448/1503 |
| `terminal/style/style_table.mbt` | 20/22 |
| `terminal/terminal_screen_storage.mbt` | 19/21 |
| `terminal/utf8_decoder/decode_until_control.mbt` | 68/71 |

### Pre-existing API follow-up candidates

The `.mbti` audit identifies existing public mutable font implementation state:
`Atlas` data/nodes/counters, `AtlasNode`, `CodepointMap.list`, and `SpriteCanvas`
data/clip fields (as well as intentionally caller-built public font value
records). These deserve a separate consumer/API contract audit; this step
preserves rather than expands their visibility. `Parser::reset_ground` likewise
remains a follow-up candidate. Cursor shared mutable state has an existing
upstream ownership justification in the main audit.

Main reviewer signoff: the inherited coverage gaps above are acceptable for
this behavior-preserving maintenance. Independent diff review confirmed no
new executable behavior in those gaps and no unexplained public API changes.
