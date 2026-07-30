# Bridge index and logical-row ARC cleanup

Post-translation performance follow-up for the linefeed/index path. This task
is stacked on `P7.3.2` because it profiles and optimizes the persistent
circular-grid implementation introduced there.

## Goal

Remove avoidable temporary reference ownership and repeated logical-row
accessor calls from the full-screen linefeed path without changing terminal
behavior, storage ownership, or public APIs.

This task does not remove the ownership required when a row is transferred to
scrollback or when a blank row replaces a harvested physical slot.

## Upstream sources

- `upstream/ghostty/src/terminal/Terminal.zig`
  - `Terminal.index` clears pending wrap, classifies the cursor against the
    scrolling region, captures scrollback for the primary top/full-width
    region, advances or scrolls the active screen, and applies semantic
    continuation state afterward.
- `upstream/ghostty/src/terminal/Screen.zig`
  - `Screen.cursorScrollAbove` owns the full-screen scrollback/row-rotation
    behavior reached by `Terminal.index`.

## MoonBit targets

- `terminal/stream_terminal_bridge.mbt`
  - `StreamTerminalBridgeState::index`;
  - its index-only scroll-region predicates;
  - semantic-after-newline tag checks.
- `terminal/grid/grid.mbt`
  - `ScreenGridState::index`;
  - full-width up/down survivor cleanup, blank replacement, and dirty marking.
- existing terminal/grid/scrollback tests; add a regression only if an
  observable branch is not already covered.

## Baseline evidence

The native release `scroll_full` translation unit shows:

- `StreamTerminalBridgeState::index` retains/releases the cursor around
  `set_pending_wrap`, retains/releases both `PageList` and grid around
  scrollback capture, and retains/releases both grid and cursor around
  `ScreenGridState::index`;
- `active_screen == Primary` lowers to derived polymorphic `Eq`;
- `shift_full_width_up` calls `clean_trailing_spacer_head`, `row_state`,
  `set_row_state`, and `set_blank_row` for every affected row; those methods
  repeatedly remap the same logical row.

A fresh 350-sample native `scroll_full` profile reports:

- `StreamTerminalBridgeState::index <- moonbit_drop_object`: 10.9%;
- `row_cells`: 6.0% self time;
- `row_state`: 6.0% self time;
- `clean_trailing_spacer_head`: 5.4% self time;
- `set_blank_row`: 5.1% self time;
- `set_row_state`: 5.1% self time;
- `shift_full_width_up` ARC attribution: 4.3% incref and 2.3% decref.

## Planned source changes

- Mutate the already-public cursor field directly for the pending-wrap reset,
  avoiding the out-of-line setter receiver retain.
- Use enum tag patterns rather than derived equality for primary/output checks.
- Fold index-only scroll-region predicates into `index` so cursor/margin
  scalars are loaded once and the hot function does not re-enter trivial
  methods.
- Let `ScreenGridState::index` inline into the bridge call site only if
  generated C confirms the hint removes receiver retains without duplicating
  cold work.
- In full-width row shifts, map each survivor/dirty logical row once and update
  the private parallel storage directly. Load the trailing cell value before
  checking its width so no row-buffer reference remains live across that call.
- In `set_blank_row`, map once and replace the three physical components
  directly; keep the public `replace_row` method for its PageList rebuild
  consumer.

No helper function or intermediate model is introduced.

## Must-preserve invariants

- Index behavior matches upstream inside, outside, and at every scroll-region
  boundary.
- Scrollback capture still occurs only on the primary screen with a top-zero,
  full-width region and before the grid shift.
- Semantic clear-EOL/output/prompt-continuation behavior runs after movement.
- Descriptor, cell, and hyperlink buffers remain paired through circular
  origin wrap.
- Partial-height and margin-constrained shifts remain unchanged.
- Public `.mbti` output does not change.

## Performance acceptance

- Generated native release C removes the pending-wrap receiver retain and
  polymorphic `TerminalScreen` equality from bridge `index`.
- Generated C reduces repeated `row_state`/`row_cells`/`set_row_state` calls in
  the full-screen relocation branch.
- Four paired native-release rounds compare the `P7.3.2` commit immediately
  before this branch for `scroll_full`, `scroll_storm`, `plain_lines`,
  `wrapped_blob`, `tui_redraw`, and `colored_log`.
- The intended result is a repeatable improvement in `scroll_full` and
  `scroll_storm` with no control regression above 2%. The audit records the
  measured result even if it misses that target.
- A fresh profile verifies which ARC/accessor costs moved and identifies the
  next remaining bottleneck.

## Validation commands

- `moon check --target all`
- focused terminal/grid/scrollback tests on all targets
- `moon test --target all`
- `moon test --target native --enable-coverage`
- `moon coverage analyze -- -f summary`
- caret coverage review for touched executable files
- `moon build --release --target native bench/scroll_full`
- generated native C inspection
- four paired native-release benchmark rounds
- fresh native `scroll_full` profile
- `moon fmt`
- `moon info`
- `git diff --check`
- generated `.mbti` and public API audit

## Audit notes

- `StreamTerminalBridgeState::index` now clears `pending_wrap` directly, loads
  the cursor and margin coordinates once, uses tag tests for primary/output,
  and keeps the upstream capture-before-shift ordering. The index-only
  outside-region method was removed; the separate primary top-region predicate
  remains because CSI scroll-up also consumes it.
- Full-width up/down shifts now map each survivor and dirty logical row once.
  Packed trailing cells and row descriptors are staged in scalar locals before
  cross-package value methods, so generated C does not retain row buffers or
  descriptor arrays across those calls.
- `set_blank_row` uses `unsafe_pop` only after a non-empty pool check, stages
  the packed descriptor before the indexed store, and writes the three private
  physical components directly. A black-box PageList regression proves that an
  evicted history buffer can be reused as the next active blank without
  aliasing the retained history or active rows.
- Generated native release C confirms:
  - the pending-wrap setter retain/release and primary/output derived equality
    calls are absent from bridge `index`;
  - `row_cells`, `row_state`, `set_row_state`, and
    `clean_trailing_spacer_head` calls are absent from the full-width shift;
  - pooled blank replacement calls `Array::unsafe_pop` directly, without an
    `Option` temporary or `replace_row`;
  - descriptor-array ARC is absent around `with_wrap`,
    `with_wrap_continuation`, `with_dirty`, and `with_styled`.
- `#inline` on `ScreenGridState::index` produced no release-C change and was
  removed. Ordinary MoonBit functions do support `#borrow`; however, with
  moonc `0.10.5+5e7afb0c0` the cross-package release-C call retained the same
  grid/cursor ARC after testing `#borrow(cursor)`, `#borrow(self, cursor)`, and
  a borrowed bridge receiver. Those no-effect annotations were removed rather
  than being presented as an optimization.
- The first native check after deleting the index-only predicate exposed its
  second CSI scroll-up consumer. The shared domain predicate was restored and
  the implementation scope was not expanded.
- Final four-round paired native-release medians against the `P7.3.2` commit:

  | workload | P7.3.2 | P7.3.3 | change |
  | --- | ---: | ---: | ---: |
  | `plain_lines` | 248.505 us | 238.965 us | -3.84% |
  | `wrapped_blob` | 237.125 us | 232.870 us | -1.79% |
  | `scroll_storm` | 754.830 us | 651.840 us | -13.64% |
  | `scroll_full` | 4.735 ms | 4.230 ms | -10.67% |
  | `colored_log` | 267.715 us | 262.035 us | -2.12% |
  | `tui_redraw` | 790.680 us | 794.580 us | +0.49% |

  Both scroll targets improved in all four pairs. The only median regression
  stayed below the 2% control threshold.
- The final 296-sample native `scroll_full` profile no longer attributes ARC to
  `shift_region_up`. `shift_full_width_up` is 18.9% self time and
  `set_blank_row` is 8.8%; the former row accessor functions are absent.
  The remaining ownership hotspot is
  `StreamTerminalBridgeState::index <- moonbit_drop_object` at 11.1%, arising
  around the necessary scrollback capture and cross-package grid-index calls.
- Validation:
  - `moon check --target all`: pass;
  - focused grid tests: 18/18 on wasm, wasm-gc, JS, and native;
  - focused PageList tests: 12/12 on all four targets;
  - `moon test --target all`: 666/666 wasm, 666/666 wasm-gc, 688/688 JS,
    and 666/666 native;
  - native coverage run: 666/666, total 13343/14880;
  - touched coverage: grid 629/646, PageList 820/969, bridge 1429/1484;
    caret review found no uncovered line introduced or modified by this task;
  - `moon fmt`, `moon info`, and `git diff --check`: pass;
  - generated `.mbti` diff: empty.
