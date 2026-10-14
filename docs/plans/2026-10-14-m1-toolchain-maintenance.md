# M1: Current-toolchain warning and format maintenance

## Goal and scope

Update the existing translated repository for MoonBit 0.1.20261012 / moonc
0.10.15, remove compiler warnings, refresh formatting and generated interfaces,
and keep existing behavior and public contracts. This is user-requested
maintenance of completed plan steps, not advancement of P17.C.

## Source mapping and ownership

- Core worker: `terminal/**`, `font/**`, corresponding tests and package imports.
  Upstream owners remain `src/terminal/{Parser,parse_table,UTF8Decoder,stream,
  osc,sgr,dcs}.zig`, translated terminal value/model owners, and the already
  implemented `src/font/{Atlas,CodepointMap}.zig` / `src/font/sprite/*` owners.
  Test qualification and explicit trait method promotion are mechanical
  compatibility edits on existing symbols, not new adapters.
- Examples worker: `examples/**` except its module manifest, and
  `bench/**` except its module manifest. These retain the existing P15/P16 and
  native tmux host adapters; update calls for published dependency APIs without
  adding translation abstractions or changing terminal behavior.
- Main agent: module manifests, ignore rules, integration, full validation,
  `docs/plan.md`, this audit, and final commit. Also maintain the existing
  P17.B.11 `tools/gen_octants` generator: upstream `font/sprite/octants.txt`
  table generation, formatter type spelling, and generated-table consistency.
- Separate worker worktrees; upstream source and pre-existing untracked work
  are read-only and excluded from the patch.

## Dependencies and invariants

The old Rabbita/PTY/TTY/async dependency set cannot load on the current
toolchain (`moon.mod.json` is no longer supported). Update the existing
dependencies to compatible published versions before source checking.
Remove the nonexistent `lexmatch_longest_match` warning mnemonic; retain all
other warning settings. Migrate deprecated module packaging exclusion to the
supported ignore mechanism.

Package inspection also found pre-existing local `worktrees/`, `.tmp/`, and
`GTK_RENDERER_HANDOFF.md` artifacts eligible for packaging. Exclude these exact
paths without deleting their contents.

Preserve parser action ordering, table-driven transitions, UTF-8 retry
semantics, dedicated OSC capture, incremental DCS handling, and terminal/host
effect separation. Preserve existing storage and public API; no new helper
types/functions. Any necessary behavioral deviation must be reported before
editing. Explicit trait extensions must retain the prior callable methods.

## Acceptance and validation

- `moon check --target all --deny-warn`
- `moon test --target all`
- `moon coverage analyze` with touched executable lines reviewed; use the
  appropriate backend for native/JS examples and record justified gaps.
- `moon fmt` followed by `moon fmt --check`
- `moon info` with generated-interface review
- Validate standalone `tools` module with its native backend.
- No unexplained interface changes or warning suppression.

## Baseline and audit

- Initial `moon check`: dependency resolution failed on Rabbita 0.12.1's
  legacy module manifest before any tests ran.
- After dependency/config compatibility updates, `moon check --target all`
  reported 1256 warnings and 15 example API errors. Main warning categories:
  implicit test package imports (845) and implicit trait method promotion
  (374). Also deprecated APIs, unused imports, and one pre-existing font
  guard whose failure already panics.
- Explorer reviewed parser public visibility; parser state remains opaque.
  Cursor's public mutable fields have an existing upstream shared-state
  justification. `Parser::reset_ground` is a pre-existing public API candidate
  used locally only by a stream test; removing it is outside this compatibility
  task and would require a separate API decision.

## Results

Completed and reviewed after integration.

- `moon check --target all --deny-warn`: passes with zero compiler warnings.
- `moon test --target all`: Wasm 660/660, Wasm-GC 660/660, JS 682/682,
  Native 660/660. Rechecked after final workspace formatting.
- `moon fmt`, `moon fmt --check`, `moon info`, and `git diff --check`: pass.
  Independent review confirms formatter-only numeric type/default-parameter
  spellings and trailing-comma/layout changes preserve existing semantics.
- `moon coverage analyze -- -f summary`: succeeds, 13294/13904 points in the
  collected report (including standalone tools traces). Additional JS player
  instrumented tests pass 22/22, with package coverage 509/530.
- Main reviewer inspected final coverage counts: `CodepointMap::add` guard
  line 23 has 10 hits, `Atlas::grow` exact view line 222 has 2 hits,
  `SpriteCanvas::write_atlas` exact view line 137 has 653 hits, and playground
  JSON constructors at lines 587 and 608 have 3 and 1 hits. Inherited gaps and
  build-only startup/PTY alias changes are explicitly accepted in the core and
  example subplans; this task does not introduce new branches or exclusions.
- Public API audit: 564 generated declarations are the same previously
  callable trait methods made explicit (366 Eq, 184 Debug, 14 Hash). No new
  types, mutable fields, or unexplained interface removal. Existing API debt
  is recorded in the core subplan for a separate consumer-contract decision.
- `moon package --list` and archive inspection: 469 entries; no `upstream`,
  `worktrees`, `.tmp`, or GTK handoff artifact included. No package published.
- Native initial builds emit an Xcode `libtool` empty-archive warning for
  dependency `moonbitlang/async/types`; no project compiler warning remains.
  The dependency's empty native archive is outside this source cleanup.

- Standalone tools: `moon -C tools check --target native --deny-warn`,
  `moon -C tools test --target native` (9/9), `moon -C tools coverage analyze`,
  `moon -C tools fmt`, `moon -C tools info`, and format check pass.
- Generator coverage: 57/65 points. Caret report identifies only the unchanged
  filesystem-writing `main` path (lines 107–114); parser and emission edits
  are tested. Main reviewer accepts the existing CLI coverage gap for this
  maintenance task. `moon -C tools run --target native gen_octants` also
  succeeded; output matches the formatted checked-in table exactly.
- Current formatter canonicalizes `Int`/`UInt` to `Int32`/`UInt32`. Update the
  generator's emitted type spelling and its two exact-output assertions
  together so regenerated octant data remains format-clean.
- Minimal compatible example pins selected after API inspection:
  Rabbita 0.12.4 and PTY 0.2.3 preserve the existing Cell and PTY lifecycle
  APIs. Latest releases would require unrelated architectural migration.

Worker audits:

- [Core maintenance](2026-10-14-m1-core-maintenance.md)
- [Examples and benchmarks](2026-10-14-m1-example-maintenance.md)

## Commit scope

One green Conventional Commit for the compatibility/format maintenance batch,
including this audit and the maintenance entry in `docs/plan.md`.
